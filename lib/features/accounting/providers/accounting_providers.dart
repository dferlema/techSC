import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tscomputer/features/accounting/models/transaction_model.dart';
import 'package:tscomputer/features/accounting/services/accounting_service.dart';
import 'package:tscomputer/features/accounting/services/chart_of_accounts_service.dart';
import 'package:tscomputer/features/accounting/services/journal_entry_service.dart';
import 'package:tscomputer/features/accounting/services/receivable_service.dart';
import 'package:tscomputer/features/accounting/services/payable_service.dart';
import 'package:tscomputer/features/accounting/services/bank_reconciliation_service.dart';
import 'package:tscomputer/features/accounting/services/financial_report_service.dart';
import 'package:tscomputer/features/accounting/services/payroll_service.dart';
import 'package:tscomputer/features/accounting/services/profitability_service.dart';
import 'package:tscomputer/features/accounting/services/service_profitability_service.dart';
import 'package:tscomputer/features/accounting/services/purchase_invoice_service.dart';
import 'package:tscomputer/features/accounting/models/chart_of_account_model.dart';
import 'package:tscomputer/features/accounting/models/accounting_entry_model.dart';
import 'package:tscomputer/features/accounting/models/receivable_model.dart';
import 'package:tscomputer/features/accounting/models/payable_model.dart';
import 'package:tscomputer/features/accounting/models/purchase_invoice_model.dart';
import 'package:tscomputer/features/accounting/models/bank_reconciliation_model.dart';
import 'package:tscomputer/features/accounting/models/payroll_model.dart';
import 'package:tscomputer/features/accounting/models/service_profitability_model.dart';

final purchaseInvoiceServiceProvider = Provider<PurchaseInvoiceService>((ref) {
  return PurchaseInvoiceService();
});

final purchaseInvoicesStreamProvider =
    StreamProvider<List<PurchaseInvoiceModel>>((ref) {
      return ref
          .watch(purchaseInvoiceServiceProvider)
          .getInvoicesStream()
          .handleError(
            (error) => debugPrint('Stream error [purchaseInvoices]: $error'),
          );
    });

final accountingServiceProvider = Provider<AccountingService>((ref) {
  return AccountingService();
});

final chartOfAccountsServiceProvider = Provider<ChartOfAccountsService>((ref) {
  return ChartOfAccountsService();
});

final journalEntryServiceProvider = Provider<JournalEntryService>((ref) {
  return JournalEntryService();
});

final receivableServiceProvider = Provider<ReceivableService>((ref) {
  return ReceivableService();
});

final payableServiceProvider = Provider<PayableService>((ref) {
  return PayableService();
});

final bankReconciliationServiceProvider = Provider<BankReconciliationService>((
  ref,
) {
  return BankReconciliationService();
});

final financialReportServiceProvider = Provider<FinancialReportService>((ref) {
  return FinancialReportService();
});

final profitabilityServiceProvider = Provider<ProfitabilityService>((ref) {
  return ProfitabilityService();
});

final profitabilityReportProvider = FutureProvider<ProfitabilityReport>((ref) {
  return ref.watch(profitabilityServiceProvider).getReport();
});

final accountingDateRangeProvider = StateProvider<DateTimeRange>((ref) {
  return DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
});

final transactionsStreamProvider = StreamProvider<List<TransactionModel>>((
  ref,
) {
  final service = ref.watch(accountingServiceProvider);
  final range = ref.watch(accountingDateRangeProvider);
  return service
      .getTransactionsStream(start: range.start, end: range.end)
      .handleError(
        (error) => debugPrint('Stream error [transactions]: $error'),
      );
});

final accountsStreamProvider = StreamProvider<List<ChartOfAccountModel>>((ref) {
  return ref
      .watch(chartOfAccountsServiceProvider)
      .getAccountsStream()
      .handleError((error) => debugPrint('Stream error [accounts]: $error'));
});

final entriesStreamProvider = StreamProvider<List<AccountingEntryModel>>((ref) {
  return ref
      .watch(journalEntryServiceProvider)
      .getEntriesStream()
      .handleError(
        (error) => debugPrint('Stream error [journalEntries]: $error'),
      );
});

final receivablesStreamProvider = StreamProvider<List<ReceivableModel>>((ref) {
  return ref
      .watch(receivableServiceProvider)
      .getAllReceivablesStream()
      .handleError((error) => debugPrint('Stream error [receivables]: $error'));
});

final pendingReceivablesStreamProvider = StreamProvider<List<ReceivableModel>>((
  ref,
) {
  return ref
      .watch(receivableServiceProvider)
      .getPendingReceivablesStream()
      .handleError(
        (error) => debugPrint('Stream error [pendingReceivables]: $error'),
      );
});

final payablesStreamProvider = StreamProvider<List<PayableModel>>((ref) {
  return ref
      .watch(payableServiceProvider)
      .getAllPayablesStream()
      .handleError((error) => debugPrint('Stream error [payables]: $error'));
});

final pendingPayablesStreamProvider = StreamProvider<List<PayableModel>>((ref) {
  return ref
      .watch(payableServiceProvider)
      .getPendingPayablesStream()
      .handleError(
        (error) => debugPrint('Stream error [pendingPayables]: $error'),
      );
});

final reconciliationsStreamProvider =
    StreamProvider<List<BankReconciliationModel>>((ref) {
      return ref
          .watch(bankReconciliationServiceProvider)
          .getAllStream()
          .handleError(
            (error) => debugPrint('Stream error [reconciliations]: $error'),
          );
    });

final payrollServiceProvider = Provider<PayrollService>((ref) {
  return PayrollService();
});

final payrollStreamProvider = StreamProvider<List<PayrollModel>>((ref) {
  return ref
      .watch(payrollServiceProvider)
      .getPayrollsStream()
      .handleError((error) => debugPrint('Stream error [payroll]: $error'));
});

final serviceProfitabilityServiceProvider =
    Provider<ServiceProfitabilityService>((ref) {
      return ServiceProfitabilityService();
    });

final serviceProfitabilityReportProvider =
    FutureProvider<ServiceProfitabilityReport>((ref) {
      return ref.watch(serviceProfitabilityServiceProvider).getReport();
    });
