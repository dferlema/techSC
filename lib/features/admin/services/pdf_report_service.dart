import 'package:flutter/material.dart'; // For Colors (technically pdf uses PdfColors but some logic might use Material colors, checking...)
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:techsc/core/services/config_service.dart';
import 'package:techsc/core/models/config_model.dart';

class PdfReportService {
  Future<void> generateSalesPDF(
    List<QueryDocumentSnapshot> docs,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final config = await ConfigService().getConfig();
    final pdf = pw.Document();
    final dateRange =
        'Del ${DateFormat('dd/MM/yyyy').format(startDate)} al ${DateFormat('dd/MM/yyyy').format(endDate)}';

    // Fetch sellers to map IDs to Names
    Map<String, String> sellerNames = {};
    try {
      final userDocs = await FirebaseFirestore.instance
          .collection('users')
          .get();
      for (var doc in userDocs.docs) {
        final data = doc.data();
        if (data.containsKey('name')) {
          sellerNames[doc.id] = data['name'];
        }
      }
    } catch (e) {
      debugPrint('Error fetching sellers: $e');
    }

    // Group by Seller
    Map<String, List<Map<String, dynamic>>> groupedBySeller = {};
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final originalQuote = data['originalQuote'] as Map<String, dynamic>?;
      final sellerId =
          originalQuote?['creatorId'] as String? ??
          data['userId'] ??
          'Sin Asignar';

      if (!groupedBySeller.containsKey(sellerId)) {
        groupedBySeller[sellerId] = [];
      }
      groupedBySeller[sellerId]!.add({'id': doc.id, 'data': data});
    }

