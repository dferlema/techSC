import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:tscomputer/core/services/document_id_service.dart';
import 'package:tscomputer/features/orders/models/order_model.dart';
import 'package:tscomputer/features/accounting/models/transaction_model.dart';
import 'package:tscomputer/features/accounting/services/accounting_service.dart';
import 'package:tscomputer/features/accounting/services/receivable_service.dart';
import 'package:tscomputer/features/accounting/services/journal_entry_service.dart';
import 'package:tscomputer/features/accounting/services/account_mapper.dart';
import 'package:tscomputer/features/inventory/models/inventory_movement_model.dart';
import 'package:tscomputer/core/utils/firestore_retry.dart';
import 'package:tscomputer/features/inventory/services/inventory_service.dart';

/// Servicio para gestionar pedidos.
///
/// Integrado con el módulo contable: al marcar un pedido como entregado/completado,
/// se registra automáticamente un ingreso contable.
class OrderService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final AccountingService _accountingService = AccountingService();
  static const String _collection = 'orders';

  /// Stream de pedidos de un usuario específico.
  Stream<List<OrderModel>> getUserOrders(String uid) {
    return _db
        .collection(_collection)
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => OrderModel.fromFirestore(doc))
              .toList();
        });
  }

  /// Stream de todos los pedidos (para Admin/Vendedor).
  Stream<List<OrderModel>> getAllOrders() {
    return _db
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => OrderModel.fromFirestore(doc))
              .toList();
        });
  }

  /// Obtiene un pedido por su ID.
  Future<OrderModel?> getOrder(String orderId) async {
    final doc = await retryFirestore(() => _db.collection(_collection).doc(orderId).get());
    if (doc.exists) {
      return OrderModel.fromFirestore(doc);
    }
    return null;
  }

  /// Actualiza el estado de un pedido.
  /// Si el estado cambia a 'entregado' o 'completado', se registra
  /// automáticamente un ingreso contable con el total del pedido.
  /// Si el estado cambia a 'cancelado' desde un estado completado,
  /// se registra automáticamente una reversión contable.
  Future<void> updateOrderStatus(String orderId, String status) async {
    final estadosCompletados = [
      'entregado',
      'completado',
      'completed',
      'delivered',
    ];
    final estadosCancelacion = ['cancelado', 'cancelled', 'rechazado', 'rejected'];
    final isComplete = estadosCompletados.contains(status.toLowerCase());
    final isCancellation = estadosCancelacion.contains(status.toLowerCase());

    final Map<String, dynamic> updates = {'status': status};

    final doc = await retryFirestore(() => _db.collection(_collection).doc(orderId).get());
    if (!doc.exists) {
      await _db.collection(_collection).doc(orderId).update(updates);
      return;
    }

    final data = doc.data() as Map<String, dynamic>;
    final currentStatus = (data['status'] as String?)?.toLowerCase() ?? '';
    final wasComplete = estadosCompletados.contains(currentStatus);

    if (isComplete) {
      final total = (data['total'] as num?)?.toDouble() ?? 0.0;
      final totalPaid = (data['totalPaid'] as num?)?.toDouble() ?? 0.0;
      if (totalPaid >= total) {
        updates['paymentStatus'] = 'paid';
      } else if (totalPaid > 0) {
        updates['paymentStatus'] = 'partial';
      }
      if (totalPaid > 0) {
        updates['paidAmount'] = totalPaid;
      }
    }

    await _db.collection(_collection).doc(orderId).update(updates);

    // --- Integración Contable ---
    if (isComplete) {
      await registerOrderIncome(orderId);
      await _deductInventoryForOrder(orderId, data);
    } else if (isCancellation && wasComplete) {
      await _registerOrderReversal(orderId, data);
      await _restoreInventoryForOrder(orderId, data);
    }
  }

  Future<void> _registerOrderReversal(String orderId, Map<String, dynamic> data) async {
    try {
      final revId = 'order_reversal_$orderId';
      final existingRev = await _db.collection('accounting_transactions').doc(revId).get();
      if (existingRev.exists) {
        debugPrint('⏭️ Reversión contable ya existe para pedido $orderId, omitiendo');
        return;
      }
      final total = (data['total'] as num?)?.toDouble() ?? 0.0;
      if (total <= 0) return;
      final originalQuote = data['originalQuote'] as Map<String, dynamic>?;
      final bool applyTax = originalQuote?['applyTax'] ?? false;
      final double taxRate = (originalQuote?['taxRate'] as num?)?.toDouble() ?? 0.15;
      double subtotal = total;
      double vatAmount = 0.0;
      if (applyTax && taxRate > 0) {
        subtotal = total / (1 + taxRate);
        vatAmount = total - subtotal;
      }
      final tx = TransactionModel(
        id: revId,
        type: TransactionType.egreso,
        category: 'Reversión',
        amount: subtotal,
        vatAmount: vatAmount,
        vatRate: vatAmount > 0 ? taxRate : 0,
        total: total,
        date: DateTime.now(),
        description: 'Reversión pedido #${orderId.length > 8 ? orderId.substring(0, 8) : orderId}',
        referenceId: orderId,
      );
      await _accountingService.saveTransaction(tx);
      debugPrint('✅ Reversión contable registrada para pedido $orderId');
    } catch (e) {
      debugPrint('⚠️ Error al registrar reversión: $e');
    }
  }

  /// Mapea un item de venta (nombre + tipo) a su cuenta de ingreso 4.x.xx
  /// según el BLOQUE 3.3 del prompt (subcategorías).
  /// Usa AccountMapper unificado para mantener consistencia con reservaciones.
  String _incomeAccountFor(String itemName, String itemType) {
    if (itemType == 'service') {
      return AccountMapper.serviceIncomeAccount(itemName);
    }
    return AccountMapper.productIncomeAccount(itemName);
  }

  /// Mapea un item de venta (nombre + tipo) a la cuenta de INVENTARIO 1.1.03.xx
  /// que será acreditada al registrar el COGS (salida de inventario).
  /// Usa AccountMapper unificado para mantener consistencia con reservaciones.
  String _inventoryAccountFor(String itemName, String itemType, {String categoryName = ''}) {
    if (itemType == 'service') return '1.1.03.05'; // Insumos técnicos de servicio
    final fromCategory = AccountMapper.inventoryAccountForCategory(categoryName);
    return fromCategory ?? AccountMapper.inventoryAccountForProduct(itemName);
  }

  Future<void> _deductInventoryForOrder(String orderId, Map<String, dynamic> data) async {
    try {
      final originalQuote = data['originalQuote'] as Map<String, dynamic>?;
      if (originalQuote == null) return;
      final items = originalQuote['items'] as List<dynamic>? ?? [];
      final clientName = data['shippingAddress']?['fullName'] ?? data['clientName'] ?? 'Cliente';

      for (final item in items) {
        final type = item['type'] as String? ?? '';
        if (type != 'product') continue;
        final productId = item['id'] as String? ?? '';
        final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
        if (productId.isEmpty || quantity <= 0) continue;

        final existing = await _db.collection('accounting_transactions')
            .where('description', isEqualTo: 'COGS: ${item['name']} x$quantity - Pedido #${orderId.length > 8 ? orderId.substring(0, 8) : orderId}')
            .limit(1)
            .get();
        if (existing.docs.isNotEmpty) {
          debugPrint('⏭️ COGS ya registrado para ${item['name']} en pedido $orderId');
          continue;
        }

        // Obtener categoría del producto desde Firestore
        String categoryName = '';
        try {
          final productDoc = await _db.collection('products').doc(productId).get();
          if (productDoc.exists && productDoc.data() != null) {
            categoryName = (productDoc.data()!['category'] ?? '').toString();
          }
        } catch (_) {}

        await InventoryService().registerMovement(
          productId: productId,
          type: MovementType.outward,
          quantity: quantity,
          reason: 'Pedido #${orderId.length > 8 ? orderId.substring(0, 8) : orderId} - $clientName',
          userId: '',
          inventoryAccountCode: _inventoryAccountFor(item['name']?.toString() ?? '', item['type']?.toString() ?? '', categoryName: categoryName),
        );
      }
    } catch (e) {
      debugPrint('⚠️ Error al descontar inventario del pedido: $e');
    }
  }

  Future<void> _restoreInventoryForOrder(String orderId, Map<String, dynamic> data) async {
    try {
      final originalQuote = data['originalQuote'] as Map<String, dynamic>?;
      if (originalQuote == null) return;
      final items = originalQuote['items'] as List<dynamic>? ?? [];

      for (final item in items) {
        final type = item['type'] as String? ?? '';
        if (type != 'product') continue;
        final productId = item['id'] as String? ?? '';
        final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
        if (productId.isEmpty || quantity <= 0) continue;

        await InventoryService().registerMovement(
          productId: productId,
          type: MovementType.inward,
          quantity: quantity,
          reason: 'Reversión pedido #${orderId.length > 8 ? orderId.substring(0, 8) : orderId}',
          userId: '',
        );
      }
    } catch (e) {
      debugPrint('⚠️ Error al restaurar inventario del pedido cancelado: $e');
    }
  }

  /// Registra el ingreso contable correspondiente a un pedido completado o pagado.
  /// Es idempotente: usa `order_$orderId` como ID para evitar transacciones duplicadas.
  /// Construye los débitos dinámicamente según el método de pago de cada abono:
  ///   efectivo → Caja (1.1.01.01), transferencia/payphone/tarjeta → Bancos (1.1.01.03),
  ///   crédito → CxC Facturas (1.1.02.01), saldo pendiente → CxC Facturas (1.1.02.01).
  Future<void> registerOrderIncome(String orderId) async {
    try {
      final doc = await _db.collection(_collection).doc(orderId).get();
      if (!doc.exists) return;

      final data = doc.data() as Map<String, dynamic>;
      final originalQuote = data['originalQuote'] as Map<String, dynamic>?;

      double total = 0.0;
      if (data['total'] != null) {
        total = (data['total'] as num).toDouble();
      } else if (originalQuote != null && originalQuote['total'] != null) {
        total = (originalQuote['total'] as num).toDouble();
      }

      if (total <= 0) return;

      final bool applyTax = originalQuote?['applyTax'] ?? false;
      final double taxRate = (originalQuote?['taxRate'] as num?)?.toDouble() ?? 0.15;
      double subtotal = total;
      double vatAmount = 0.0;
      if (applyTax && taxRate > 0) {
        subtotal = total / (1 + taxRate);
        vatAmount = total - subtotal;
      }

      final String clientIdentification =
          data['userId'] ?? originalQuote?['customerUid'] ?? originalQuote?['clientId'] ?? '';

      final transactionId = 'order_$orderId';

      final existingTx = await _db.collection('accounting_transactions').doc(transactionId).get();
      if (existingTx.exists) {
        debugPrint('⏭️ Transacción contable ya existe para pedido $orderId, omitiendo');
        return;
      }

      // ─── Leer abonos registrados y agrupar por método de pago ───
      final paymentsSnap = await _db.collection(_collection).doc(orderId).collection('payments').get();
      final Map<String, double> amountsByMethod = {};
      double cashTotal = 0.0;
      for (final pDoc in paymentsSnap.docs) {
        final pMethod = (pDoc.data()['method'] as String?) ?? 'efectivo';
        final pAmount = (pDoc.data()['amount'] as num?)?.toDouble() ?? 0.0;
        amountsByMethod[pMethod] = (amountsByMethod[pMethod] ?? 0.0) + pAmount;
        cashTotal += pAmount;
      }

      // Saldo pendiente (no pagado ni registrado como crédito)
      final balance = (total - cashTotal).clamp(0.0, double.infinity);

      // ─── Construir líneas del asiento contable ───
      String accountForMethod(String method) {
        switch (method) {
          case 'efectivo': return '1.1.01.01';   // Caja General
          case 'transferencia': return '1.1.01.03'; // Bancos
          case 'payphone': return '1.1.01.03';      // Bancos
          case 'tarjeta': return '1.1.01.03';       // Bancos
          case 'credito': return '1.1.02.01';    // Clientes - Facturas
          default: return '1.1.01.01';
        }
      }

      final List<Map<String, dynamic>> entryLines = [];

      // Débitos por cada método de pago (proporcional al TOTAL con IVA)
      for (final entry in amountsByMethod.entries) {
        final ratio = total > 0 ? entry.value / total : 0.0;
        final debitAmount = double.parse((ratio * total).toStringAsFixed(2));
        if (debitAmount > 0) {
          entryLines.add({'accountCode': accountForMethod(entry.key), 'debit': debitAmount, 'credit': 0.0});
        }
      }

      // Débito por saldo pendiente (CxC) sobre el total
      if (balance > 0) {
        final ratio = total > 0 ? balance / total : 0.0;
        final debitAmount = double.parse((ratio * total).toStringAsFixed(2));
        if (debitAmount > 0) {
          entryLines.add({'accountCode': '1.1.02.01', 'debit': debitAmount, 'credit': 0.0});
        }
      }

      // IVA débito fiscal de ventas (si aplica): se acredita a 2.1.02.
      if (vatAmount > 0) {
        entryLines.add({'accountCode': '2.1.02', 'debit': 0.0, 'credit': vatAmount});
      }

      // ─── Venta crédito: repartir ingreso por subcategoría (BLOQUE 3.3) ───
      //   El ingreso se acredita por el SUBTOTAL (el IVA va a 2.1.02).
      //   Mapeo nombre/tipo del item → cuenta 4.x.xx según el prompt V3
      final items = (originalQuote?['items'] as List<dynamic>?) ?? [];
      final Map<String, double> incomeByAccount = {};
      for (final item in items) {
        final iName = (item['name'] as String? ?? '').toString();
        final iType = item['type'] as String? ?? 'product';
        final iPrice = (item['price'] as num?)?.toDouble() ?? 0.0;
        final iQty = (item['quantity'] as num?)?.toDouble() ?? 0.0;
        final lineAmount = iPrice * iQty;
        if (lineAmount <= 0) continue;
        final account = _incomeAccountFor(iName, iType);
        incomeByAccount[account] = (incomeByAccount[account] ?? 0.0) + lineAmount;
      }
      final itemsGross = incomeByAccount.values.fold(0.0, (a, b) => a + b);
      final scale = itemsGross > 0 ? subtotal / itemsGross : 1.0;
      double allocated = 0.0;
      final accounts = incomeByAccount.keys.toList();
      for (int i = 0; i < accounts.length; i++) {
        final account = accounts[i];
        final raw = incomeByAccount[account]! * scale;
        final isLast = i == accounts.length - 1;
        final credit = isLast
            ? double.parse((subtotal - allocated).toStringAsFixed(2))
            : double.parse(raw.toStringAsFixed(2));
        allocated += credit;
        if (credit > 0) {
          entryLines.add({'accountCode': account, 'debit': 0.0, 'credit': credit});
        }
      }

      // ─── Guardar transacción y asiento ───
      final transaction = TransactionModel(
        id: transactionId,
        type: TransactionType.ingreso,
        category: 'Venta',
        amount: subtotal,
        vatAmount: vatAmount,
        vatRate: vatAmount > 0 ? taxRate : 0,
        total: total,
        date: DateTime.now(),
        description: 'Pedido #${orderId.length > 8 ? orderId.substring(0, 8) : orderId} procesado',
        clientIdentification: clientIdentification.isNotEmpty ? clientIdentification : null,
        referenceId: orderId,
      );

      await _accountingService.saveTransaction(transaction);
      debugPrint('✅ Ingreso contable registrado para pedido $orderId (ID: $transactionId)');

      await JournalEntryService().createEntryFromEvent(
        referenceType: 'order_income',
        referenceId: orderId,
        date: DateTime.now(),
        description: 'Venta pedido #${orderId.length > 8 ? orderId.substring(0, 8) : orderId}',
        createdBy: data['userId'],
        lines: entryLines,
      );

      // ─── Crear CxC por el monto a crédito (abonos crédito + saldo pendiente) ───
      final creditoPaid = amountsByMethod['credito'] ?? 0.0;
      final cxcAmount = creditoPaid + balance;
      if (cxcAmount > 0.01) {
        final clientName = data['shippingAddress']?['fullName'] ?? data['clientName'] ?? 'Cliente';
        await ReceivableService().autoCreateFromOrder(orderId, clientName,
            clientIdentification.isNotEmpty ? clientIdentification : null, cxcAmount, DateTime.now());
      }
    } catch (e) {
      debugPrint('⚠️ Error al registrar ingreso contable del pedido $orderId: $e');
    }
  }

  /// Registra un abono (pago parcial) de un cliente en un pedido.
  ///
  /// - Guarda el abono en la subcolección `orders/{id}/payments`.
  /// - Actualiza los campos `totalPaid` y `balance` en el documento de la orden.
  /// - Actualiza la CxC existente si el pedido ya fue completado (reduce saldo).
  /// - NO crea transacción de ingreso (el ingreso se reconoce al completar la orden).
  Future<String> registerPayment({
    required String orderId,
    required double amount,
    required String method,
    String? institution,
    String? voucher,
    String? note,
  }) async {
    try {
      final orderRef = _db.collection(_collection).doc(orderId);
      final orderDoc = await orderRef.get();
      if (!orderDoc.exists) throw Exception('Pedido no encontrado');

      final data = orderDoc.data() as Map<String, dynamic>;
      final originalQuote = data['originalQuote'] as Map<String, dynamic>?;

      // Total del pedido
      double orderTotal = 0.0;
      if (data['total'] != null) {
        orderTotal = (data['total'] as num).toDouble();
      } else if (originalQuote?['total'] != null) {
        orderTotal = (originalQuote!['total'] as num).toDouble();
      }

      // Calcular nuevo total pagado
      final prevTotalPaid = (data['totalPaid'] as num?)?.toDouble() ?? 0.0;
      final newTotalPaid = prevTotalPaid + amount;
      final newBalance = (orderTotal - newTotalPaid).clamp(0.0, double.infinity);

      // 1. Guardar abono en subcolección
      final paymentRef = orderRef.collection('payments').doc(
        await DocumentIdService().generateId(prefix: 'pago', useDate: true),
      );
      await paymentRef.set({
        'amount': amount,
        'method': method,
        'institution': institution ?? '',
        'voucher': voucher ?? '',
        'note': note ?? '',
        'date': Timestamp.now(),
        'orderId': orderId,
      });

      // 2. Actualizar totalPaid, balance, paymentStatus y paidAmount en la orden
      final newPaymentStatus = newTotalPaid >= orderTotal ? 'paid' : 'partial';
      await orderRef.update({
        'totalPaid': newTotalPaid,
        'paidAmount': newTotalPaid,
        'balance': newBalance,
        'paymentStatus': newPaymentStatus,
      });

      // 3. Si ya existe una CxC para este pedido, reducir el saldo pendiente
      final existingCxC = await _db
          .collection('accounts_receivable')
          .where('originId', isEqualTo: orderId)
          .where('originType', isEqualTo: 'order')
          .limit(1)
          .get();
      if (existingCxC.docs.isNotEmpty) {
        final cxcRef = existingCxC.docs.first.reference;
        final cxcData = existingCxC.docs.first.data();
        final currentPaid = (cxcData['paidAmount'] as num?)?.toDouble() ?? 0.0;
        final totalAmount = (cxcData['totalAmount'] as num?)?.toDouble() ?? 0.0;
        final newCxcPaid = currentPaid + amount;
        final newStatus = newCxcPaid >= totalAmount ? 'pagada' : 'parcial';
        await cxcRef.update({
          'paidAmount': newCxcPaid,
          'balance': (totalAmount - newCxcPaid).clamp(0.0, double.infinity),
          'status': newStatus,
          'lastPaymentDate': Timestamp.fromDate(DateTime.now()),
        });
      }

      debugPrint(
        '✅ Abono registrado: \$$amount para pedido $orderId. '
        'TotalPaid: $newTotalPaid, Balance: $newBalance',
      );

      return paymentRef.id;
    } catch (e) {
      debugPrint('⚠️ Error al registrar abono: $e');
      // Reintentar si es un error de permisos de Firestore tras una breve espera
      if (e.toString().contains('PERMISSION_DENIED')) {
        debugPrint('⏳ Error de permisos detectado, reintentando en 2 segundos...');
        await Future.delayed(const Duration(seconds: 2));
        try {
          final orderRef2 = _db.collection(_collection).doc(orderId);
          final paymentRef2 = orderRef2.collection('payments').doc(
            await DocumentIdService().generateId(prefix: 'pago', useDate: true),
          );
          final orderDoc2 = await orderRef2.get();
          final data2 = orderDoc2.data() as Map<String, dynamic>;
          final prevPaid2 = (data2['totalPaid'] as num?)?.toDouble() ?? 0.0;
          final newPaid2 = prevPaid2 + amount;
          final orderTotal2 = (data2['total'] as num?)?.toDouble() ?? 0.0;
          final newBalance2 = (orderTotal2 - newPaid2).clamp(0.0, double.infinity);
          final newStatus2 = newPaid2 >= orderTotal2 ? 'paid' : 'partial';
          await paymentRef2.set({
            'amount': amount,
            'method': method,
            'institution': institution ?? '',
            'voucher': voucher ?? '',
            'note': note ?? '',
            'date': Timestamp.now(),
            'orderId': orderId,
          });
          await orderRef2.update({
            'totalPaid': newPaid2,
            'paidAmount': newPaid2,
            'balance': newBalance2,
            'paymentStatus': newStatus2,
          });
          debugPrint('✅ Abono registrado en el reintento: \$$amount para pedido $orderId');
          return paymentRef2.id;
        } catch (retryError) {
          debugPrint('⚠️ Error también en el reintento: $retryError');
          rethrow;
        }
      }
      rethrow;
    }
  }

  /// Stream de abonos registrados para un pedido específico.
  Stream<QuerySnapshot> getPaymentsStream(String orderId) {
    return _db
        .collection(_collection)
        .doc(orderId)
        .collection('payments')
        .orderBy('date', descending: false)
        .snapshots();
  }

  /// Elimina un pedido.
  Future<void> deleteOrder(String orderId) async {
    await _db.collection(_collection).doc(orderId).delete();
  }
}

