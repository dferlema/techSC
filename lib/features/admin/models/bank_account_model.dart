class BankAccount {
  final String id;
  final String bankName;
  final String accountType; // Ahorros, Corriente
  final String accountNumber;
  final String holderName;
  final String holderId;
  final String holderEmail;

  BankAccount({
    required this.id,
    required this.bankName,
    required this.accountType,
    required this.accountNumber,
    required this.holderName,
    required this.holderId,
    required this.holderEmail,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bankName': bankName,
      'accountType': accountType,
      'accountNumber': accountNumber,
      'holderName': holderName,
      'holderId': holderId,
      'holderEmail': holderEmail,
    };
  }

  factory BankAccount.fromMap(Map<String, dynamic> map) {
    return BankAccount(
      id: map['id'] ?? '',
      bankName: map['bankName'] ?? '',
      accountType: map['accountType'] ?? 'Ahorros',
      accountNumber: map['accountNumber'] ?? '',
      holderName: map['holderName'] ?? '',
      holderId: map['holderId'] ?? '',
      holderEmail: map['holderEmail'] ?? '',
    );
  }

  String toWhatsAppString() {
    return '''*DATOS DE PAGO*
🏦 *Banco:* $bankName
📄 *Tipo:* $accountType
🔢 *Número:* $accountNumber
👤 *Titular:* $holderName
🆔 *CI/RUC:* $holderId
📧 *Correo:* $holderEmail''';
  }
}
