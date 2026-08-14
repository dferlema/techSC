import 'package:cloud_firestore/cloud_firestore.dart';

/// Estado de una factura de compra (independiente del estado de la CxP).
enum PurchaseInvoiceStatus { pendiente, pagada, anulada }

/// Tipo de factura de compra.
enum PurchaseInvoiceType { gasto, inventario }

extension PurchaseInvoiceTypeExtension on PurchaseInvoiceType {
  String get value => name;
  static PurchaseInvoiceType fromString(String? value) {
    return PurchaseInvoiceType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PurchaseInvoiceType.gasto,
    );
  }
}

/// Ítem de línea de una factura de compra de inventario.
class PurchaseInvoiceItem {
  final String productId;
  final String productName;
  final int quantity;
  final double unitCost;
  final double totalCost;
  final String inventoryAccountCode;

  PurchaseInvoiceItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitCost,
    required this.totalCost,
    this.inventoryAccountCode = '1.1.03.02',
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'unitCost': unitCost,
      'totalCost': totalCost,
      'inventoryAccountCode': inventoryAccountCode,
    };
  }

  factory PurchaseInvoiceItem.fromMap(Map<String, dynamic> map) {
    return PurchaseInvoiceItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      unitCost: (map['unitCost'] as num?)?.toDouble() ?? 0.0,
      totalCost: (map['totalCost'] as num?)?.toDouble() ?? 0.0,
      inventoryAccountCode: map['inventoryAccountCode'] ?? '1.1.03.02',
    );
  }
}

/// Factura de compra y gastos de la empresa.
///
/// Es la fuente de verdad de cada compra/gasto. A partir de ella se generan
/// de forma idempotente: transacción contable (`factura_<id>`), asiento
/// (`auto_purchase_invoice_<id>`) y CxP (si queda pendiente de pago).
class PurchaseInvoiceModel {
  final String id;
  final String supplierName;
  final String? supplierIdentification;
  final String? supplierPhone;
  final String documentType;
  final String documentNumber;
  final DateTime issueDate;
  final DateTime? dueDate;
  final double subtotal;
  final double vatAmount;
  final double vatRate;
  final double total;
  final String paymentType; // 'contado', 'credito', 'transferencia'
  final String category;
  final String accountCode; // Cuenta que se debita (gasto o inventario)
  final PurchaseInvoiceType type;
  final PurchaseInvoiceStatus status;
  final List<PurchaseInvoiceItem> items;
  final String? payableId;
  final String? originType; // 'inventory' si viene de un movimiento
  final String? originId; // movementId si viene de inventario
  final String? notes;
  final DateTime createdAt;

  PurchaseInvoiceModel({
    required this.id,
    required this.supplierName,
    this.supplierIdentification,
    this.supplierPhone,
    this.documentType = 'Factura',
    this.documentNumber = '',
    required this.issueDate,
    this.dueDate,
    required this.subtotal,
    required this.vatAmount,
    this.vatRate = 0.15,
    required this.total,
    this.paymentType = 'contado',
    required this.category,
    required this.accountCode,
    this.type = PurchaseInvoiceType.gasto,
    this.status = PurchaseInvoiceStatus.pendiente,
    this.items = const [],
    this.payableId,
    this.originType,
    this.originId,
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'supplierName': supplierName,
      'supplierIdentification': supplierIdentification,
      'supplierPhone': supplierPhone,
      'documentType': documentType,
      'documentNumber': documentNumber,
      'issueDate': Timestamp.fromDate(issueDate),
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
      'subtotal': subtotal,
      'vatAmount': vatAmount,
      'vatRate': vatRate,
      'total': total,
      'paymentType': paymentType,
      'category': category,
      'accountCode': accountCode,
      'type': type.value,
      'status': status.name,
      'items': items.map((i) => i.toMap()).toList(),
      'payableId': payableId,
      'originType': originType,
      'originId': originId,
      'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  PurchaseInvoiceModel copyWith({
    String? payableId,
    PurchaseInvoiceStatus? status,
  }) {
    return PurchaseInvoiceModel(
      id: id,
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
      type: type,
      status: status ?? this.status,
      items: items,
      payableId: payableId ?? this.payableId,
      originType: originType,
      originId: originId,
      notes: notes,
      createdAt: createdAt,
    );
  }

  factory PurchaseInvoiceModel.fromMap(Map<String, dynamic> map, String docId) {
    return PurchaseInvoiceModel(
      id: docId,
      supplierName: map['supplierName'] ?? '',
      supplierIdentification: map['supplierIdentification'],
      supplierPhone: map['supplierPhone'],
      documentType: map['documentType'] ?? 'Factura',
      documentNumber: map['documentNumber'] ?? '',
      issueDate: (map['issueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dueDate: (map['dueDate'] as Timestamp?)?.toDate(),
      subtotal: (map['subtotal'] as num?)?.toDouble() ?? 0.0,
      vatAmount: (map['vatAmount'] as num?)?.toDouble() ?? 0.0,
      vatRate: (map['vatRate'] as num?)?.toDouble() ?? 0.15,
      total: (map['total'] as num?)?.toDouble() ?? 0.0,
      paymentType: map['paymentType'] ?? 'contado',
      category: map['category'] ?? '',
      accountCode: map['accountCode'] ?? '',
      type: PurchaseInvoiceTypeExtension.fromString(map['type']),
      status: PurchaseInvoiceStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => PurchaseInvoiceStatus.pendiente,
      ),
      items: (map['items'] as List? ?? [])
          .map((i) => PurchaseInvoiceItem.fromMap(i as Map<String, dynamic>))
          .toList(),
      payableId: map['payableId'],
      originType: map['originType'],
      originId: map['originId'],
      notes: map['notes'],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  factory PurchaseInvoiceModel.fromSnapshot(DocumentSnapshot doc) {
    return PurchaseInvoiceModel.fromMap(
      doc.data() as Map<String, dynamic>,
      doc.id,
    );
  }
}
