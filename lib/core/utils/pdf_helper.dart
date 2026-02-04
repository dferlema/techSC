import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:techsc/features/orders/models/quote_model.dart';
import 'package:techsc/core/models/config_model.dart';
import 'package:techsc/core/services/config_service.dart';

class PdfHelper {
  static Future<Uint8List> generateQuotePdf(QuoteModel quote) async {
    final pdf = pw.Document();
    final config = await ConfigService().getConfig();

    // Load icon font
    final iconFont = await PdfGoogleFonts.materialIcons();

    // Pre-fetch images
    final Map<String, pw.ImageProvider> imageCache = {};
    for (var item in quote.items) {
      if (item.imageUrl != null && item.imageUrl!.isNotEmpty) {
        try {
          final provider = await networkImage(item.imageUrl!);
          imageCache[item.imageUrl!] = provider;
        } catch (e) {
          debugPrint('Error pre-fetching image: $e');
        }
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => _buildHeader(quote, config),
        footer: (context) => _buildFooter(config),
        build: (context) => [
          pw.SizedBox(height: 20),
          _buildClientSection(quote, iconFont),
          pw.SizedBox(height: 30),
          _buildItemsTable(quote, imageCache),
          pw.SizedBox(height: 20),
          _buildTotals(quote),
          pw.SizedBox(height: 30),
          _buildSignatures(),
          pw.SizedBox(height: 20),
          _buildTerms(),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildHeader(QuoteModel quote, ConfigModel config) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  config.companyName.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue900,
                  ),
                ),
                pw.Text(
                  config.companyAddress,
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
                pw.Text(
                  'Tel: ${config.companyPhone} | Email: ${config.companyEmail}',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'COTIZACIÓN',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blueGrey,
                  ),
                ),
                pw.Text(
                  '#${quote.id.toUpperCase()}',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  DateFormat('dd MMMM, yyyy', 'es_EC').format(quote.createdAt),
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(thickness: 2, color: PdfColors.blue900),
      ],
    );
  }

  static pw.Widget _buildClientSection(QuoteModel quote, pw.Font iconFont) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'DATOS DEL CLIENTE',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      quote.clientName.toUpperCase(),
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    pw.Text(
                      'RUC/CI: ${quote.clientId}',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Icon(
                          const pw.IconData(0xe0b0),
                          font: iconFont,
                          size: 12,
                          color: PdfColors.blue900,
                        ),
                        pw.SizedBox(width: 5),
                        pw.Text(
                          quote.clientPhone,
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      children: [
                        pw.Icon(
                          const pw.IconData(0xe0be),
                          font: iconFont,
                          size: 12,
                          color: PdfColors.blue900,
                        ),
                        pw.SizedBox(width: 5),
                        pw.Text(
                          quote.clientEmail,
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSignatures() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
      children: [
        pw.Column(
          children: [
            pw.Container(width: 150, height: 1, color: PdfColors.black),
            pw.SizedBox(height: 5),
            pw.Text('Firma Cliente', style: const pw.TextStyle(fontSize: 10)),
          ],
        ),
        pw.Column(
          children: [
            pw.Container(width: 150, height: 1, color: PdfColors.black),
            pw.SizedBox(height: 5),
            pw.Text(
              'Firma Autorizada',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _buildItemsTable(
    QuoteModel quote,
    Map<String, pw.ImageProvider> imageCache,
  ) {
    final headers = ['', 'Cant.', 'Descripción', 'P. Unit', 'Total'];
    final data = quote.items.map((item) {
      final image = (item.imageUrl != null) ? imageCache[item.imageUrl!] : null;

      return [
        image != null
            ? pw.Container(
                width: 25,
                height: 25,
                child: pw.Image(image, fit: pw.BoxFit.cover),
              )
            : pw.SizedBox(width: 25, height: 25),
        item.quantity.toString(),
        item.name,
        '\$${item.price.toStringAsFixed(2)}',
        '\$${item.total.toStringAsFixed(2)}',
      ];
    }).toList();

    return pw.Table.fromTextArray(
      headers: headers,
      data: data,
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue700),
      cellHeight: 35,
      cellAlignments: {
        0: pw.Alignment.center,
        1: pw.Alignment.center,
        2: pw.Alignment.centerLeft,
        3: pw.Alignment.centerRight,
        4: pw.Alignment.centerRight,
      },
      columnWidths: {
        0: const pw.FixedColumnWidth(30),
        1: const pw.FixedColumnWidth(40),
        2: const pw.FlexColumnWidth(),
        3: const pw.FixedColumnWidth(70),
        4: const pw.FixedColumnWidth(70),
      },
    );
  }

  static pw.Widget _buildTotals(QuoteModel quote) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      child: pw.Container(
        width: 200,
        child: pw.Column(
          children: [
            _buildTotalRow('Subtotal', quote.subtotal),
            _buildTotalRow(
              'IVA (${(quote.taxRate * 100).toInt()}%)',
              quote.taxAmount,
            ),
            pw.Divider(),
            _buildTotalRow('TOTAL', quote.total, isBold: true),
          ],
        ),
      ),
    );
  }

  static pw.Widget _buildTotalRow(
    String label,
    double amount, {
    bool isBold = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(fontWeight: isBold ? pw.FontWeight.bold : null),
          ),
          pw.Text(
            '\$${amount.toStringAsFixed(2)}',
            style: pw.TextStyle(fontWeight: isBold ? pw.FontWeight.bold : null),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTerms() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Términos y Condiciones:',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
        ),
        pw.Text(
          '- Validez de la cotización: 15 días.',
          style: const pw.TextStyle(fontSize: 8),
        ),
        pw.Text(
          '- Precios sujetos a cambio sin previo aviso.',
          style: const pw.TextStyle(fontSize: 8),
        ),
        pw.Text(
          '- Entrega inmediata sujeta a stock.',
          style: const pw.TextStyle(fontSize: 8),
        ),
      ],
    );
  }

  static pw.Widget _buildFooter(ConfigModel config) {
    return pw.Container(
      alignment: pw.Alignment.center,
      margin: const pw.EdgeInsets.only(top: 20),
      child: pw.Text(
        'Gracias por preferir a ${config.companyName}',
        style: pw.TextStyle(
          fontStyle: pw.FontStyle.italic,
          fontSize: 10,
          color: PdfColors.grey600,
        ),
      ),
    );
  }
}
