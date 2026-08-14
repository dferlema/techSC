import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:tscomputer/core/services/document_id_service.dart';
import 'package:tscomputer/features/accounting/models/purchase_invoice_model.dart';
import 'package:tscomputer/features/accounting/models/payable_model.dart';
import 'package:tscomputer/features/accounting/models/transaction_model.dart';
import 'package:tscomputer/features/accounting/services/accounting_service.dart';
import 'package:tscomputer/features/accounting/services/account_mapper.dart';
import 'package:tscomputer/features/accounting/services/journal_entry_service.dart';
import 'package:tscomputer/features/accounting/services/payable_service.dart';

/// Servicio de Facturas de Compra y Gastos.
///
/// Cada factura (`purchase_invoices`) es la fuente de verdad de una compra o
/// gasto. Al registrarla se generan, de forma IDEMPOTENTE:
///   - transacción contable con ID determinista `factura_<invoiceId>`,
///   - asiento automático `auto_purchase_invoice_<invoiceId>`,
///   - CxP si la factura queda pendiente de pago (idempotente por `originId`).
///
/// La idempotencia evita asientos o valores duplicados aunque se registre dos
/// veces la misma factura o se sincronice el historial.
class PurchaseInvoiceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AccountingService _accountingService = AccountingService();
  final JournalEntryService _journalEntryService = JournalEntryService();
  final PayableService _payableService = PayableService();
  static const String _collection = 'purchase_invoices';

  Stream<List<PurchaseInvoiceModel>> getInvoicesStream() {
    return _firestore
        .collection(_collection)
        .orderBy('issueDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PurchaseInvoiceModel.fromSnapshot(doc))
            .toList());
  }

  Future<List<PurchaseInvoiceModel>> getInvoices() async {
    final snapshot =
        await _firestore.collection(_collection).orderBy('issueDate', descending: true).get();
    return snapshot.docs.map((doc) => PurchaseInvoiceModel.fromSnapshot(doc)).toList();
  }

  /// Registra una factura de gasto (sin inventario) de forma idempotente.
  ///
  /// - [subtotal] es la base sin IVA.
  /// - El IVA de compras NO es acreditable (RIMPE): se capitaliza y el egreso
  ///   real es el [total].
  /// - [accountCode] es la cuenta de gasto que se debita.
  Future<String?> registerExpenseInvoice({
    required String supplierName,
    String? supplierIdentification,
    String? supplierPhone,
    String documentType = 'Factura',
    required String documentNumber,
    required DateTime issueDate,
    DateTime? dueDate,
    required double subtotal,
    required double vatRate,
    required String paymentType, // 'contado', 'credito', 'transferencia'
    required String category,
    required String accountCode,
    String? notes,
  }) async {
    if (subtotal <= 0) return null;
    final vatAmount = subtotal * vatRate;
    final total = subtotal + vatAmount;

    // Idempotencia: si ya se registró una factura manual con el mismo número,
    // proveedor y día, retornar la existente sin duplicar nada.
    final existing = await _findExistingManualInvoice(
      documentNumber: documentNumber,
      supplierName: supplierName,
      issueDate: issueDate,
      type: PurchaseInvoiceType.gasto,
    );
    if (existing != null) {
      debugPrint('⏭️ Factura de gasto $existing ya existe, omitiendo');
      return existing;
    }

    final invoiceId =
        await DocumentIdService().generateId(prefix: 'fac', useDate: true);
    final invoice = PurchaseInvoiceModel(
      id: invoiceId,
      supplierName: supplierName,
      supplierIdentification: supplierIdentification,
      supplierPhone: supplierPhone,
      documentType: documentType,
      documentNumber: documentNumber,
      issueDate: issueDate,
      dueDate: dueDate,
      subtotal: subtotal,
      vatAmount: vatAmount,
      vatRate: vatRate,
      total: total,
      paymentType: paymentType,
      category: category,
      accountCode: accountCode,
      type: PurchaseInvoiceType.gasto,
      status: paymentType == 'contado' || paymentType == 'transferencia'
          ? PurchaseInvoiceStatus.pagada
          : PurchaseInvoiceStatus.pendiente,
      notes: notes,
      createdAt: DateTime.now(),
    );
    return _persistInvoice(invoice);
  }

  /// Registra una factura de compra de inventario (con ítems) de forma idempotente.
  ///
  /// - [inventoryAccountCode] es la cuenta de inventario que se debita (1.1.03.xx).
  /// - El IVA de compras se capitaliza: el inventario se debita por el [total].
  Future<String?> registerInventoryInvoice({
    required String supplierName,
    String? supplierIdentification,
    String? supplierPhone,
    String documentType = 'Factura',
    required String documentNumber,
    required DateTime issueDate,
    DateTime? dueDate,
    required double subtotal,
    required double vatRate,
    required double total,
    required String paymentType, // 'contado', 'credito', 'transferencia'
    required String inventoryAccountCode,
    List<PurchaseInvoiceItem> items = const [],
    String? notes,
  }) async {
    if (total <= 0) return null;
    final vatAmount = total - subtotal;

    // Idempotencia: si ya se registró una factura manual con el mismo número,
    // proveedor y día, retornar la existente sin duplicar nada.
    final existing = await _findExistingManualInvoice(
      documentNumber: documentNumber,
      supplierName: supplierName,
      issueDate: issueDate,
      type: PurchaseInvoiceType.inventario,
    );
    if (existing != null) {
      debugPrint('⏭️ Factura de inventario $existing ya existe, omitiendo');
      return existing;
    }

    final invoiceId =
        await DocumentIdService().generateId(prefix: 'fac', useDate: true);
    final invoice = PurchaseInvoiceModel(
      id: invoiceId,
      supplierName: supplierName,
      supplierIdentification: supplierIdentification,
      supplierPhone: supplierPhone,
      documentType: documentType,
      documentNumber: documentNumber,
      issueDate: issueDate,
      dueDate: dueDate,
      subtotal: subtotal,
      vatAmount: vatAmount,
      vatRate: vatRate,
      total: total,
      paymentType: paymentType,
      category: 'Compra de Inventario',
      accountCode: inventoryAccountCode,
      type: PurchaseInvoiceType.inventario,
      status: paymentType == 'contado' || paymentType == 'transferencia'
          ? PurchaseInvoiceStatus.pagada
          : PurchaseInvoiceStatus.pendiente,
      items: items,
      notes: notes,
      createdAt: DateTime.now(),
    );
    return _persistInvoice(invoice);
  }

  /// Registra la factura que respalda un movimiento de inventario IN ya creado.
  ///
  /// Usado por [InventoryService] para unificar las compras de inventario por
  /// factura: el movimiento crea la factura como fuente de verdad y aquí se
  /// generan transacción + asiento + CxP. Si la factura ya existe (mismo
  /// `originId`), retorna su ID sin duplicar nada.
  Future<String?> registerInvoiceFromMovement({
    required String movementId,
    required String supplierName,
    String? supplierId,
    String? supplierPhone,
    String? supplierNameRaw,
    String? documentType,
    String? documentNumber,
    required DateTime date,
    DateTime? dueDate,
    required double subtotal,
    required double vatAmount,
    required double vatRate,
    required double total,
    required String paymentType,
    required String inventoryAccountCode,
    List<PurchaseInvoiceItem> items = const [],
  }) async {
    if (total <= 0) return null;

    // Idempotencia: si ya existe una factura ligada a este movimiento, retornarla.
    final existing = await _firestore
        .collection(_collection)
        .where('originType', isEqualTo: 'inventory')
        .where('originId', isEqualTo: movementId)
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) {
      debugPrint('⏭️ Factura ya existe para movimiento $movementId, omitiendo');
      return existing.docs.first.id;
    }

    final invoiceId = 'inv_$movementId';
    final invoice = PurchaseInvoiceModel(
      id: invoiceId,
      supplierName: supplierName.isNotEmpty ? supplierName : (supplierNameRaw ?? 'Proveedor'),
      supplierIdentification: supplierId,
      supplierPhone: supplierPhone,
      documentType: documentType ?? 'Factura',
      documentNumber: documentNumber ?? '',
      issueDate: date,
      dueDate: dueDate ?? date.add(const Duration(days: 30)),
      subtotal: subtotal,
      vatAmount: vatAmount,
      vatRate: vatRate,
      total: total,
      paymentType: paymentType,
      category: 'Compra de Inventario',
      accountCode: inventoryAccountCode,
      type: PurchaseInvoiceType.inventario,
      status: paymentType == 'contado' || paymentType == 'transferencia'
          ? PurchaseInvoiceStatus.pagada
          : PurchaseInvoiceStatus.pendiente,
      items: items,
      originType: 'inventory',
      originId: movementId,
      createdAt: DateTime.now(),
    );
    return _persistInvoice(invoice);
  }

  /// Registra la factura de comisión que Payphone emite por cada venta con tarjeta.
  ///
  /// Idempotente por ID determinista `payphone_<orderId>`. En régimen RIMPE el
  /// IVA de la comisión NO es acreditable y se capitaliza al gasto: la cuenta
  /// `5.4.04 Comisiones por Tarjetas` se debita por el TOTAL (base + IVA) y
  /// Bancos (1.1.01.03) se acredita por el mismo monto, reflejando que Payphone
  /// solo deposita el neto (total − comisión − IVA de la comisión).
  Future<String?> registerPayphoneCommissionInvoice({
    required String orderId,
    required DateTime date,
    required double commissionBase,
    required double vatRate,
    String? notes,
  }) async {
    if (commissionBase <= 0) return null;
    final vatAmount = commissionBase * vatRate;
    final total = commissionBase + vatAmount;

    final invoiceId = 'payphone_$orderId';
    final existing = await _firestore.collection(_collection).doc(invoiceId).get();
    if (existing.exists) {
      debugPrint('⏭️ Comisión Payphone ya registrada para pedido $orderId');
      return invoiceId;
    }

    final invoice = PurchaseInvoiceModel(
      id: invoiceId,
      supplierName: 'Payphone',
      documentType: 'Factura',
      documentNumber: 'COM-$orderId',
      issueDate: date,
      subtotal: commissionBase,
      vatAmount: vatAmount,
      vatRate: vatRate,
      total: total,
      paymentType: 'transferencia', // Payphone deposita el neto a Bancos
      category: 'Comisiones',
      accountCode: '5.4.04', // Comisiones por Tarjetas
      type: PurchaseInvoiceType.gasto,
      status: PurchaseInvoiceStatus.pagada,
      notes: notes,
      createdAt: DateTime.now(),
    );
    return _persistInvoice(invoice);
  }

  /// Persiste la factura y sus artefactos contables de forma idempotente.
  Future<String?> _persistInvoice(PurchaseInvoiceModel invoice) async {
    try {
      // 1. Transacción contable con ID determinista (sobreescribe, no duplica).
      final transaction = TransactionModel(
        id: 'factura_${invoice.id}',
        type: TransactionType.egreso,
        category: invoice.category,
        amount: invoice.subtotal,
        vatAmount: invoice.vatAmount,
        vatRate: invoice.vatRate,
        total: invoice.total,
        date: invoice.issueDate,
        description:
            '${invoice.documentType}: ${invoice.documentNumber} - ${invoice.supplierName}',
        clientIdentification: invoice.supplierIdentification,
        referenceId: invoice.id,
        paymentMethodType:
            invoice.paymentType == 'contado' ? 'efectivo' : invoice.paymentType,
      );
      await _accountingService.saveTransaction(transaction);

      // 2. Asiento contable idempotente (createEntryFromEvent omite si existe).
      final cashAccount = switch (invoice.paymentType) {
        'contado' => '1.1.01.01', // Caja General
        'transferencia' => '1.1.01.03', // Bancos
        _ => AccountMapper.supplierAccountFor(invoice.accountCode), // Crédito → CxP
      };
      await _journalEntryService.createEntryFromEvent(
        referenceType: 'purchase_invoice',
        referenceId: invoice.id,
        date: invoice.issueDate,
        description: 'Compra/Gasto - ${invoice.supplierName} (${invoice.documentNumber})',
        lines: [
          {'accountCode': invoice.accountCode, 'debit': invoice.total, 'credit': 0.0},
          {'accountCode': cashAccount, 'debit': 0.0, 'credit': invoice.total},
        ],
      );

      // 3. CxP si la factura queda pendiente de pago.
      String? payableId;
      if (invoice.paymentType == 'credito' &&
          invoice.status != PurchaseInvoiceStatus.pagada) {
        final existingPayable = await _firestore
            .collection('accounts_payable')
            .where('originType', isEqualTo: 'invoice')
            .where('originId', isEqualTo: invoice.id)
            .limit(1)
            .get();
        if (existingPayable.docs.isEmpty) {
          payableId = await _payableService.createPayable(
            PayableModel(
              id: '',
              supplierName: invoice.supplierName,
              supplierIdentification: invoice.supplierIdentification,
              supplierPhone: invoice.supplierPhone,
              originType: 'invoice',
              originId: invoice.id,
              totalAmount: invoice.total,
              issueDate: invoice.issueDate,
              dueDate: invoice.dueDate,
              notes: '${invoice.documentType} ${invoice.documentNumber}',
            ),
          );
          await _firestore
              .collection('accounts_payable')
              .doc(payableId)
              .update({'accountCode': AccountMapper.supplierAccountFor(invoice.accountCode)});
        }
      }

      // 4. Guardar el documento de la factura (con payableId ya asignado).
      final invoiceToSave = payableId != null
          ? invoice.copyWith(payableId: payableId)
          : invoice;
      await _firestore
          .collection(_collection)
          .doc(invoice.id)
          .set(invoiceToSave.toMap());
      debugPrint('✅ Factura ${invoice.id} registrada (Total: \$${invoice.total})');
      return invoice.id;
    } catch (e) {
      debugPrint('⚠️ Error al registrar factura: $e');
      return null;
    }
  }

  /// Actualiza una factura existente (uso exclusivo administrador/contabilidad).
  ///
  /// Revierte y recrea el asiento automático con los nuevos valores; la
  /// transacción contable `factura_<id>` se sobreescribe vía `saveTransaction`.
  /// Conserva `id`, `originType`/`originId` y el `payableId` de la factura.
  Future<String?> updateInvoice(PurchaseInvoiceModel invoice) async {
    try {
      // Revertir saldos + eliminar asiento anterior para recrearlo idempotente.
      await _journalEntryService.removeEntryFromEvent('purchase_invoice', invoice.id);
      return _persistInvoice(invoice);
    } catch (e) {
      debugPrint('⚠️ Error al actualizar factura ${invoice.id}: $e');
      return null;
    }
  }

  Future<void> deleteInvoice(String id) async {
    await _firestore.collection(_collection).doc(id).delete();
  }

  /// Actualiza el estado de pago de una factura.
  Future<void> updateStatus(String id, PurchaseInvoiceStatus status) async {
    await _firestore.collection(_collection).doc(id).update({'status': status.name});
  }

  /// Busca una factura manual existente (mismo número de documento, proveedor
  /// y día) para evitar duplicados por doble envío del formulario.
  Future<String?> _findExistingManualInvoice({
    required String documentNumber,
    required String supplierName,
    required DateTime issueDate,
    required PurchaseInvoiceType type,
  }) async {
    if (documentNumber.isEmpty) return null;
    final snapshot = await _firestore
        .collection(_collection)
        .where('documentNumber', isEqualTo: documentNumber)
        .limit(10)
        .get();
    for (final doc in snapshot.docs) {
      final existing = PurchaseInvoiceModel.fromSnapshot(doc);
      final sameDay = existing.issueDate.year == issueDate.year &&
          existing.issueDate.month == issueDate.month &&
          existing.issueDate.day == issueDate.day;
      final sameSupplier = existing.supplierName.trim().toLowerCase() ==
          supplierName.trim().toLowerCase();
      if (existing.type == type && sameDay && sameSupplier) return existing.id;
    }
    return null;
  }

  /// Verifica si ya existe una transacción contable ligada a una factura.
  Future<bool> transactionExists(String invoiceId) async {
    final doc =
        await _firestore.collection('accounting_transactions').doc('factura_$invoiceId').get();
    return doc.exists;
  }
}
