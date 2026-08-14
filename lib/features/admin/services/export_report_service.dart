import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:tscomputer/core/platform/io_helper.dart';

/// Caché simple de nombres de usuario para evitar N+1 queries en reportes.
class _NameCache {
  static final _NameCache _instance = _NameCache._();
  factory _NameCache() => _instance;
  _NameCache._();
  Map<String, String>? _cache;
  DateTime _lastFetch = DateTime(2000);

  Future<Map<String, String>> getNames() async {
    if (_cache != null && DateTime.now().difference(_lastFetch).inMinutes < 5) {
      return _cache!;
    }
    final userDocs = await FirebaseFirestore.instance.collection('users').get();
    final map = <String, String>{};
    for (var doc in userDocs.docs) {
      final data = doc.data();
      map[doc.id] = data['name'] ?? data['userName'] ?? 'Desconocido';
    }
    _cache = map;
    _lastFetch = DateTime.now();
    return map;
  }

  void invalidate() { _cache = null; }
}

class ExportReportService {
  Future<void> generateSalesCSV(List<QueryDocumentSnapshot> docs) async {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln(
      'Pedido ID,Fecha,Vendedor,Cliente,Teléfono,Productos,Método Pago,Estado Pago,Total',
    );

    final sellerNames = await _NameCache().getNames();

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final originalQuote = data['originalQuote'] as Map<String, dynamic>?;
      final total = (data['total'] ?? 0.0).toDouble();

      final sellerId = originalQuote?['creatorId'] ?? data['userId'] ?? '';
      final sellerName = sellerNames[sellerId] ?? 'Desconocido';
      final clientName =
          originalQuote?['clientName'] ?? data['userName'] ?? 'Desconocido';
      final clientPhone = originalQuote?['clientPhone'] ?? '';
      final items = (originalQuote?['items'] as List<dynamic>? ?? []);
      final productsStr = items
          .map((item) => '${item['quantity']}x ${item['name']}')
          .join('; ');
      final paymentMethod = data['paymentMethod'] ?? 'N/A';
      final paymentStatus =
          data['paymentStatus'] ??
          (data['isPaid'] == true ? 'Pagado' : 'Pendiente');
      final date = DateFormat(
        'dd/MM/yyyy',
      ).format((data['createdAt'] as Timestamp).toDate());

      buffer.writeln(
        '"${doc.id.substring(0, 8).toUpperCase()}",'
        '"$date",'
        '"$sellerName",'
        '"$clientName",'
        '"$clientPhone",'
        '"$productsStr",'
        '"$paymentMethod",'
        '"$paymentStatus",'
        '$total',
      );
    }

