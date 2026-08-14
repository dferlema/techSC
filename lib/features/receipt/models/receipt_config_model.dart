import 'package:cloud_firestore/cloud_firestore.dart';

class ReceiptItem {
  final String description;
  final int quantity;
  final double unitPrice;
  final double total;

  ReceiptItem({
    required this.description,
    this.quantity = 1,
    required this.unitPrice,
    double? total,
  }) : total = total ?? (unitPrice * quantity);
}

class WorkshopReceiptData {
  final String saleNumber;
  final DateTime date;

  // Datos del cliente
  final String clientName;
  final String clientId; // cédula / RUC / DNI
  final String clientPhone;
  final String clientEmail;
  final String clientAddress;

  // Datos del equipo
  final String deviceType; // laptop, celular, impresora...
  final String brand;
  final String model;
  final String serialNumber; // IMEI / Número de serie
  final String? pin;
  final String accessories; // cargador, funda, etc.
  final String reportedFault;
  final DateTime receptionDate;
  final DateTime? estimatedDeliveryDate;
  final DateTime? actualDeliveryDate;

  // Descripción del trabajo
  final String diagnosis;
  final List<ReceiptItem> services; // mano de obra
  final List<ReceiptItem> parts; // repuestos / materiales
  final String warrantyTerms;

  // Pagos
  final double subtotal;
  final double iva;
  final double discount;
  final double total;
  final String paymentMethod;
  final double advance;
  final double pendingBalance;

  // Firmas y notas
  final String? technicianName;
  final String? additionalNotes;

  WorkshopReceiptData({
    required this.saleNumber,
    required this.date,
    required this.clientName,
    this.clientId = '',
    this.clientPhone = '',
    this.clientEmail = '',
    this.clientAddress = '',
    this.deviceType = '',
    this.brand = '',
    this.model = '',
    this.serialNumber = '',
    this.pin,
    this.accessories = '',
    this.reportedFault = '',
    required this.receptionDate,
    this.estimatedDeliveryDate,
    this.actualDeliveryDate,
    this.diagnosis = '',
    this.services = const [],
    this.parts = const [],
    this.warrantyTerms = '30 días sobre mano de obra. No cubre daños por líquidos.',
    required this.subtotal,
    this.iva = 0,
    this.discount = 0,
    required this.total,
    this.paymentMethod = '',
    this.advance = 0,
    this.pendingBalance = 0,
    this.technicianName,
    this.additionalNotes,
  });
}

class ReceiptConfigModel {
  final String id;
  final String companyName;
  final String ruc;
  final String address;
  final String phone;
  final String email;
  final String? logoUrl;
  final String? receiptFooter;
  final String? businessType; // taller mecánico, técnico en computación, etc.
  final String? warrantyDefault;
  final A4Margins a4Margins;
  final ReceiptStyle style;

  ReceiptConfigModel({
    this.id = '',
    this.companyName = '',
    this.ruc = '',
    this.address = '',
    this.phone = '',
    this.email = '',
    this.logoUrl,
    this.receiptFooter = 'Gracias por su preferencia',
    this.businessType,
    this.warrantyDefault,
    this.a4Margins = const A4Margins(),
    this.style = const ReceiptStyle(),
  });

  Map<String, dynamic> toMap() {
    return {
      'companyName': companyName,
      'ruc': ruc,
      'address': address,
      'phone': phone,
      'email': email,
      'logoUrl': logoUrl,
      'receiptFooter': receiptFooter,
      'businessType': businessType,
      'warrantyDefault': warrantyDefault,
      'a4Margins': a4Margins.toMap(),
      'style': style.toMap(),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    };
  }

  factory ReceiptConfigModel.fromMap(Map<String, dynamic> map, String docId) {
    return ReceiptConfigModel(
      id: docId,
      companyName: map['companyName'] ?? '',
      ruc: map['ruc'] ?? '',
      address: map['address'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      logoUrl: map['logoUrl'],
      receiptFooter: map['receiptFooter'],
      businessType: map['businessType'],
      warrantyDefault: map['warrantyDefault'],
      a4Margins: A4Margins.fromMap(map['a4Margins'] ?? {}),
      style: ReceiptStyle.fromMap(map['style'] ?? {}),
    );
  }

  ReceiptConfigModel copyWith({
    String? companyName,
    String? ruc,
    String? address,
    String? phone,
    String? email,
    String? logoUrl,
    String? receiptFooter,
    String? businessType,
    String? warrantyDefault,
    A4Margins? a4Margins,
    ReceiptStyle? style,
  }) {
    return ReceiptConfigModel(
      id: id,
      companyName: companyName ?? this.companyName,
      ruc: ruc ?? this.ruc,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      logoUrl: logoUrl ?? this.logoUrl,
      receiptFooter: receiptFooter ?? this.receiptFooter,
      businessType: businessType ?? this.businessType,
      warrantyDefault: warrantyDefault ?? this.warrantyDefault,
      a4Margins: a4Margins ?? this.a4Margins,
      style: style ?? this.style,
    );
  }
}

class A4Margins {
  final double top;
  final double bottom;
  final double left;
  final double right;

  const A4Margins({
    this.top = 20,
    this.bottom = 20,
    this.left = 15,
    this.right = 15,
  });

  Map<String, dynamic> toMap() {
    return {'top': top, 'bottom': bottom, 'left': left, 'right': right};
  }

  factory A4Margins.fromMap(Map<String, dynamic> map) {
    return A4Margins(
      top: (map['top'] as num?)?.toDouble() ?? 20,
      bottom: (map['bottom'] as num?)?.toDouble() ?? 20,
      left: (map['left'] as num?)?.toDouble() ?? 15,
      right: (map['right'] as num?)?.toDouble() ?? 15,
    );
  }
}

class ReceiptStyle {
  final String primaryColor;
  final String fontFamily;
  final bool showLogo;
  final bool showRuc;
  final bool showAddress;
  final bool showPhone;
  final bool showEmail;

  const ReceiptStyle({
    this.primaryColor = '1565C0',
    this.fontFamily = 'Helvetica',
    this.showLogo = true,
    this.showRuc = true,
    this.showAddress = true,
    this.showPhone = true,
    this.showEmail = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'primaryColor': primaryColor,
      'fontFamily': fontFamily,
      'showLogo': showLogo,
      'showRuc': showRuc,
      'showAddress': showAddress,
      'showPhone': showPhone,
      'showEmail': showEmail,
    };
  }

  factory ReceiptStyle.fromMap(Map<String, dynamic> map) {
    return ReceiptStyle(
      primaryColor: map['primaryColor'] ?? '1565C0',
      fontFamily: map['fontFamily'] ?? 'Helvetica',
      showLogo: map['showLogo'] ?? true,
      showRuc: map['showRuc'] ?? true,
      showAddress: map['showAddress'] ?? true,
      showPhone: map['showPhone'] ?? true,
      showEmail: map['showEmail'] ?? true,
    );
  }
}
