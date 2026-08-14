class ConfigModel {
  final String companyName;
  final String companyEmail;
  final String companyPhone;
  final String companyAddress;

  final String payphoneToken;
  final String payphoneStoreId;
  final bool payphoneIsSandbox;
  final double vatPercentage;

  /// Porcentaje de comisión que Payphone cobra por cada transacción
  /// (ej. 5.0 = 5% sobre el total de la venta).
  final double payphoneCommissionPercentage;

  ConfigModel({
    this.companyName = 'TechService Pro',
    this.companyEmail = 'techservicecomputer@hotmail.com',
    this.companyPhone = '0991090805',
    this.companyAddress = 'De los Guabos n47-313, Quito',
    this.payphoneToken = '',
    this.payphoneStoreId = '',
    this.payphoneIsSandbox = true,
    this.vatPercentage = 15.0,
    this.payphoneCommissionPercentage = 5.0,
  });

  Map<String, dynamic> toMap() {
    return {
      'companyName': companyName,
      'companyEmail': companyEmail,
      'companyPhone': companyPhone,
      'companyAddress': companyAddress,
      'payphoneToken': payphoneToken,
      'payphoneStoreId': payphoneStoreId,
      'payphoneIsSandbox': payphoneIsSandbox,
      'vatPercentage': vatPercentage,
      'payphoneCommissionPercentage': payphoneCommissionPercentage,
    };
  }

  Map<String, dynamic> toFirestore() => toMap();

  factory ConfigModel.fromMap(Map<String, dynamic> map) {
    return ConfigModel(
      companyName: map['companyName'] ?? 'TechService Pro',
      companyEmail: map['companyEmail'] ?? 'techservicecomputer@hotmail.com',
      companyPhone: map['companyPhone'] ?? '0991090805',
      companyAddress: map['companyAddress'] ?? 'De los Guabos n47-313, Quito',
      payphoneToken: map['payphoneToken'] ?? '',
      payphoneStoreId: map['payphoneStoreId'] ?? '',
      payphoneIsSandbox: map['payphoneIsSandbox'] ?? true,
      vatPercentage: (map['vatPercentage'] as num?)?.toDouble() ?? 15.0,
      payphoneCommissionPercentage:
          (map['payphoneCommissionPercentage'] as num?)?.toDouble() ?? 5.0,
    );
  }
}