    await shareBytes(
      Uint8List.fromList(utf8.encode(buffer.toString())),
      'reporte_ventas_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
    );
  }

  Future<void> generateSalesExcel(List<QueryDocumentSnapshot> docs) async {
    final excel = Excel.createExcel();
    final sheet = excel['Reporte de Ventas'];

    final sellerNames = await _NameCache().getNames();

    // Headers
    sheet.appendRow([
      TextCellValue('Pedido ID'),
      TextCellValue('Fecha'),
      TextCellValue('Vendedor'),
      TextCellValue('Cliente'),
      TextCellValue('Teléfono'),
      TextCellValue('Productos'),
      TextCellValue('Método Pago'),
      TextCellValue('Estado Pago'),
      TextCellValue('Total'),
    ]);

    // Data rows
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final originalQuote = data['originalQuote'] as Map<String, dynamic>?;
      final total = (data['total'] ?? 0.0).toDouble();

      final sellerId = originalQuote?['creatorId'] ?? data['userId'] ?? '';
      final sellerName = sellerNames[sellerId] ?? 'Desconocido';
      final clientName =
          originalQuote?['clientName'] ?? data['userName'] ?? 'Desconocido';
      final clientPhone = originalQuote?['clientPhone'] ?? '';
      final items = (originalQuote?['items'] as List<dynamic>? ?? []);
      final productsStr = items
          .map((item) => '${item['quantity']}x ${item['name']}')
          .join(', ');
      final paymentMethod = data['paymentMethod'] ?? 'N/A';
      final paymentStatus =
          data['paymentStatus'] ??
          (data['isPaid'] == true ? 'Pagado' : 'Pendiente');
      final date = DateFormat(
        'dd/MM/yyyy',
      ).format((data['createdAt'] as Timestamp).toDate());

      sheet.appendRow([
        TextCellValue(doc.id.substring(0, 8).toUpperCase()),
        TextCellValue(date),
        TextCellValue(sellerName),
        TextCellValue(clientName),
        TextCellValue(clientPhone),
        TextCellValue(productsStr),
        TextCellValue(paymentMethod),
        TextCellValue(paymentStatus),
        DoubleCellValue(total),
      ]);
    }

    final bytes = excel.save();
    if (bytes != null) {
      await shareBytes(
        Uint8List.fromList(bytes),
        'reporte_ventas_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx',
      );
    }
  }

  Future<void> generateServicesCSV(List<QueryDocumentSnapshot> docs) async {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln(
      'Reserva ID,Fecha,Técnico,Cliente,Dispositivo,Problema,Solución,Repuestos,Método Pago,Estado Pago,Costo',
    );

    final techNames = await _NameCache().getNames();

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final techId = data['technicianId'] ?? '';
      final techName = techNames[techId] ?? 'Sin Asignar';
      final cost = (data['repairCost'] as num?)?.toDouble() ?? 0.0;
      final date = DateFormat(
        'dd/MM/yyyy',
      ).format((data['scheduledDate'] as Timestamp).toDate());
      final payMethod = data['paymentMethod'] ?? 'N/A';
      final isPaid = data['isPaid'] == true ? 'Pagado' : 'Pendiente';

      // Escaping for CSV
      String escape(String? val) {
        if (val == null) return '';
        return val.replaceAll('"', '""'); // basic CSV escaping
      }

      buffer.writeln(
        '"${doc.id.substring(0, 8).toUpperCase()}",'
        '"$date",'
        '"${escape(techName)}",'
        '"${escape(data['clientName'])}",'
        '"${escape(data['device'])}",'
        '"${escape(data['description'])}",'
        '"${escape(data['solution'])}",'
        '"${escape(data['spareParts'])}",'
        '"${escape(payMethod)}",'
        '"$isPaid",'
        '$cost',
      );
    }

    await shareBytes(
      Uint8List.fromList(utf8.encode(buffer.toString())),
      'reporte_servicios_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
    );
  }

  Future<void> generateServicesExcel(List<QueryDocumentSnapshot> docs) async {
    final excel = Excel.createExcel();
    final sheet = excel['Reporte de Servicios'];

    final techNames = await _NameCache().getNames();

    // Headers
    sheet.appendRow([
      TextCellValue('ID Reserva'),
      TextCellValue('Fecha'),
      TextCellValue('Técnico'),
      TextCellValue('Cliente'),
      TextCellValue('Dispositivo'),
      TextCellValue('Problema'),
      TextCellValue('Solución'),
      TextCellValue('Repuestos'),
      TextCellValue('Método Pago'),
      TextCellValue('Estado Pago'),
      TextCellValue('Costo'),
    ]);

    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final techId = data['technicianId'] ?? '';
      final techName = techNames[techId] ?? 'Sin Asignar';
      final cost = (data['repairCost'] as num?)?.toDouble() ?? 0.0;
      final date = DateFormat(
        'dd/MM/yyyy',
      ).format((data['scheduledDate'] as Timestamp).toDate());
      final payMethod = data['paymentMethod'] ?? 'N/A';
      final isPaid = data['isPaid'] == true ? 'Pagado' : 'Pendiente';

      sheet.appendRow([
        TextCellValue(doc.id.substring(0, 8).toUpperCase()),
        TextCellValue(date),
        TextCellValue(techName),
        TextCellValue(data['clientName'] ?? ''),
        TextCellValue(data['device'] ?? ''),
        TextCellValue(data['description'] ?? ''),
        TextCellValue(data['solution'] ?? ''),
        TextCellValue(data['spareParts'] ?? ''),
        TextCellValue(payMethod),
        TextCellValue(isPaid),
        DoubleCellValue(cost),
      ]);
    }

    final bytes = excel.save();
    if (bytes != null) {
      await shareBytes(
        Uint8List.fromList(bytes),
        'reporte_servicios_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx',
      );
    }
  }
}
