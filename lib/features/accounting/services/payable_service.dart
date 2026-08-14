import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:tscomputer/core/services/document_id_service.dart';
import 'package:tscomputer/features/accounting/models/payable_model.dart';
import 'package:tscomputer/features/accounting/services/journal_entry_service.dart';

class PayableService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'accounts_payable';

  Future<String> createPayable(PayableModel payable) async {
    try {
      final docRef = _firestore.collection(_collection).doc();
      final updated = PayableModel(
        id: docRef.id,
        supplierName: payable.supplierName,
        supplierIdentification: payable.supplierIdentification,
        supplierPhone: payable.supplierPhone,
        originType: payable.originType,
        originId: payable.originId,
        totalAmount: payable.totalAmount,
        paidAmount: payable.paidAmount,
        issueDate: payable.issueDate,
        dueDate: payable.dueDate,
        status: payable.status,
        notes: payable.notes,
        lastPaymentDate: payable.lastPaymentDate,
      );
      await docRef.set(updated.toMap());
      return docRef.id;
    } catch (e) {
      debugPrint('Error al crear cuenta por pagar: $e');
      rethrow;
    }
  }

  Future<void> registerPayment(String payableId, double amount, String method, {bool applyVAT = false}) async {
    try {
      final docRef = _firestore.collection(_collection).doc(payableId);
      final doc = await docRef.get();
      if (!doc.exists) throw Exception('Cuenta por pagar no encontrada');

      final data = doc.data()!;
      final currentPaid = (data['paidAmount'] as num?)?.toDouble() ?? 0.0;
      final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
      final newPaid = currentPaid + amount;
      final newStatus = newPaid >= totalAmount ? PayableStatus.pagada.name : PayableStatus.parcial.name;

      await docRef.update({
        'paidAmount': newPaid,
        'balance': (totalAmount - newPaid).clamp(0.0, double.infinity),
        'status': newStatus,
        'lastPaymentDate': Timestamp.fromDate(DateTime.now()),
      });

      final paymentRef = docRef.collection('payments').doc(
        await DocumentIdService().generateId(prefix: 'cxppago', useDate: true),
      );
      await paymentRef.set({
        'amount': amount,
        'method': method,
        'date': Timestamp.now(),
      });

      // Asiento contable: DR CxP (disminución de pasivo) / CR cuenta según método
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
      final payableAccount = (data['accountCode'] as String?)?.isNotEmpty == true
          ? data['accountCode'] as String
          : '2.1.01';
      await JournalEntryService().createEntryFromEvent(
        referenceType: 'payable_payment',
        referenceId: paymentRef.id,
        date: DateTime.now(),
        description: 'Pago CxP - ${data['supplierName']}',
        lines: [
          {'accountCode': payableAccount, 'debit': amount, 'credit': 0.0},
          {'accountCode': cashAccount, 'debit': 0.0, 'credit': amount},
        ],
      );
    } catch (e) {
      debugPrint('Error al registrar pago CxP: $e');
      rethrow;
    }
  }

  Stream<List<PayableModel>> getAllPayablesStream() {
    return _firestore.collection(_collection).orderBy('issueDate', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => PayableModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Future<List<PayableModel>> getAllPayables() async {
    final snapshot = await _firestore.collection(_collection).orderBy('issueDate', descending: true).get();
    return snapshot.docs.map((doc) => PayableModel.fromMap(doc.data(), doc.id)).toList();
  }

  Stream<List<PayableModel>> getPendingPayablesStream() {
    return _firestore.collection(_collection).where('status', whereIn: ['pendiente', 'parcial', 'vencida']).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => PayableModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Future<double> getTotalPending() async {
    final snapshot = await _firestore.collection(_collection).where('status', whereIn: ['pendiente', 'parcial', 'vencida']).get();
    double total = 0;
    for (final doc in snapshot.docs) {
      total += (doc.data()['balance'] as num?)?.toDouble() ?? 0.0;
    }
    return total;
  }

  Future<void> deletePayable(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  Future<int> markOverdue() async {
    final now = Timestamp.fromDate(DateTime.now());
    final snapshot = await _firestore.collection(_collection)
        .where('dueDate', isLessThan: now)
        .get();
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
    debugPrint('✅ $count CxP marcadas como vencidas');
    return count;
  }

  Future<void> autoCreateFromInventoryMovement(String movementId, String supplierName, String? supplierId, double total, DateTime date, {String? accountCode}) async {
    final existing = await _firestore.collection(_collection).where('originId', isEqualTo: movementId).where('originType', isEqualTo: 'inventory').limit(1).get();
    if (existing.docs.isNotEmpty) return;
    await createPayable(PayableModel(
      id: '',
      supplierName: supplierName,
      supplierIdentification: supplierId,
      originType: 'inventory',
      originId: movementId,
      totalAmount: total,
      issueDate: date,
      dueDate: date.add(const Duration(days: 30)),
    ));
    // Guardar la subcuenta de proveedor (2.1.01.xx) para el asiento de pago
    if (accountCode != null && accountCode.isNotEmpty) {
      final q = await _firestore.collection(_collection).where('originId', isEqualTo: movementId).where('originType', isEqualTo: 'inventory').limit(1).get();
      if (q.docs.isNotEmpty) {
        await q.docs.first.reference.update({'accountCode': accountCode});
      }
    }
  }
}
