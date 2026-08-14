import 'package:cloud_firestore/cloud_firestore.dart';

enum ReceivableStatus { pendiente, parcial, pagada, vencida, anulada }

class ReceivableModel {
  final String id;
  final String clientName;
  final String? clientIdentification;
  final String? clientPhone;
  final String originType;
  final String originId;
  final double totalAmount;
  final double paidAmount;
  double get balance => (totalAmount - paidAmount).clamp(0.0, double.infinity);
  final DateTime issueDate;
  final DateTime? dueDate;
  final ReceivableStatus status;
  final String? notes;
  final DateTime? lastPaymentDate;

  ReceivableModel({
    required this.id,
    required this.clientName,
    this.clientIdentification,
    this.clientPhone,
    required this.originType,
    required this.originId,
    required this.totalAmount,
    this.paidAmount = 0.0,
    required this.issueDate,
    this.dueDate,
    this.status = ReceivableStatus.pendiente,
    this.notes,
    this.lastPaymentDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'clientName': clientName,
      'clientIdentification': clientIdentification,
      'clientPhone': clientPhone,
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

  factory ReceivableModel.fromMap(Map<String, dynamic> map, String docId) {
    return ReceivableModel(
      id: docId,
      clientName: map['clientName'] ?? '',
      clientIdentification: map['clientIdentification'],
      clientPhone: map['clientPhone'],
      originType: map['originType'] ?? '',
      originId: map['originId'] ?? '',
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      paidAmount: (map['paidAmount'] as num?)?.toDouble() ?? 0.0,
      issueDate: (map['issueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dueDate: (map['dueDate'] as Timestamp?)?.toDate(),
      status: ReceivableStatus.values.byName(map['status'] ?? 'pendiente'),
      notes: map['notes'],
      lastPaymentDate: (map['lastPaymentDate'] as Timestamp?)?.toDate(),
    );
  }
}
