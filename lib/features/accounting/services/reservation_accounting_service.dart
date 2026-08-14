import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:tscomputer/features/accounting/models/transaction_model.dart';
import 'package:tscomputer/features/accounting/services/account_mapper.dart';
import 'package:tscomputer/features/accounting/services/accounting_service.dart';
import 'package:tscomputer/features/accounting/services/journal_entry_service.dart';
import 'package:tscomputer/features/accounting/services/receivable_service.dart';
import 'package:tscomputer/features/inventory/models/inventory_movement_model.dart';
import 'package:tscomputer/features/inventory/services/inventory_service.dart';

/// Servicio centralizado para la lógica contable e inventario de reservaciones.
///
/// Extraído de `reservation_detail_page.dart` para:
/// - Separar lógica de negocio de la UI
/// - Hacer testeable y reutilizable la lógica
/// - Unificar mapeo de cuentas con OrderService via AccountMapper
/// - Evitar duplicación de registros
class ReservationAccountingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AccountingService _accountingService = AccountingService();

  // ─────────────────────────────────────────────────────────
  //  INVENTARIO
  // ─────────────────────────────────────────────────────────

  /// Descuenta inventario por los repuestos usados en un servicio técnico.
  ///
  /// Usa `AccountMapper.inventoryAccountForProduct()` para determinar la
  /// subcuenta de inventario correcta (1.1.03.xx) según el nombre del producto.
  /// Idempotente: verifica que no exista un movimiento previo para la misma reserva.
  Future<void> deductInventoryForParts({
    required String reservationId,
    required String clientName,
    required List<Map<String, dynamic>> parts,
    String userId = '',
  }) async {
    if (parts.isEmpty) return;

    // Verificar idempotencia
    final existingMovements = await _firestore
        .collection('inventory_movements')
        .where('reason',
            isEqualTo: 'Servicio Técnico #$reservationId - $clientName')
        .limit(1)
        .get();
    if (existingMovements.docs.isNotEmpty) {
      debugPrint('⏭️ Inventario ya descontado para reserva $reservationId');
      return;
    }

    // Agrupar cantidades por producto
    final Map<String, int> productQuantities = {};
    final Map<String, String> productNames = {};
    for (final part in parts) {
      final pid = part['productId'] as String?;
      if (pid == null || pid.isEmpty) continue;
      productQuantities[pid] = (productQuantities[pid] ?? 0) + 1;
      productNames[pid] = part['name'] ?? '';
    }

    if (productQuantities.isEmpty) return;

    // Verificar stock disponible
    for (final entry in productQuantities.entries) {
      final doc = await _firestore
          .collection('products')
          .doc(entry.key)
          .get();
      if (!doc.exists) continue;
      final stock = (doc.data()?['stock'] as num?)?.toInt() ?? 0;
      if (stock < entry.value) {
        throw Exception(
          'Stock insuficiente para ${productNames[entry.key]}: '
          'disponible $stock, requerido ${entry.value}',
        );
      }
    }

    // Descontar cada producto con la cuenta de inventario correcta
    final reason = 'Servicio Técnico #$reservationId - $clientName';
    for (final entry in productQuantities.entries) {
      final productName = productNames[entry.key] ?? '';

      // 1) Intentar mapear por categoría del producto (campo real del catálogo)
      String? inventoryAccountCode;
      try {
        final productDoc = await _firestore
            .collection('products')
            .doc(entry.key)
            .get();
        if (productDoc.exists && productDoc.data() != null) {
          final categoryName =
              (productDoc.data()!['category'] ?? '').toString();
          inventoryAccountCode =
              AccountMapper.inventoryAccountForCategory(categoryName);
        }
      } catch (_) {}

      // 2) Fallback: mapear por nombre del producto
      inventoryAccountCode ??=
          AccountMapper.inventoryAccountForProduct(productName);

      await InventoryService().registerMovement(
        productId: entry.key,
        type: MovementType.outward,
        quantity: entry.value,
        reason: reason,
        userId: userId,
        inventoryAccountCode: inventoryAccountCode,
      );
    }

    debugPrint(
        '✅ Inventario descontado para reserva $reservationId: ${productQuantities.length} productos');
  }

  /// Restaura inventario al cancelar un servicio técnico completado.
  ///
  /// Busca los movimientos de inventario previos de la reserva y crea
  /// movimientos de entrada inversos para restaurar el stock.
  Future<void> restoreInventoryForParts({
    required String reservationId,
    required String clientName,
  }) async {
    // Buscar movimientos de inventario existentes para esta reserva
    final existingMovements = await _firestore
        .collection('inventory_movements')
        .where('reason',
            isEqualTo: 'Servicio Técnico #$reservationId - $clientName')
        .get();

    if (existingMovements.docs.isEmpty) {
      debugPrint('ℹ️ No hay inventario que restaurar para reserva $reservationId');
      return;
    }

    // Restaurar cada movimiento
    for (final doc in existingMovements.docs) {
      final data = doc.data();
      final productId = data['productId'] as String? ?? '';
      final quantity = (data['quantity'] as num?)?.toInt() ?? 0;
      if (productId.isEmpty || quantity <= 0) continue;

      await InventoryService().registerMovement(
        productId: productId,
        type: MovementType.inward,
        quantity: quantity,
        reason: 'Reversión Servicio Técnico #$reservationId - $clientName',
        userId: '',
      );
    }

    debugPrint(
        '✅ Inventario restaurado para reserva $reservationId: ${existingMovements.docs.length} productos');
  }

  // ─────────────────────────────────────────────────────────
  //  INGRESO CONTABLE
  // ─────────────────────────────────────────────────────────

  /// Registra el ingreso contable de un servicio técnico completado.
  ///
  /// Es idempotente: usa `reservation_{reservationId}` como ID de transacción.
  /// Divide el total por método de pago (efectivo/tarjeta) y crea asientos
  /// con las cuentas correctas via AccountMapper.
  ///
  /// Retorna true si se registró, false si ya existía (idempotente).
  Future<bool> registerIncome({
    required String reservationId,
    required String serviceType,
    required String clientName,
    required String clientId,
    required double servicesTotal,
    required double partsTotal,
    required String paymentMethod,
    required List<Map<String, dynamic>> selectedParts,
    bool applyVAT = false,
  }) async {
    final total = servicesTotal + partsTotal;
    if (total <= 0) return false;

    // ID idempotente: una sola transacción por reserva
    final txId = 'reservation_$reservationId';
    final existingTx = await _firestore
        .collection('accounting_transactions')
        .doc(txId)
        .get();
    if (existingTx.exists) {
      debugPrint(
          '⏭️ Transacción contable ya existe para reserva $reservationId, omitiendo');
      return false;
    }

    // Dividir por método de pago (parts usan su propio paymentMethod)
    double cashTotal = 0.0;
    double cardTotal = 0.0;

    for (final part in selectedParts) {
      final pm = part['paymentMethod'] ?? 'efectivo';
      final price = (part['price'] as num?)?.toDouble() ?? 0.0;
      if (pm == 'tarjeta') {
        cardTotal += price;
      } else {
        cashTotal += price;
      }
    }

    // Mano de obra según método de pago general
    if (servicesTotal > 0) {
      if (paymentMethod == 'tarjeta') {
        cardTotal += servicesTotal;
      } else {
        cashTotal += servicesTotal;
      }
    }

    // Si ambos son 0 (caso raro), usar el total con el método general
    if (cashTotal <= 0 && cardTotal <= 0) {
      if (paymentMethod == 'tarjeta') {
        cardTotal = total;
      } else {
        cashTotal = total;
      }
    }

    // Calcular subtotal e IVA
    final subtotal = applyVAT ? total / 1.15 : total;
    final vatAmount = applyVAT ? total - subtotal : 0.0;

    // Registrar transacción contable
    final transaction = TransactionModel(
      id: txId,
      type: TransactionType.ingreso,
      category: 'Servicio',
      amount: subtotal,
      vatAmount: vatAmount,
      vatRate: applyVAT ? 0.15 : 0.0,
      total: total,
      date: DateTime.now(),
      description: '$serviceType - $clientName',
      clientIdentification: clientId.isNotEmpty ? clientId : null,
      referenceId: reservationId,
      paymentMethodType: paymentMethod,
    );

    await _accountingService.saveTransaction(transaction);

    // Construir asiento contable
    final incomeAccount = AccountMapper.serviceIncomeAccount(serviceType);
    final List<Map<String, dynamic>> entryLines = [];

    // Débitos por método de pago
    if (cashTotal > 0) {
      entryLines.add({
        'accountCode': '1.1.01.01',
        'debit': cashTotal,
        'credit': 0.0,
      });
    }
    if (cardTotal > 0) {
      entryLines.add({
        'accountCode': '1.1.01.03',
        'debit': cardTotal,
        'credit': 0.0,
      });
    }

    // Crédito IVA débito fiscal
    if (vatAmount > 0) {
      entryLines.add({
        'accountCode': '2.1.02',
        'debit': 0.0,
        'credit': vatAmount,
      });
    }

    // Crédito ingreso por servicio
    entryLines.add({
      'accountCode': incomeAccount,
      'debit': 0.0,
      'credit': subtotal,
    });

    await JournalEntryService().createEntryFromEvent(
      referenceType: 'reservation_income',
      referenceId: reservationId,
      date: DateTime.now(),
      description: '$serviceType - $clientName',
      lines: entryLines,
    );

    debugPrint(
        '✅ Ingreso contable registrado para reserva $reservationId: \$$total');
    return true;
  }

  /// Registra ingreso contable por un monto específico (abono/pago parcial).
  ///
  /// Se usa cuando el cliente realiza un pago y el servicio ya está completado.
  /// Idempotente: usa `reservation_{reservationId}_payment_{paymentIndex}`.
  Future<void> registerIncomeForPayment({
    required String reservationId,
    required String serviceType,
    required String clientName,
    required String clientId,
    required double servicesTotal,
    required double partsTotal,
    required double paidAmount,
    required String paymentMethod,
    required List<Map<String, dynamic>> selectedParts,
    bool applyVAT = false,
  }) async {
    if (paidAmount <= 0) return;

    // Calcular subtotal e IVA del monto pagado
    final subtotal = applyVAT ? paidAmount / 1.15 : paidAmount;
    final vatAmount = applyVAT ? paidAmount - subtotal : 0.0;

    // Determinar cuenta de efectivo/bancos según método
    final cashAccount = AccountMapper.cashAccountForMethod(paymentMethod);
    final incomeAccount = AccountMapper.serviceIncomeAccount(serviceType);

    // Transacción contable
    final txId = 'reservation_${reservationId}_payment_${DateTime.now().millisecondsSinceEpoch}';
    final tx = TransactionModel(
      id: txId,
      type: TransactionType.ingreso,
      category: 'Servicio',
      amount: subtotal,
      vatAmount: vatAmount,
      vatRate: applyVAT ? 0.15 : 0.0,
      total: paidAmount,
      date: DateTime.now(),
      description: 'Abono $serviceType - $clientName',
      clientIdentification: clientId.isNotEmpty ? clientId : null,
      referenceId: reservationId,
      paymentMethodType: paymentMethod,
    );

    await _accountingService.saveTransaction(tx);

    // Asiento contable
    final entryLines = <Map<String, dynamic>>[];

    // Débito: Caja/Bancos
    entryLines.add({
      'accountCode': cashAccount,
      'debit': subtotal,
      'credit': 0.0,
    });

    // Crédito: IVA débito fiscal (si aplica)
    if (vatAmount > 0) {
      entryLines.add({
        'accountCode': '2.1.02',
        'debit': 0.0,
        'credit': vatAmount,
      });
    }

    // Crédito: Ingreso por servicio
    entryLines.add({
      'accountCode': incomeAccount,
      'debit': 0.0,
      'credit': subtotal,
    });

    await JournalEntryService().createEntryFromEvent(
      referenceType: 'reservation_income',
      referenceId: '${reservationId}_payment_${DateTime.now().millisecondsSinceEpoch}',
      date: DateTime.now(),
      description: 'Abono $serviceType - $clientName',
      lines: entryLines,
    );

    debugPrint('✅ Ingreso por abono registrado para reserva $reservationId: \$$paidAmount');
  }

  /// Registra ingreso por saldo restante (cuando ya hay abonos previos).
  ///
  /// Idempotente con ID `reservation_{reservationId}_remaining`.
  Future<void> registerRemainingBalance({
    required String reservationId,
    required String serviceType,
    required String clientName,
    required String clientId,
    required double total,
    required double totalPaid,
    required String paymentMethod,
    bool applyVAT = false,
  }) async {
    final balance = (total - totalPaid).clamp(0.0, double.infinity);
    if (balance <= 0) return;

    final txId = 'reservation_${reservationId}_remaining';
    final existing = await _firestore
        .collection('accounting_transactions')
        .doc(txId)
        .get();
    if (existing.exists) {
      debugPrint('⏭️ Transacción $txId ya existe, omitiendo');
      return;
    }

    final subtotal = applyVAT ? balance / 1.15 : balance;
    final vatAmount = applyVAT ? balance - subtotal : 0.0;
    final incomeAccount = AccountMapper.serviceIncomeAccount(serviceType);
    final cashAccount = AccountMapper.cashAccountForMethod(paymentMethod);

    final tx = TransactionModel(
      id: txId,
      type: TransactionType.ingreso,
      category: 'Servicio',
      amount: subtotal,
      vatAmount: vatAmount,
      vatRate: applyVAT ? 0.15 : 0.0,
      total: balance,
      date: DateTime.now(),
      description: 'Saldo restante $serviceType - $clientName',
      clientIdentification: clientId.isNotEmpty ? clientId : null,
      referenceId: reservationId,
      paymentMethodType: paymentMethod,
    );

    await _accountingService.saveTransaction(tx);

    final List<Map<String, dynamic>> entryLines = [
      {'accountCode': cashAccount, 'debit': balance, 'credit': 0.0},
      if (vatAmount > 0)
        {'accountCode': '2.1.02', 'debit': 0.0, 'credit': vatAmount},
      {'accountCode': incomeAccount, 'debit': 0.0, 'credit': subtotal},
    ];

    await JournalEntryService().createEntryFromEvent(
      referenceType: 'reservation_income_remaining',
      referenceId: reservationId,
      date: DateTime.now(),
      description: 'Saldo restante $serviceType - $clientName',
      lines: entryLines,
    );
  }

  // ─────────────────────────────────────────────────────────
  //  CxC (CUENTAS POR COBRAR)
  // ─────────────────────────────────────────────────────────

  /// Crea CxC para el saldo pendiente de una reserva.
  ///
  /// Idempotente: no crea duplicados si ya existe una CxC para esta reserva.
  Future<void> createReceivableForBalance({
    required String reservationId,
    required String clientName,
    String? clientId,
    required double total,
    required double totalPaid,
    required DateTime date,
    String serviceType = '',
  }) async {
    final balance = (total - totalPaid).clamp(0.0, double.infinity);
    if (balance <= 0) return;

    await ReceivableService().autoCreateFromReservation(
      reservationId,
      clientName,
      clientId,
      balance,
      date,
      serviceType: serviceType,
    );
  }

  // ─────────────────────────────────────────────────────────
  //  REVERSIÓN (CANCELACIÓN)
  // ─────────────────────────────────────────────────────────

  /// Registra la reversión contable e inventario al cancelar un servicio completado.
  ///
  /// Idempotente: verifica que no exista una reversión previa.
  Future<void> registerReversal({
    required String reservationId,
    required String clientName,
    required String clientId,
    required double servicesTotal,
    required double partsTotal,
    required String serviceType,
    required String paymentMethod,
    bool applyVAT = false,
  }) async {
    final revId = 'reservation_reversal_$reservationId';
    final existingRev = await _firestore
        .collection('accounting_transactions')
        .doc(revId)
        .get();
    if (existingRev.exists) {
      debugPrint(
          '⏭️ Reversión contable ya existe para reserva $reservationId, omitiendo');
      return;
    }

    final total = servicesTotal + partsTotal;
    if (total <= 0) return;

    final subtotal = applyVAT ? total / 1.15 : total;
    final vatAmount = applyVAT ? total - subtotal : 0.0;
    final incomeAccount = AccountMapper.serviceIncomeAccount(serviceType);
    final cashAccount = AccountMapper.cashAccountForMethod(paymentMethod);

    // Transacción contable (egreso reversión)
    final tx = TransactionModel(
      id: revId,
      type: TransactionType.egreso,
      category: 'Reversión',
      amount: subtotal,
      vatAmount: vatAmount,
      vatRate: applyVAT ? 0.15 : 0.0,
      total: total,
      date: DateTime.now(),
      description: 'Reversión servicio #$reservationId - $clientName',
      clientIdentification: clientId.isNotEmpty ? clientId : null,
      referenceId: reservationId,
    );

    await _accountingService.saveTransaction(tx);

    // Asiento de reversión (invertir el asiento original)
    final List<Map<String, dynamic>> entryLines = [
      {'accountCode': incomeAccount, 'debit': subtotal, 'credit': 0.0},
      if (vatAmount > 0)
        {'accountCode': '2.1.02', 'debit': vatAmount, 'credit': 0.0},
      {'accountCode': cashAccount, 'debit': 0.0, 'credit': total},
    ];

    await JournalEntryService().createEntryFromEvent(
      referenceType: 'reservation_reversal',
      referenceId: reservationId,
      date: DateTime.now(),
      description: 'Reversión servicio #$reservationId - $clientName',
      lines: entryLines,
    );

    // Restaurar inventario
    await restoreInventoryForParts(
      reservationId: reservationId,
      clientName: clientName,
    );

    debugPrint('✅ Reversión + inventario restaurado para reserva $reservationId');
  }
}
