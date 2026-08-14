import 'package:cloud_firestore/cloud_firestore.dart';

enum ReconTransactionType { debito, credito }
enum ReconStatus { pendiente, conciliado, noConciliado }

class BankTransactionLine {
  final String id;
  final DateTime date;
  final String description;
  final double amount;
  final ReconTransactionType type;
  ReconStatus status;
  final String? referenceTransactionId;

  BankTransactionLine({
    required this.id,
    required this.date,
    required this.description,
    required this.amount,
    required this.type,
    this.status = ReconStatus.pendiente,
    this.referenceTransactionId,
  });

  Map<String, dynamic> toMap() {
    return {
      'date': Timestamp.fromDate(date),
      'description': description,
      'amount': amount,
      'type': type.name,
      'status': status.name,
      'referenceTransactionId': referenceTransactionId,
    };
  }

  factory BankTransactionLine.fromMap(Map<String, dynamic> map, String lineId) {
    return BankTransactionLine(
      id: lineId,
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      description: map['description'] ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      type: ReconTransactionType.values.byName(map['type'] ?? 'debito'),
      status: ReconStatus.values.byName(map['status'] ?? 'pendiente'),
      referenceTransactionId: map['referenceTransactionId'],
    );
  }
}

class BankReconciliationModel {
  final String id;
  final String bankName;
  final String? accountNumber;
  final DateTime statementDate;
  final double openingBalance;
  final double closingBalance;
  final List<BankTransactionLine> lines;
  final double systemBalance;
  double get difference => closingBalance - systemBalance;
  double get reconciledAmount => lines.where((l) => l.status == ReconStatus.conciliado).fold(0.0, (sum, l) => l.type == ReconTransactionType.debito ? sum + l.amount : sum - l.amount);
  final String? notes;
  final String? createdBy;
  final DateTime createdAt;

  BankReconciliationModel({
    required this.id,
    required this.bankName,
    this.accountNumber,
    required this.statementDate,
    required this.openingBalance,
    required this.closingBalance,
    required this.lines,
    required this.systemBalance,
    this.notes,
    this.createdBy,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'bankName': bankName,
      'accountNumber': accountNumber,
      'statementDate': Timestamp.fromDate(statementDate),
      'openingBalance': openingBalance,
      'closingBalance': closingBalance,
      'lines': lines.map((l) => l.toMap()).toList(),
      'systemBalance': systemBalance,
      'difference': difference,
      'notes': notes,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory BankReconciliationModel.fromMap(Map<String, dynamic> map, String docId) {
    final linesList = (map['lines'] as List? ?? []);
    final linesMap = <String, dynamic>{};
    for (int i = 0; i < linesList.length; i++) {
      linesMap['line_$i'] = linesList[i];
    }
    return BankReconciliationModel(
      id: docId,
      bankName: map['bankName'] ?? '',
      accountNumber: map['accountNumber'],
      statementDate: (map['statementDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      openingBalance: (map['openingBalance'] as num?)?.toDouble() ?? 0.0,
      closingBalance: (map['closingBalance'] as num?)?.toDouble() ?? 0.0,
      lines: (map['lines'] as List? ?? []).map((l) => BankTransactionLine.fromMap(l as Map<String, dynamic>, '')).toList(),
      systemBalance: (map['systemBalance'] as num?)?.toDouble() ?? 0.0,
      notes: map['notes'],
      createdBy: map['createdBy'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
