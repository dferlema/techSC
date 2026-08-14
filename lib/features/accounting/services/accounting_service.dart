import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:tscomputer/core/services/document_id_service.dart';
import 'package:tscomputer/features/accounting/models/transaction_model.dart';
import 'package:tscomputer/features/accounting/models/daily_closure_model.dart';
import 'package:tscomputer/features/accounting/services/reservation_accounting_service.dart';
import 'package:tscomputer/core/utils/firestore_retry.dart';
import 'package:tscomputer/features/orders/services/order_service.dart';

/// Servicio encargado de la gestión de datos contables en Firestore.
///
/// Este servicio permite el registro de ingresos y egresos, así como la consulta
/// de transacciones filtradas por rangos de fecha para reportes contables.
class AccountingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'accounting_transactions';

  /// Guarda una nueva transacción o actualiza una existente.
  /// Si ya existe, guarda el historial previo en una subcolección `_history`.
  Future<void> saveTransaction(TransactionModel transaction) async {
    try {
      if (transaction.id.isEmpty) {
        final id = await DocumentIdService().generateId(prefix: 'cta', useDate: true);
        await _firestore.collection(_collection).doc(id).set(transaction.toMap());
      } else {
        final docRef = _firestore.collection(_collection).doc(transaction.id);
        final existing = await retryFirestore(() => docRef.get());
        if (existing.exists) {
          final oldData = existing.data() as Map<String, dynamic>;
          oldData['changedAt'] = Timestamp.fromDate(DateTime.now());
          oldData['changedTo'] = transaction.toMap();
          await docRef.collection('_history').add(oldData);
        }
        await docRef.set(transaction.toMap(), SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error al guardar transacción: $e');
      rethrow;
    }
  }

  /// Obtiene un flujo (Stream) de transacciones dentro de un rango de fechas.
  ///
  /// Útil para actualizar la interfaz en tiempo real cuando se filtran reportes.
  Stream<List<TransactionModel>> getTransactionsStream({
    required DateTime start,
    required DateTime end,
  }) {
    // Se ajusta el rango para incluir todo el día de inicio y fin.
    final startTimestamp = Timestamp.fromDate(
      DateTime(start.year, start.month, start.day, 0, 0, 0),
    );
    final endTimestamp = Timestamp.fromDate(
      DateTime(end.year, end.month, end.day, 23, 59, 59),
    );

    return _firestore
        .collection(_collection)
        .where('date', isGreaterThanOrEqualTo: startTimestamp)
        .where('date', isLessThanOrEqualTo: endTimestamp)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return TransactionModel.fromMap(doc.data(), doc.id);
          }).toList();
        });
  }

  /// Elimina una transacción de forma permanente.
  Future<void> deleteTransaction(String id) async {
    try {
      await _firestore.collection(_collection).doc(id).delete();
    } catch (e) {
      debugPrint('Error al eliminar transacción: $e');
      rethrow;
    }
  }

  /// Obtiene todas las transacciones de una categoría específica en un periodo.
  Future<List<TransactionModel>> getTransactionsByCategory(
    String category,
    DateTime start,
    DateTime end,
  ) async {
    final snapshot = await retryFirestore(() => _firestore
        .collection(_collection)
        .where('category', isEqualTo: category)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get());

    return snapshot.docs.map((doc) {
      return TransactionModel.fromMap(doc.data(), doc.id);
    }).toList();
  }

  // --- Métodos para Cierres de Caja (Daily Closures) ---

  /// Guarda un nuevo cierre de caja en Firestore.
  Future<void> saveClosure(DailyClosureModel closure) async {
    try {
      final docId = closure.id.isEmpty
          ? await DocumentIdService().generateId(prefix: 'cierre', useDate: true)
          : closure.id;
      await _firestore
          .collection('accounting_closures')
          .doc(docId)
          .set(closure.toMap());
    } catch (e) {
      debugPrint('Error al guardar cierre de caja: $e');
      rethrow;
    }
  }

  /// Obtiene los últimos cierres de caja realizados.
  Stream<List<DailyClosureModel>> getClosuresStream({int limit = 10}) {
    return _firestore
        .collection('accounting_closures')
        .orderBy('date', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return DailyClosureModel.fromMap(doc.data(), doc.id);
          }).toList();
        });
  }

  /// Sincroniza todas las ventas/órdenes y reservaciones pasadas
  /// que aún no cuentan con registro en contabilidad.
  Future<int> syncPastSalesToAccounting() async {
    int syncedCount = 0;
    try {
      // 1. Sincronizar Órdenes / Ventas
      final ordersSnapshot = await _firestore.collection('orders').get();
      final orderService = OrderService();

      final estadosValidos = ['entregado', 'completado', 'completed', 'delivered'];

      for (var doc in ordersSnapshot.docs) {
        final data = doc.data();
        final status = (data['status'] ?? '').toString().toLowerCase();
        final isPaid = data['isPaid'] == true || data['paymentStatus'] == 'paid';
        if (estadosValidos.contains(status) || isPaid) {
          final transactionDocId = 'order_${doc.id}';
          final existingTx = await retryFirestore(() => _firestore
              .collection(_collection)
              .doc(transactionDocId)
              .get());

          if (!existingTx.exists) {
            await orderService.registerOrderIncome(doc.id);
            syncedCount++;
          }
        }
      }

      // 2. Sincronizar Reservaciones / Servicios Técnicos
      final reservationsSnapshot = await _firestore.collection('reservations').get();
      final reservationSvc = ReservationAccountingService();

      final resEstadosValidos = ['completado'];

      for (var doc in reservationsSnapshot.docs) {
        final data = doc.data();
        final status = (data['status'] ?? '').toString().toLowerCase();
        if (!resEstadosValidos.contains(status)) continue;

        final transactionDocId = 'reservation_${doc.id}';
        final existingTx = await retryFirestore(() => _firestore
            .collection(_collection)
            .doc(transactionDocId)
            .get());

        if (!existingTx.exists) {
          try {
            final clientName = data['clientName'] ?? '';
            final clientId = data['clientId'] ?? '';
            final serviceType = data['serviceType'] ?? '';
            final partsData = (data['partsData'] as List<dynamic>?)
                    ?.map((p) => Map<String, dynamic>.from(p as Map))
                    .toList() ??
                [];
            final servicesData = (data['servicesData'] as List<dynamic>?) ?? [];

            double servicesTotal = 0;
            for (final s in servicesData) {
              servicesTotal += (s['price'] as num?)?.toDouble() ?? 0.0;
            }
            double partsTotal = 0;
            for (final p in partsData) {
              partsTotal += (p['price'] as num?)?.toDouble() ?? 0.0;
            }

            final paymentMethod = data['paymentMethod'] ?? 'efectivo';

            await reservationSvc.registerIncome(
              reservationId: doc.id,
              serviceType: serviceType,
              clientName: clientName,
              clientId: clientId,
              servicesTotal: servicesTotal,
              partsTotal: partsTotal,
              paymentMethod: paymentMethod,
              selectedParts: partsData,
            );
            syncedCount++;
          } catch (e) {
            debugPrint('⚠️ Error sincronizando reserva ${doc.id}: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('Error durante la sincronización a contabilidad: $e');
    }
    return syncedCount;
  }
}
