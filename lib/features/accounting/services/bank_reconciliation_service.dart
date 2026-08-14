import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:tscomputer/features/accounting/models/bank_reconciliation_model.dart';

class BankReconciliationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'bank_reconciliation';

  Future<String> createReconciliation(BankReconciliationModel recon) async {
    try {
      final docRef = _firestore.collection(_collection).doc();
      final updated = BankReconciliationModel(
        id: docRef.id,
        bankName: recon.bankName,
        accountNumber: recon.accountNumber,
        statementDate: recon.statementDate,
        openingBalance: recon.openingBalance,
        closingBalance: recon.closingBalance,
        lines: recon.lines,
        systemBalance: recon.systemBalance,
        notes: recon.notes,
        createdBy: recon.createdBy,
      );
      await docRef.set(updated.toMap());
      return docRef.id;
    } catch (e) {
      debugPrint('Error al crear conciliación: $e');
      rethrow;
    }
  }

  Future<void> updateLineStatus(String reconId, String lineIndex, ReconStatus status) async {
    final docRef = _firestore.collection(_collection).doc(reconId);
    await docRef.update({
      'lines.$lineIndex.status': status.name,
    });
  }

  Future<void> deleteReconciliation(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  Stream<List<BankReconciliationModel>> getAllStream() {
    return _firestore.collection(_collection).orderBy('statementDate', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => BankReconciliationModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Future<List<BankReconciliationModel>> getAll() async {
    final snapshot = await _firestore.collection(_collection).orderBy('statementDate', descending: true).get();
    return snapshot.docs.map((doc) => BankReconciliationModel.fromMap(doc.data(), doc.id)).toList();
  }
}
