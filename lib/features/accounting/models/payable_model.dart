import 'package:cloud_firestore/cloud_firestore.dart';

enum PayableStatus { pendiente, parcial, pagada, vencida, anulada }

class PayableModel {
  final String id;
  final String supplierName;
  final String? supplierIdentification;
  final String? supplierPhone;
  final String originType;
  final String originId;
  final double totalAmount;
  final double paidAmount;
  double get balance => (totalAmount - paidAmount).clamp(0.0, double.infinity);
  final DateTime issueDate;
  final DateTime? dueDate;
  final PayableStatus status;
  final String? notes;
  final DateTime? lastPaymentDate;

  PayableModel({
    required this.id,
    required this.supplierName,
    this.supplierIdentification,
    this.supplierPhone,
    required this.originType,
    required this.originId,
    required this.totalAmount,
    this.paidAmount = 0.0,
    required this.issueDate,
    this.dueDate,
    this.status = PayableStatus.pendiente,
    this.notes,
    this.lastPaymentDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'supplierName': supplierName,
      'supplierIdentification': supplierIdentification,
      'supplierPhone': supplierPhone,
      'originType': originType,
      'originId': originId,
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'balance': balance,
      'issueDate': Timestamp.fromDate(issueDate),
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'status': status.name,
      'notes': notes,
      'lastPaymentDate': lastPaymentDate != null ? Timestamp.fromDate(lastPaymentDate!) : null,
    };
  }

  factory PayableModel.fromMap(Map<String, dynamic> map, String docId) {
    return PayableModel(
      id: docId,
      supplierName: map['supplierName'] ?? '',
      supplierIdentification: map['supplierIdentification'],
      supplierPhone: map['supplierPhone'],
      originType: map['originType'] ?? '',
      originId: map['originId'] ?? '',
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (map['paidAmount'] as num?)?.toDouble() ?? 0.0,
      issueDate: (map['issueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dueDate: (map['dueDate'] as Timestamp?)?.toDate(),
      status: PayableStatus.values.byName(map['status'] ?? 'pendiente'),
      notes: map['notes'],
      lastPaymentDate: (map['lastPaymentDate'] as Timestamp?)?.toDate(),
    );
  }
}
