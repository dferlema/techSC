import 'package:cloud_firestore/cloud_firestore.dart';

class AccountingEntryLine {
  final String accountId;
  final String accountCode;
  final String accountName;
  final double debit;
  final double credit;
  final String? reference;
  final String? accountNature; // 'deudora' o 'acreedora' — para calcular saldos

  AccountingEntryLine({
    required this.accountId,
    required this.accountCode,
    required this.accountName,
    this.debit = 0.0,
    this.credit = 0.0,
    this.reference,
    this.accountNature,
  });

  Map<String, dynamic> toMap() {
    return {
      'accountId': accountId,
      'accountCode': accountCode,
      'accountName': accountName,
      'debit': debit,
      'credit': credit,
      'reference': reference,
      'accountNature': accountNature,
    };
  }

  factory AccountingEntryLine.fromMap(Map<String, dynamic> map) {
    return AccountingEntryLine(
      accountId: map['accountId'] ?? '',
      accountCode: map['accountCode'] ?? '',
      accountName: map['accountName'] ?? '',
      debit: (map['debit'] as num?)?.toDouble() ?? 0.0,
      credit: (map['credit'] as num?)?.toDouble() ?? 0.0,
      reference: map['reference'],
      accountNature: map['accountNature'],
    );
  }
}

enum EntryStatus { borrador, contabilizado, cancelado }

class AccountingEntryModel {
  final String id;
  final String number;
  final DateTime date;
  final String description;
  final List<AccountingEntryLine> lines;
  final EntryStatus status;
  final String? createdBy;
  final String? referenceType;
  final String? referenceId;
  final DateTime? createdAt;
  final DateTime? postedAt;

  AccountingEntryModel({
    required this.id,
    required this.number,
    required this.date,
    required this.description,
    required this.lines,
    this.status = EntryStatus.borrador,
    this.createdBy,
    this.referenceType,
    this.referenceId,
    this.createdAt,
    this.postedAt,
  });

  double get totalDebit => lines.fold(0, (sum, l) => sum + l.debit);
  double get totalCredit => lines.fold(0, (sum, l) => sum + l.credit);
  bool get isBalanced => (totalDebit - totalCredit).abs() < 0.01;

  Map<String, dynamic> toMap() {
    return {
      'number': number,
      'date': Timestamp.fromDate(date),
      'description': description,
      'lines': lines.map((l) => l.toMap()).toList(),
      'status': status.name,
      'createdBy': createdBy,
      'referenceType': referenceType,
      'referenceId': referenceId,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : Timestamp.fromDate(DateTime.now()),
      'postedAt': postedAt != null ? Timestamp.fromDate(postedAt!) : null,
    };
  }

  factory AccountingEntryModel.fromMap(Map<String, dynamic> map, String docId) {
    return AccountingEntryModel(
      id: docId,
      number: map['number'] ?? '',
      date: (map['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      description: map['description'] ?? '',
      lines: (map['lines'] as List? ?? []).map((l) => AccountingEntryLine.fromMap(l as Map<String, dynamic>)).toList(),
      status: EntryStatus.values.byName(map['status'] ?? 'borrador'),
      createdBy: map['createdBy'],
      referenceType: map['referenceType'],
      referenceId: map['referenceId'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      postedAt: (map['postedAt'] as Timestamp?)?.toDate(),
    );
  }
}
