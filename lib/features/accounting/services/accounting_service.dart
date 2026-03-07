import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:techsc/features/accounting/models/transaction_model.dart';
import 'package:techsc/features/accounting/models/daily_closure_model.dart';
import 'package:techsc/features/accounting/models/electronic_invoice_model.dart';

/// Servicio encargado de la gestión de datos contables en Firestore.
///
/// Este servicio permite el registro de ingresos y egresos, así como la consulta
/// de transacciones filtradas por rangos de fecha para reportes contables.
class AccountingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'accounting_transactions';

  /// Guarda una nueva transacción o actualiza una existente en la base de datos.
  ///
  /// Si la transacción tiene un ID vacío, Firestore generará uno automáticamente.
  Future<void> saveTransaction(TransactionModel transaction) async {
    try {
      if (transaction.id.isEmpty) {
        await _firestore.collection(_collection).add(transaction.toMap());
      } else {
        await _firestore
            .collection(_collection)
            .doc(transaction.id)
            .set(transaction.toMap(), SetOptions(merge: true));
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
    final snapshot = await _firestore
        .collection(_collection)
        .where('category', isEqualTo: category)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .get();

    return snapshot.docs.map((doc) {
      return TransactionModel.fromMap(doc.data(), doc.id);
    }).toList();
  }

  // --- Métodos para Cierres de Caja (Daily Closures) ---

  /// Guarda un nuevo cierre de caja en Firestore.
  Future<void> saveClosure(DailyClosureModel closure) async {
    try {
      await _firestore
          .collection('accounting_closures')
          .doc(closure.id.isEmpty ? null : closure.id)
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

  // --- Métodos para Facturación Electrónica (Bridge) ---

  /// Registra una factura electrónica en el sistema (puente).
  Future<void> saveElectronicInvoice(ElectronicInvoiceModel invoice) async {
    try {
      await _firestore
          .collection('accounting_invoices')
          .doc(invoice.id.isEmpty ? null : invoice.id)
          .set(invoice.toMap());
    } catch (e) {
      debugPrint('Error al guardar factura electrónica: $e');
      rethrow;
    }
  }
}
