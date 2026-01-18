class ConfigModel {
  final String companyName;
  final String companyEmail;
  final String companyPhone;
  final String companyAddress;

  ConfigModel({
    this.companyName = 'TechService Pro',
    this.companyEmail = 'techservicecomputer@hotmail.com',
    this.companyPhone = '0991090805',
    this.companyAddress = 'De los Guabos n47-313, Quito',
  });

  Map<String, dynamic> toMap() {
    return {
      'companyName': companyName,
      'companyEmail': companyEmail,
      'companyPhone': companyPhone,
      'companyAddress': companyAddress,
    };
  }

  factory ConfigModel.fromMap(Map<String, dynamic> map) {
    return ConfigModel(
      companyName: map['companyName'] ?? 'TechService Pro',
      companyEmail: map['companyEmail'] ?? 'techservicecomputer@hotmail.com',
      companyPhone: map['companyPhone'] ?? '0991090805',
      companyAddress: map['companyAddress'] ?? 'De los Guabos n47-313, Quito',
    );
  }
}
