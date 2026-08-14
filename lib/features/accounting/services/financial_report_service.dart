import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tscomputer/features/accounting/models/accounting_entry_model.dart';
import 'package:tscomputer/features/accounting/models/transaction_model.dart';
import 'package:tscomputer/features/accounting/services/accounting_calculator.dart';

/// Servicio de reportes financieros calculados a partir de los asientos contables
/// (plan de cuentas de 199 cuentas) en lugar de la capa simplificada de transacciones.
class FinancialReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Asientos y mapa código→nombre de cuenta para enriquecer los reportes.
  Future<(List<AccountingEntryModel>, Map<String, double>, Map<String, String>)> _loadBalances(DateTime start, DateTime end) async {
    final entries = await _getPostedEntries(start, end);
    final balances = AccountingCalculator.accountBalances(entries);
    final names = <String, String>{};
    for (final e in entries) {
      for (final l in e.lines) {
        if (l.accountCode.isNotEmpty) names[l.accountCode] = l.accountName;
      }
    }
    return (entries, balances, names);
  }

  Future<Map<String, dynamic>> getBalanceSheet(DateTime asOf) async {
    final (_, balances, names) = await _loadBalances(DateTime(asOf.year, 1, 1), asOf);
    final result = AccountingCalculator.balanceSheet(balances);
    return _withAccountDetail(result, balances, names);
  }

  Future<Map<String, dynamic>> getIncomeStatement(DateTime start, DateTime end) async {
    final (_, balances, names) = await _loadBalances(start, end);
    final result = AccountingCalculator.incomeStatement(balances);
    return _withAccountDetail(result, balances, names);
  }

  /// Enriquecimiento con el desglose por cuenta del plan de cuentas para el PDF.
  /// - Activo (1.x), Pasivo (2.x), Patrimonio/Capital (3.x).
  /// - Ingresos (4.x), Gastos (5.x, 6.x).
  Map<String, dynamic> _withAccountDetail(
      Map<String, dynamic> result, Map<String, double> balances, Map<String, String> names) {
    List<Map<String, dynamic>> detail(String prefix) => AccountingCalculator.leafAccounts(balances, prefix)
        .map((e) => {'code': e['code'], 'name': names[e['code']] ?? e['code'], 'balance': e['balance']})
        .toList();

    result['detalleActivo'] = detail('1');
    result['detallePasivo'] = detail('2');
    result['detallePatrimonio'] = detail('3');
    result['detalleIngresos'] = detail('4');
    result['detalleGastos'] = [...detail('5'), ...detail('6')];
    return result;
  }

  Future<Map<String, dynamic>> getGeneralLedger(String accountName, DateTime start, DateTime end) async {
    final entries = await _getPostedEntries(start, end);
    final filtered = entries.where((e) =>
        e.description.toLowerCase().contains(accountName.toLowerCase()) ||
        e.lines.any((l) => l.accountName.toLowerCase().contains(accountName.toLowerCase()) ||
            l.accountCode.toLowerCase().contains(accountName.toLowerCase()))).toList();

    double totalDebitos = 0;
    double totalCreditos = 0;
    final transactionModels = <TransactionModel>[];

    for (final entry in filtered) {
      for (final line in entry.lines) {
        if (line.accountName.toLowerCase().contains(accountName.toLowerCase()) ||
            line.accountCode.toLowerCase().contains(accountName.toLowerCase())) {
          totalDebitos += line.debit;
          totalCreditos += line.credit;
        }
      }
      if (entry.lines.any((l) => l.accountName.toLowerCase().contains(accountName.toLowerCase()) ||
          l.accountCode.toLowerCase().contains(accountName.toLowerCase()))) {
        final deb = entry.lines.where((l) => l.debit > 0 && (l.accountName.toLowerCase().contains(accountName.toLowerCase()) ||
                l.accountCode.toLowerCase().contains(accountName.toLowerCase())))
            .fold(0.0, (s, l) => s + l.debit);
        final cre = entry.lines.where((l) => l.credit > 0 && (l.accountName.toLowerCase().contains(accountName.toLowerCase()) ||
                l.accountCode.toLowerCase().contains(accountName.toLowerCase())))
            .fold(0.0, (s, l) => s + l.credit);
        final tipo = cre > deb ? TransactionType.ingreso : TransactionType.egreso;
        transactionModels.add(TransactionModel(
          id: entry.id,
          type: tipo,
          category: entry.lines.firstWhere((l) => l.debit > 0 || l.credit > 0,
              orElse: () => entry.lines.first).accountName,
          amount: deb,
          vatAmount: 0.0,
          vatRate: 0.0,
          total: deb > cre ? deb : cre,
          date: entry.date,
          description: entry.description,
        ));
      }
    }

    return {
      'transactions': transactionModels,
      'saldoInicial': 0.0,
      'totalDebitos': totalDebitos,
      'totalCreditos': totalCreditos,
      'saldoFinal': totalCreditos - totalDebitos,
    };
  }

  /// Reporte de IVA calculado desde los asientos:
  ///   IVA ventas = créditos a IVA Débito (2.1.02)
  ///   IVA compras = débitos a IVA Crédito (1.1.04)
  Future<Map<String, dynamic>> getIvaReport(DateTime start, DateTime end) async {
    final entries = await _getPostedEntries(start, end);

    double ivaVentas = 0, baseVentas = 0, totalVentasConIva = 0;
    double ivaCompras = 0, baseCompras = 0, totalComprasConIva = 0;
    final transacciones = <TransactionModel>[];

    for (final entry in entries) {
      final deb = <String, double>{};
      final cre = <String, double>{};
      for (final line in entry.lines) {
        if (line.debit > 0) deb[line.accountCode] = (deb[line.accountCode] ?? 0.0) + line.debit;
        if (line.credit > 0) cre[line.accountCode] = (cre[line.accountCode] ?? 0.0) + line.credit;
      }

      final ivaCredito = deb['1.1.04'] ?? 0.0;      // IVA de compras
      final ivaDebito = cre['2.1.02'] ?? 0.0;       // IVA de ventas

      if (ivaCredito > 0) {
        final base = entry.lines.where((l) => l.debit > 0 && l.accountCode != '1.1.04')
            .fold(0.0, (s, l) => s + l.debit);
        ivaCompras += ivaCredito;
        baseCompras += base;
        totalComprasConIva += base + ivaCredito;
        transacciones.add(TransactionModel(
          id: entry.id,
          type: TransactionType.egreso,
          category: 'IVA Compra',
          amount: base,
          vatAmount: ivaCredito,
          vatRate: base > 0 ? ivaCredito / base : 0.0,
          total: base + ivaCredito,
          date: entry.date,
          description: entry.description,
        ));
      }

      if (ivaDebito > 0) {
        final base = entry.lines.where((l) => l.credit > 0 && l.accountCode != '2.1.02')
            .fold(0.0, (s, l) => s + l.credit);
        ivaVentas += ivaDebito;
        baseVentas += base;
        totalVentasConIva += base + ivaDebito;
        transacciones.add(TransactionModel(
          id: entry.id,
          type: TransactionType.ingreso,
          category: 'IVA Venta',
          amount: base,
          vatAmount: ivaDebito,
          vatRate: base > 0 ? ivaDebito / base : 0.0,
          total: base + ivaDebito,
          date: entry.date,
          description: entry.description,
        ));
      }
    }

    transacciones.sort((a, b) => b.date.compareTo(a.date));

    return {
      'ivaVentas': ivaVentas,
      'baseVentas': baseVentas,
      'totalVentasConIva': totalVentasConIva,
      'ivaCompras': ivaCompras,
      'baseCompras': baseCompras,
      'totalComprasConIva': totalComprasConIva,
      'ivaNeto': ivaVentas - ivaCompras,
      'transacciones': transacciones,
    };
  }

  /// Envejecimiento de CxC
  Future<Map<String, dynamic>> getReceivablesAging() async {
    final receivables = await _getAllReceivables();
    return _computeAging(receivables, 'balance', 'dueDate');
  }

  /// Envejecimiento de CxP
  Future<Map<String, dynamic>> getPayablesAging() async {
    final payables = await _getAllPayables();
    return _computeAging(payables, 'balance', 'dueDate');
  }

  Map<String, dynamic> _computeAging(List<Map<String, dynamic>> items, String amountField, String dateField) {
    double r0_30 = 0, r31_60 = 0, r61_90 = 0, r90plus = 0;
    final now = DateTime.now();

    for (final item in items) {
      final status = item['status'] as String? ?? '';
      if (status == 'pagada' || status == 'anulada') continue;
      final balance = (item[amountField] as num?)?.toDouble() ?? 0;
      if (balance <= 0) continue;
      final dueDate = (item[dateField] as Timestamp?)?.toDate();
      if (dueDate == null) {
        r0_30 += balance;
        continue;
      }
      final daysOverdue = now.difference(dueDate).inDays;
      if (daysOverdue <= 30) {
        r0_30 += balance;
      } else if (daysOverdue <= 60) {
        r31_60 += balance;
      } else if (daysOverdue <= 90) {
        r61_90 += balance;
      } else {
        r90plus += balance;
      }
    }

    return {
      '0_30': r0_30,
      '31_60': r31_60,
      '61_90': r61_90,
      '90plus': r90plus,
      'total': r0_30 + r31_60 + r61_90 + r90plus,
    };
  }

  Future<List<Map<String, dynamic>>> _getAllReceivables() async {
    final snap = await _firestore.collection('accounts_receivable').get();
    return snap.docs.map((d) => d.data()..['id'] = d.id).toList();
  }

  Future<List<Map<String, dynamic>>> _getAllPayables() async {
    final snap = await _firestore.collection('accounts_payable').get();
    return snap.docs.map((d) => d.data()..['id'] = d.id).toList();
  }

  Future<List<AccountingEntryModel>> _getPostedEntries(DateTime start, DateTime end) async {
    final snapshot = await _firestore
        .collection('accounting_entries')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(DateTime(start.year, start.month, start.day)))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(DateTime(end.year, end.month, end.day, 23, 59, 59)))
        .orderBy('date', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => AccountingEntryModel.fromMap(doc.data(), doc.id))
        .where((e) => e.status == EntryStatus.contabilizado)
        .toList();
  }
}
