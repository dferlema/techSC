import 'dart:convert';
import 'package:http/http.dart' as http;

class PayphoneService {
  final String authToken;
  final String storeId;
  final bool isSandbox;

  PayphoneService({
    required this.authToken,
    required this.storeId,
    this.isSandbox = true,
  });

  String get _baseUrl => 'https://pay.payphonetodoesposible.com/api/Links';

  /// Crea una solicitud de pago (Link) y devuelve el URL generado
  Future<String?> createPaymentRequest({
    required double amount,
    required String clientTransactionId,
    String? reference,
    String? responseUrl,
    String? cancellationUrl,
    // Note: Guide does not list email/phone/documentId in the table,
    // but they might be supported. Following guide strictly.
  }) async {
    // Payphone maneja montos en centavos (int)
    final int totalAmount = (amount * 100).toInt();
    final int amountWithoutTax = totalAmount;
    final int tax = 0;

    final Map<String, dynamic> body = {
      "amount": totalAmount,
      "amountWithoutTax": amountWithoutTax,
      "amountWithTax": 0,
      "tax": tax,
      "service": 0,
      "tip": 0,
      "currency": "USD",
      "reference": reference ?? "Pago TechSC",
      "clientTransactionId": clientTransactionId,
      "storeId": storeId,
      if (responseUrl != null) "responseUrl": responseUrl,
      if (cancellationUrl != null) "cancellationUrl": cancellationUrl,
      "oneTime": true,
      "expireIn": 0,
      "isAmountEditable": false,
    };

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);

        // Si la respuesta es directamente un String (la URL)
        if (data is String) return data;

        // Si es una lista
        if (data is List) {
          if (data.isEmpty) return null;
          final first = data.first;
          if (first is String) return first;
          if (first is Map) {
            return (first['redirectUrl'] ??
                    first['url'] ??
                    first['payWithCard'])
                ?.toString();
          }
          return null;
        }

        // Si es un mapa
        if (data is Map) {
          return (data['redirectUrl'] ?? data['url'] ?? data['payWithCard'])
              ?.toString();
        }

        return data?.toString();
      } else {
        throw Exception(
          'Error Payphone (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      print('Payphone Error: $e');
      rethrow;
    }
  }

  /// Verifica el estado de una transacción
  Future<Map<String, dynamic>?> getTransactionStatus(int transactionId) async {
    final url = 'https://pay.payphone.app/api/v2/Sale/$transactionId';

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $authToken'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return null;
    } catch (e) {
      print('Payphone Status Error: $e');
      return null;
    }
  }
}
