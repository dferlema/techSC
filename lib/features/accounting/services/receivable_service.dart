import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:tscomputer/core/services/document_id_service.dart';
import 'package:tscomputer/features/accounting/models/receivable_model.dart';
import 'package:tscomputer/core/utils/firestore_retry.dart';
import 'package:tscomputer/features/accounting/services/journal_entry_service.dart';

class ReceivableService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'accounts_receivable';

  Future<String> createReceivable(ReceivableModel receivable) async {
    try {
      final docRef = _firestore.collection(_collection).doc();
      final updated = ReceivableModel(
        id: docRef.id,
        clientName: receivable.clientName,
        clientIdentification: receivable.clientIdentification,
        clientPhone: receivable.clientPhone,
        originType: receivable.originType,
        originId: receivable.originId,
        totalAmount: receivable.totalAmount,
        paidAmount: receivable.paidAmount,
        issueDate: receivable.issueDate,
        dueDate: receivable.dueDate,
        status: receivable.status,
        notes: receivable.notes,
        lastPaymentDate: receivable.lastPaymentDate,
      );
      await docRef.set(updated.toMap());
      return docRef.id;
    } catch (e) {
      debugPrint('Error al crear cuenta por cobrar: $e');
      rethrow;
    }
  }

  Future<void> registerPayment(String receivableId, double amount, String method, {bool applyVAT = false}) async {
    try {
      final docRef = _firestore.collection(_collection).doc(receivableId);
      final doc = await retryFirestore(() => docRef.get());
      if (!doc.exists) throw Exception('Cuenta por cobrar no encontrada');

      final data = doc.data()!;
      final currentPaid = (data['paidAmount'] as num?)?.toDouble() ?? 0.0;
      final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
      final newPaid = currentPaid + amount;
      final newStatus = newPaid >= totalAmount ? ReceivableStatus.pagada.name : ReceivableStatus.parcial.name;

      await docRef.update({
        'paidAmount': newPaid,
        'balance': (totalAmount - newPaid).clamp(0.0, double.infinity),
        'status': newStatus,
        'lastPaymentDate': Timestamp.fromDate(DateTime.now()),
      });

      final paymentRef = docRef.collection('payments').doc(
        await DocumentIdService().generateId(prefix: 'cxcpago', useDate: true),
      );
      await paymentRef.set({
        'amount': amount,
        'method': method,
        'date': Timestamp.now(),
      });

      // Asiento contable: DR cuenta según método / CR CxC (disminución)
      String cashAccount;
      switch (method) {
        case 'efectivo':
          cashAccount = '1.1.01.01'; // Caja General
          break;
        case 'tarjeta':
        case 'transferencia':
          cashAccount = '1.1.01.03'; // Bancos - Cta Corriente
          break;
        default:
          cashAccount = '1.1.01.03';
      }
      await JournalEntryService().createEntryFromEvent(
        referenceType: 'receivable_payment',
        referenceId: paymentRef.id,
        date: DateTime.now(),
        description: 'Pago CxC - ${data['clientName']}',
        lines: [
          {'accountCode': cashAccount, 'debit': amount, 'credit': 0.0},
          {'accountCode': '1.1.02.01', 'debit': 0.0, 'credit': amount},
        ],
      );
    } catch (e) {
      debugPrint('Error al registrar pago CxC: $e');
      rethrow;
    }
  }

  Stream<List<ReceivableModel>> getAllReceivablesStream() {
    return _firestore.collection(_collection).orderBy('issueDate', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => ReceivableModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Stream<List<ReceivableModel>> getPendingReceivablesStream() {
    return _firestore.collection(_collection).where('status', whereIn: ['pendiente', 'parcial', 'vencida']).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => ReceivableModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Future<double> getTotalPending() async {
    final snapshot = await retryFirestore(() => _firestore.collection(_collection).where('status', whereIn: ['pendiente', 'parcial', 'vencida']).get());
    double total = 0;
    for (final doc in snapshot.docs) {
      total += (doc.data()['balance'] as num?)?.toDouble() ?? 0.0;
    }
    return total;
  }

  Future<void> deleteReceivable(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  Future<int> markOverdue() async {
    final now = Timestamp.fromDate(DateTime.now());
    final snapshot = await retryFirestore(() => _firestore.collection(_collection)
        .where('dueDate', isLessThan: now)
        .get());
    int count = 0;
    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      final status = doc.data()['status'] as String? ?? '';
      if (status == 'pendiente' || status == 'parcial') {
        batch.update(doc.reference, {'status': 'vencida'});
        count++;
      }
    }
    if (count > 0) await batch.commit();
    debugPrint('✅ $count CxC marcadas como vencidas');
    return count;
  }

  Future<void> autoCreateFromOrder(String orderId, String clientName, String? clientId, double total, DateTime date) async {
    final existing = await retryFirestore(() => _firestore.collection(_collection).where('originId', isEqualTo: orderId).where('originType', isEqualTo: 'order').limit(1).get());
    if (existing.docs.isNotEmpty) return;
    await createReceivable(ReceivableModel(
      id: '',
      clientName: clientName,
      clientIdentification: clientId,
      originType: 'order',
      originId: orderId,
      totalAmount: total,
      issueDate: date,
      dueDate: date.add(const Duration(days: 30)),
    ));
  }

  Future<void> autoCreateFromReservation(String reservationId, String clientName, String? clientId, double total, DateTime date, {String serviceType = ''}) async {
    final existing = await retryFirestore(() => _firestore.collection(_collection).where('originId', isEqualTo: reservationId).where('originType', isEqualTo: 'reservation').limit(1).get());
    if (existing.docs.isNotEmpty) return;
    await createReceivable(ReceivableModel(
      id: '',
      clientName: clientName,
      clientIdentification: clientId,
      originType: 'reservation',
      originId: reservationId,
      totalAmount: total,
      issueDate: date,
      dueDate: date.add(const Duration(days: 30)),
      notes: serviceType.isNotEmpty ? 'Servicio: $serviceType' : null,
    ));
  }
}
