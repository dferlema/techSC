import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';

class ExportReportService {
  Future<void> generateSalesCSV(List<QueryDocumentSnapshot> docs) async {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln(
      'Pedido ID,Fecha,Vendedor,Cliente,Teléfono,Productos,Método Pago,Estado Pago,Total',
    );

    // Fetch sellers
    Map<String, String> sellerNames = {};
    final userDocs = await FirebaseFirestore.instance.collection('users').get();
    for (var doc in userDocs.docs) {
      final data = doc.data();
      if (data.containsKey('name')) {
        sellerNames[doc.id] = data['name'];
      }
    }

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

    final output = await getTemporaryDirectory();
    final file = File(
      '${output.path}/reporte_ventas_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
    );
    await file.writeAsString(buffer.toString(), encoding: utf8);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Reporte de Ventas CSV',
      text: 'Aquí está el reporte de ventas generado desde TechSC.',
    );
  }

  Future<void> generateSalesExcel(List<QueryDocumentSnapshot> docs) async {
    final excel = Excel.createExcel();
    final sheet = excel['Reporte de Ventas'];

    // Fetch sellers
    Map<String, String> sellerNames = {};
    final userDocs = await FirebaseFirestore.instance.collection('users').get();
    for (var doc in userDocs.docs) {
      final data = doc.data();
      if (data.containsKey('name')) {
        sellerNames[doc.id] = data['name'];
      }
    }

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

    final output = await getTemporaryDirectory();
    final file = File(
      '${output.path}/reporte_ventas_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx',
    );
    final bytes = excel.save();
    if (bytes != null) {
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Reporte de Ventas Excel',
        text: 'Aquí está el reporte de ventas generado desde TechSC.',
      );
    }
  }

  Future<void> generateServicesCSV(List<QueryDocumentSnapshot> docs) async {
    final StringBuffer buffer = StringBuffer();
    buffer.writeln(
      'Reserva ID,Fecha,Técnico,Cliente,Dispositivo,Problema,Solución,Repuestos,Método Pago,Estado Pago,Costo',
    );

    // Fetch technicians
    Map<String, String> techNames = {};
    final userDocs = await FirebaseFirestore.instance.collection('users').get();
    for (var doc in userDocs.docs) {
      final data = doc.data();
      if (data.containsKey('name')) {
        techNames[doc.id] = data['name'];
      } else if (data.containsKey('userName')) {
        techNames[doc.id] = data['userName'];
      }
    }

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

    final output = await getTemporaryDirectory();
    final file = File(
      '${output.path}/reporte_servicios_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv',
    );
    await file.writeAsString(buffer.toString(), encoding: utf8);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Reporte de Servicios CSV',
      text: 'Aquí está el reporte de servicios generado desde TechSC.',
    );
  }

  Future<void> generateServicesExcel(List<QueryDocumentSnapshot> docs) async {
    final excel = Excel.createExcel();
    final sheet = excel['Reporte de Servicios'];

    // Fetch technicians
    Map<String, String> techNames = {};
    final userDocs = await FirebaseFirestore.instance.collection('users').get();
    for (var doc in userDocs.docs) {
      final data = doc.data();
      if (data.containsKey('name')) {
        techNames[doc.id] = data['name'];
      } else if (data.containsKey('userName')) {
        techNames[doc.id] = data['userName'];
      }
    }

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

    final output = await getTemporaryDirectory();
    final file = File(
      '${output.path}/reporte_servicios_${DateFormat('yyyyMMdd').format(DateTime.now())}.xlsx',
    );
    final bytes = excel.save();
    if (bytes != null) {
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Reporte de Servicios Excel',
        text: 'Aquí está el reporte de servicios generado desde TechSC.',
      );
    }
  }
}
