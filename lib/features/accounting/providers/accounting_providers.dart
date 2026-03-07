import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:techsc/features/accounting/models/transaction_model.dart';
import 'package:techsc/features/accounting/services/accounting_service.dart';

/// Proveedor para el servicio de contabilidad.
final accountingServiceProvider = Provider<AccountingService>((ref) {
  return AccountingService();
});

/// Proveedor del rango de fechas para filtrar las transacciones contables.
/// Por defecto se inicializa con los últimos 30 días.
final accountingDateRangeProvider = StateProvider<DateTimeRange>((ref) {
  return DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 30)),
    end: DateTime.now(),
  );
});

/// Proveedor que expone un flujo (Stream) de las transacciones contables
/// basado en el rango de fechas seleccionado por el usuario.
final transactionsStreamProvider = StreamProvider<List<TransactionModel>>((
  ref,
) {
  final service = ref.watch(accountingServiceProvider);
  final range = ref.watch(accountingDateRangeProvider);

  return service.getTransactionsStream(start: range.start, end: range.end);
});