    // Build PDF
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        header: (context) => _buildPDFHeader(
          'Reporte de Ventas por Vendedor',
          dateRange,
          config,
        ),
        footer: (context) => _buildPDFFooter(config),
        build: (context) {
          final List<pw.Widget> content = [];
          double grandTotal = 0;

          groupedBySeller.forEach((sellerId, orders) {
            double sellerTotal = 0;
            final sellerName =
                sellerNames[sellerId] ??
                (sellerId == 'Sin Asignar'
                    ? 'Sin Vendedor Asignado'
                    : 'ID: ${sellerId.substring(0, 6)}...');

            // Header for Seller
            content.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 20, bottom: 10),
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 5,
                  horizontal: 10,
                ),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.blue50,
                  border: pw.Border(
                    left: pw.BorderSide(color: PdfColors.blue900, width: 4),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Vendedor: $sellerName',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.Text(
                      '${orders.length} pedidos',
                      style: const pw.TextStyle(color: PdfColors.grey700),
                    ),
                  ],
                ),
              ),
            );

            // Table for this Seller
            final tableData = <List<String>>[
              [
                'Pedido',
                'Fecha',
                'Cliente',
                'Teléfono',
                'Productos',
                'Método Pago',
                'Estado',
                'Total',
              ],
              for (var order in orders) ...[
                () {
                  final data = order['data'] as Map<String, dynamic>;
                  final originalQuote =
                      data['originalQuote'] as Map<String, dynamic>?;
                  final total = (data['total'] ?? 0.0).toDouble();
                  sellerTotal += total;

                  final clientName =
                      originalQuote?['clientName'] ??
                      data['userName'] ??
                      'Desconocido';
                  final clientPhone = originalQuote?['clientPhone'] ?? '';
                  final items =
                      (originalQuote?['items'] as List<dynamic>? ?? []);
                  final productsStr = items.isEmpty
                      ? 'N/A'
                      : items
                                .take(2)
                                .map(
                                  (item) =>
                                      '${item['quantity']}x ${item['name']}',
                                )
                                .join(', ') +
                            (items.length > 2 ? '...' : '');
                  final paymentMethod = data['paymentMethod'] ?? 'N/A';
                  final status = data['status'] ?? 'pendiente';

                  return [
                    order['id'].toString().substring(0, 6).toUpperCase(),
                    DateFormat(
                      'dd/MM/yy',
                    ).format((data['createdAt'] as Timestamp).toDate()),
                    clientName.toString(),
                    clientPhone.toString(),
                    productsStr,
                    paymentMethod.toString().toUpperCase(),
                    status.toString().toUpperCase(),
                    '\$${total.toStringAsFixed(2)}',
                  ];
                }(),
              ],
            ];

            content.add(
              pw.Table.fromTextArray(
                data: tableData,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 9,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blue700,
                ),
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellAlignment: pw.Alignment.centerLeft,
                columnWidths: {
                  0: const pw.FixedColumnWidth(40),
                  1: const pw.FixedColumnWidth(50),
                  2: const pw.FlexColumnWidth(2),
                  3: const pw.FixedColumnWidth(60),
                  4: const pw.FlexColumnWidth(3),
                  5: const pw.FixedColumnWidth(50),
                  6: const pw.FixedColumnWidth(50),
                  7: const pw.FixedColumnWidth(50),
                },
              ),
            );

            // Subtotal for Seller
            content.add(
              pw.Container(
                alignment: pw.Alignment.centerRight,
                margin: const pw.EdgeInsets.only(top: 5),
                child: pw.Text(
                  'Subtotal Vendedor: \$${sellerTotal.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            );

            grandTotal += sellerTotal;
          });

          // Grand Total
          content.add(pw.SizedBox(height: 30));
          content.add(pw.Divider());
          content.add(
            pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(top: 5),
              padding: const pw.EdgeInsets.all(10),
              color: PdfColors.green50,
              child: pw.Text(
                'GRAN TOTAL RECAUDADO: \$${grandTotal.toStringAsFixed(2)}',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 16,
                  color: PdfColors.green900,
                ),
              ),
            ),
          );

          return content;
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  Future<void> generateServicesPDF(
    List<QueryDocumentSnapshot> docs,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final config = await ConfigService().getConfig();
    final pdf = pw.Document();
    final dateRange =
        'Del ${DateFormat('dd/MM/yyyy').format(startDate)} al ${DateFormat('dd/MM/yyyy').format(endDate)}';

    // 1. Fetch Technicians
    Map<String, String> technicianNames = {};
    try {
      final userDocs = await FirebaseFirestore.instance
          .collection('users')
          .get();
      for (var doc in userDocs.docs) {
        final data = doc.data();
        if (data.containsKey('name')) {
          technicianNames[doc.id] = data['name'];
        } else if (data.containsKey('userName')) {
          technicianNames[doc.id] = data['userName'];
        }
      }
    } catch (e) {
      debugPrint('Error fetching technicians: $e');
    }

    // 2. Group by Technician
    Map<String, List<Map<String, dynamic>>> groupedByTech = {};
    for (var doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final techId = data['technicianId'] as String? ?? 'Sin Asignar';
      if (!groupedByTech.containsKey(techId)) {
        groupedByTech[techId] = [];
      }
      groupedByTech[techId]!.add(data);
    }

    // 3. Build PDF
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        header: (context) => _buildPDFHeader(
          'Reporte de Servicios por Técnico',
          dateRange,
          config,
        ),
        footer: (context) => _buildPDFFooter(config),
        build: (context) {
          final List<pw.Widget> content = [];
          double grandTotal = 0;

          groupedByTech.forEach((techId, services) {
            double techTotal = 0;
            final techName =
                technicianNames[techId] ??
                (techId == 'Sin Asignar'
                    ? 'Sin Técnico Asignado'
                    : 'ID: ${techId.substring(0, 6)}...');

            // Header for Technician
            content.add(
              pw.Container(
                margin: const pw.EdgeInsets.only(top: 20, bottom: 10),
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 5,
                  horizontal: 10,
                ),
                decoration: const pw.BoxDecoration(
                  color: PdfColors.blueGrey50,
                  border: pw.Border(
                    left: pw.BorderSide(color: PdfColors.blue900, width: 4),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Técnico: $techName',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.Text(
                      '${services.length} servicios',
                      style: const pw.TextStyle(color: PdfColors.grey700),
                    ),
                  ],
                ),
              ),
            );

            // Table for this Technician
            final tableData = <List<String>>[
              ['Fecha', 'Cliente', 'Dispositivo', 'Solución', 'Pago', 'Costo'],
              for (var data in services) ...[
                () {
                  final cost = (data['repairCost'] as num?)?.toDouble() ?? 0.0;
                  techTotal += cost;
                  final payMethod = (data['paymentMethod'] ?? 'N/A')
                      .toString()
                      .toUpperCase();
                  final isPaid = data['isPaid'] == true ? 'OK' : 'PEND';
                  final paymentStr = '$payMethod\n($isPaid)';

                  return [
                    DateFormat(
                      'dd/MM/yy',
                    ).format((data['scheduledDate'] as Timestamp).toDate()),
                    (data['clientName'] ?? data['userName'] ?? 'N/A')
                        .toString(),
                    (data['device'] ?? 'N/A').toString(),
                    (data['solution'] ?? 'Pendiente').toString(),
                    paymentStr,
                    '\$${cost.toStringAsFixed(2)}',
                  ];
                }(),
              ],
            ];

            content.add(
              pw.Table.fromTextArray(
                data: tableData,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.blue700,
                ),
                cellStyle: const pw.TextStyle(fontSize: 9),
                cellAlignment: pw.Alignment.centerLeft,
                columnWidths: {
                  0: const pw.FixedColumnWidth(50),
                  1: const pw.FixedColumnWidth(80),
                  2: const pw.FixedColumnWidth(70),
                  3: const pw.FlexColumnWidth(2),
                  4: const pw.FixedColumnWidth(60),
                  5: const pw.FixedColumnWidth(50),
                },
              ),
            );

            // Subtotal for Technician
            content.add(
              pw.Container(
                alignment: pw.Alignment.centerRight,
                margin: const pw.EdgeInsets.only(top: 5),
                child: pw.Text(
                  'Subtotal Técnico: \$${techTotal.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            );

            grandTotal += techTotal;
          });

          // Grand Total
          content.add(pw.SizedBox(height: 30));
          content.add(pw.Divider());
          content.add(
            pw.Container(
              alignment: pw.Alignment.centerRight,
              margin: const pw.EdgeInsets.only(top: 5),
              padding: const pw.EdgeInsets.all(10),
              color: PdfColors.green50,
              child: pw.Text(
                'GRAN TOTAL RECAUDADO: \$${grandTotal.toStringAsFixed(2)}',
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 16,
                  color: PdfColors.green900,
                ),
              ),
            ),
          );

          return content;
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  Future<void> generateCatalogPDF() async {
    try {
      final config = await ConfigService().getConfig();
      final productsDocs = await FirebaseFirestore.instance
          .collection('products')
          .get();
      final servicesDocs = await FirebaseFirestore.instance
          .collection('services')
          .get();

      // Group products by category
      Map<String, List<Map<String, dynamic>>> groupedProducts = {};
      for (var doc in productsDocs.docs) {
        final data = doc.data();
        final category = (data['category'] ?? 'General')
            .toString()
            .toUpperCase();
        if (!groupedProducts.containsKey(category)) {
          groupedProducts[category] = [];
        }
        groupedProducts[category]!.add(data);
      }

      // Helper for cell building
      pw.Widget buildCell(String text, {bool isHeader = false}) {
        return pw.Padding(
          padding: const pw.EdgeInsets.all(6),
          child: pw.Text(
            text,
            maxLines: 4,
            overflow: pw.TextOverflow.span,
            style: isHeader
                ? pw.TextStyle(
                    color: PdfColors.white,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 11,
                  )
                : const pw.TextStyle(fontSize: 10),
          ),
        );
      }

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          header: (context) => _buildPDFHeader(
            'Catálogo de Productos',
            DateFormat('dd/MM/yyyy').format(DateTime.now()),
            config,
          ),
          footer: (context) => _buildPDFFooter(config),
          build: (context) => [
            // Products Section
            pw.Header(
              level: 0,
              text: 'PRODUCTOS',
              textStyle: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue800,
              ),
            ),
            for (var entry in groupedProducts.entries) ...[
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 15, bottom: 8),
                child: pw.Text(
                  entry.key,
                  style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey800,
                  ),
                ),
              ),
              pw.Table(
                border: pw.TableBorder.all(
                  width: 0.5,
                  color: PdfColors.grey300,
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(3), // Name
                  1: const pw.FlexColumnWidth(5), // Specs/Description
                  2: const pw.FlexColumnWidth(2), // Price
                },
                children: [
                  // Header Row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.blue800,
                    ),
                    children: [
                      buildCell('Producto', isHeader: true),
                      buildCell('Descripción', isHeader: true),
                      buildCell('Precio', isHeader: true),
                    ],
                  ),
                  // Data Rows
                  for (var p in entry.value)
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        border: pw.Border(
                          bottom: pw.BorderSide(
                            color: PdfColors.grey200,
                            width: 0.5,
                          ),
                        ),
                      ),
                      children: [
                        buildCell(p['name'] ?? '—'),
                        buildCell(p['specs'] ?? p['description'] ?? '—'),
                        buildCell('\$${p['price'] ?? 0}'),
                      ],
                    ),
                ],
              ),
              pw.SizedBox(height: 10),
            ],

            pw.SizedBox(height: 20),

            // Services Section
            pw.Header(
              level: 0,
              text: 'SERVICIOS TÉCNICOS',
              textStyle: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.green800,
              ),
            ),
            pw.Table.fromTextArray(
              data: [
                ['Servicio', 'Descripción', 'Precio Base'],
                for (var doc in servicesDocs.docs)
                  [
                    doc.data()['title'] ?? '—',
                    doc.data()['description'] ?? '—',
                    '\$${doc.data()['price'] ?? 0}',
                  ],
              ],
              border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.green700,
              ),
              cellAlignment: pw.Alignment.centerLeft,
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(5),
                2: const pw.FlexColumnWidth(2),
              },
            ),

            pw.SizedBox(height: 40),
            pw.Divider(color: PdfColors.grey400),
            pw.Container(
              alignment: pw.Alignment.center,
              child: pw.Text(
                'TODOS NUESTROS PRECIOS INCLUYEN IMPUESTOS',
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey800,
                ),
              ),
            ),
          ],
        ),
      );

      await Printing.layoutPdf(onLayout: (format) => pdf.save());
    } catch (e) {
      debugPrint('Error generating catalog: $e');
      // We don't have context here to show snackbar, so we just log the error or rethrow
      // Ideally we should return a Result object or throw to be handled by UI
      rethrow;
    }
  }

  pw.Widget _buildPDFFooter(ConfigModel config) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Divider(color: PdfColors.grey400),
          pw.Text(
            'Contacto: ${config.companyEmail} | Tel: ${config.companyPhone}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
          pw.Text(
            'Ubicación: ${config.companyAddress}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'Generado por ${config.companyName}',
            style: pw.TextStyle(
              fontSize: 7,
              fontStyle: pw.FontStyle.italic,
              color: PdfColors.grey400,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPDFHeader(String title, String subtitle, ConfigModel config) {
    return pw.Column(
      children: [
        pw.Center(
          child: pw.Text(
            config.companyName.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
        ),
        pw.Center(
          child: pw.Text(
            title,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Center(
          child: pw.Text(
            subtitle,
            style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Divider(),
        pw.SizedBox(height: 20),
      ],
    );
  }
}
