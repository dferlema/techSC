import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:tscomputer/core/platform/io_helper.dart';
import 'package:tscomputer/features/receipt/models/receipt_config_model.dart';

enum ReceiptFormat { thermal80mm, a4 }

class ReceiptService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<ReceiptConfigModel> loadConfig() async {
    try {
      final doc = await _firestore.collection('receipt_config').doc('company').get();
      if (doc.exists && doc.data() != null) {
        return ReceiptConfigModel.fromMap(doc.data()!, doc.id);
      }
    } catch (e) {
      debugPrint('Error loading receipt config: $e');
    }
    return ReceiptConfigModel();
  }

  Future<void> saveConfig(ReceiptConfigModel config) async {
    await _firestore.collection('receipt_config').doc('company').set(config.toMap());
  }

  Future<Uint8List> generateReceipt({
    required ReceiptConfigModel config,
    required ReceiptFormat format,
    required WorkshopReceiptData data,
  }) async {
    final pdf = pw.Document();

    if (format == ReceiptFormat.thermal80mm) {
      _buildThermal80mm(pdf: pdf, config: config, data: data);
    } else {
      _buildA4(pdf: pdf, config: config, data: data);
    }

    return pdf.save();
  }

  // ─────────────────── TÉRMICA 80mm ───────────────────

  void _buildThermal80mm({
    required pw.Document pdf,
    required ReceiptConfigModel config,
    required WorkshopReceiptData data,
  }) {
    final dfShort = DateFormat('dd/MM/yyyy');
    final items = [...data.services, ...data.parts];
    final allItems = <pw.Widget>[];

    for (final item in items) {
      allItems.add(pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(child: pw.Text(item.description, style: const pw.TextStyle(fontSize: 7))),
          pw.Text('\$${item.total.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 7)),
        ],
      ));
      if (item.quantity > 1) {
        allItems.add(pw.Text(
          '  ${item.quantity} x \$${item.unitPrice.toStringAsFixed(2)}',
          style: const pw.TextStyle(fontSize: 6),
        ));
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat(80 * PdfPageFormat.mm, 250 * PdfPageFormat.mm),
        margin: const pw.EdgeInsets.all(4 * PdfPageFormat.mm),
        build: (context) => [
          // ENCABEZADO
          _thCenter(config.companyName.toUpperCase(), fontSize: 11, bold: true),
          if (config.style.showRuc && config.ruc.isNotEmpty)
            _thCenter('RUC: ${config.ruc}', fontSize: 7),
          if (config.style.showAddress && config.address.isNotEmpty)
            _thCenter(config.address, fontSize: 6),
          if (config.style.showPhone && config.phone.isNotEmpty)
            _thCenter('Tel: ${config.phone}', fontSize: 6),
          if (config.style.showEmail && config.email.isNotEmpty)
            _thCenter('Email: ${config.email}', fontSize: 6),
          pw.SizedBox(height: 4),
          _thDivider(),
          pw.SizedBox(height: 2),
          _thCenter('ORDEN DE SERVICIO', fontSize: 9, bold: true),
          pw.SizedBox(height: 2),
          _thLeft('Nº: ${data.saleNumber}', fontSize: 7),
          _thLeft('Fecha: ${dfShort.format(data.date)}', fontSize: 7),
          pw.SizedBox(height: 4),
          _thDivider(),

          // DATOS DEL CLIENTE
          pw.SizedBox(height: 2),
          _thSectionTitle('CLIENTE'),
          _thLeft('Nom: ${data.clientName}', fontSize: 7),
          if (data.clientId.isNotEmpty) _thLeft('ID: ${data.clientId}', fontSize: 7),
          if (data.clientPhone.isNotEmpty) _thLeft('Tel: ${data.clientPhone}', fontSize: 7),
          if (data.clientEmail.isNotEmpty) _thLeft('Email: ${data.clientEmail}', fontSize: 6),
          if (data.clientAddress.isNotEmpty) _thLeft('Dir: ${data.clientAddress}', fontSize: 6),
          pw.SizedBox(height: 4),
          _thDivider(),

          // DATOS DEL EQUIPO
          pw.SizedBox(height: 2),
          _thSectionTitle('EQUIPO'),
          if (data.deviceType.isNotEmpty) _thLeft('Tipo: ${data.deviceType}', fontSize: 7),
          if (data.brand.isNotEmpty || data.model.isNotEmpty)
            _thLeft('Marca/Modelo: ${data.brand} ${data.model}', fontSize: 7),
          if (data.serialNumber.isNotEmpty) _thLeft('Serie/IMEI: ${data.serialNumber}', fontSize: 7),
          if (data.pin != null && data.pin!.isNotEmpty) _thLeft('PIN: ${data.pin}', fontSize: 7),
          if (data.accessories.isNotEmpty) _thLeft('Accesorios: ${data.accessories}', fontSize: 6),
          if (data.reportedFault.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            _thLeft('Falla: ${data.reportedFault}', fontSize: 6),
          ],
          _thLeft('Recepción: ${dfShort.format(data.receptionDate)}', fontSize: 7),
          if (data.estimatedDeliveryDate != null)
            _thLeft('Entrega est.: ${dfShort.format(data.estimatedDeliveryDate!)}', fontSize: 7),
          pw.SizedBox(height: 4),
          _thDivider(),

          // DESCRIPCIÓN DEL TRABAJO
          if (data.diagnosis.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            _thSectionTitle('DIAGNÓSTICO'),
            _thLeft(data.diagnosis, fontSize: 6),
            pw.SizedBox(height: 4),
            _thDivider(),
          ],

          // DETALLE (servicios + repuestos)
          pw.SizedBox(height: 2),
          _thSectionTitle('DETALLE'),
          pw.SizedBox(height: 2),
          ...allItems,
          pw.SizedBox(height: 4),
          _thDivider(),

          // TOTALES
          pw.SizedBox(height: 2),
          _thRow('Subtotal:', '\$${data.subtotal.toStringAsFixed(2)}'),
          if (data.iva > 0) _thRow('IVA 15%:', '\$${data.iva.toStringAsFixed(2)}'),
          if (data.discount > 0) _thRow('Descuento:', '-\$${data.discount.toStringAsFixed(2)}'),
          _thDivider(thick: true),
          _thRow('TOTAL:', '\$${data.total.toStringAsFixed(2)}', bold: true),
          if (data.paymentMethod.isNotEmpty)
            _thLeft('Pago: ${data.paymentMethod}', fontSize: 7),
          if (data.advance > 0) _thRow('Abono:', '\$${data.advance.toStringAsFixed(2)}'),
          if (data.pendingBalance > 0)
            _thRow('Saldo:', '\$${data.pendingBalance.toStringAsFixed(2)}', bold: true),
          pw.SizedBox(height: 4),
          _thDivider(),

          // GARANTÍA
          if (data.warrantyTerms.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            _thSectionTitle('GARANTÍA'),
            _thLeft(data.warrantyTerms, fontSize: 6),
            pw.SizedBox(height: 4),
            _thDivider(),
          ],

          // TÉCNICO
          if (data.technicianName != null && data.technicianName!.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            _thLeft('Técnico: ${data.technicianName}', fontSize: 7),
          ],

          // OBSERVACIONES
          if (data.additionalNotes != null && data.additionalNotes!.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            _thSectionTitle('OBSERVACIONES'),
            _thLeft(data.additionalNotes!, fontSize: 6),
          ],

          // FECHA ENTREGA REAL
          if (data.actualDeliveryDate != null) ...[
            pw.SizedBox(height: 4),
            _thLeft('Entrega: ${dfShort.format(data.actualDeliveryDate!)}', fontSize: 7),
          ],

          // FIRMAS
          pw.SizedBox(height: 12),
          _thDivider(),
          pw.SizedBox(height: 2),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                child: pw.Column(children: [
                  pw.Text('_' * 20, style: const pw.TextStyle(fontSize: 7)),
                  _thCenter('Firma Técnico', fontSize: 6),
                ]),
              ),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pw.Column(children: [
                  pw.Text('_' * 20, style: const pw.TextStyle(fontSize: 7)),
                  _thCenter('Firma Cliente', fontSize: 6),
                ]),
              ),
            ],
          ),

          pw.SizedBox(height: 8),
          _thCenter(
            config.receiptFooter ?? 'Gracias por su preferencia',
            fontSize: 6,
          ),
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: _buildQrPayload(data),
              width: 40,
              height: 40,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _thCenter(String text, {double fontSize = 7, bool bold = false}) {
    return pw.Center(
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? pw.FontWeight.bold : null,
        ),
      ),
    );
  }

  pw.Widget _thLeft(String text, {double fontSize = 7}) {
    return pw.Align(
      alignment: pw.Alignment.centerLeft,
      child: pw.Text(text, style: pw.TextStyle(fontSize: fontSize)),
    );
  }

  pw.Widget _thSectionTitle(String title) {
    return pw.Align(
      alignment: pw.Alignment.centerLeft,
      child: pw.Text(
        title,
        style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
      ),
    );
  }

  pw.Widget _thDivider({bool thick = false}) {
    return pw.Divider(height: 2, thickness: thick ? 1 : 0.5);
  }

  pw.Widget _thRow(String label, String value, {bool bold = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 7, fontWeight: bold ? pw.FontWeight.bold : null)),
        pw.Text(value, style: pw.TextStyle(fontSize: 7, fontWeight: bold ? pw.FontWeight.bold : null)),
      ],
    );
  }

  // ─────────────────── A4 ───────────────────

  void _buildA4({
    required pw.Document pdf,
    required ReceiptConfigModel config,
    required WorkshopReceiptData data,
  }) {
    final margins = config.a4Margins;
    final primaryColor = PdfColor.fromHex('#${config.style.primaryColor}');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.only(
          top: margins.top * PdfPageFormat.mm,
          bottom: margins.bottom * PdfPageFormat.mm,
          left: margins.left * PdfPageFormat.mm,
          right: margins.right * PdfPageFormat.mm,
        ),
        header: (context) => _a4Header(config, data, primaryColor),
        footer: (context) => _a4Footer(config, data, context.pageNumber, context.pagesCount),
        build: (context) => [
          _a4ClientSection(data),
          pw.SizedBox(height: 10),
          _a4EquipmentSection(data, primaryColor),
          pw.SizedBox(height: 10),
          _a4WorkSection(data, primaryColor),
          pw.SizedBox(height: 10),
          _a4ItemsTable(data),
          pw.SizedBox(height: 10),
          _a4PaymentSection(data, primaryColor),
          pw.SizedBox(height: 10),
          _a4WarrantySection(data),
          pw.SizedBox(height: 10),
          _a4SignaturesSection(data),
          if (data.additionalNotes != null && data.additionalNotes!.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            _a4NotesSection(data),
          ],
        ],
      ),
    );
  }

  pw.Widget _a4Header(ReceiptConfigModel config, WorkshopReceiptData data, PdfColor primaryColor) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (config.style.showLogo && config.logoUrl != null && config.logoUrl!.isNotEmpty)
              pw.Container(
                width: 55,
                height: 55,
                decoration: pw.BoxDecoration(borderRadius: pw.BorderRadius.circular(4)),
                child: pw.Center(
                  child: pw.Text('LOGO', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                ),
              ),
            if (config.style.showLogo && config.logoUrl != null && config.logoUrl!.isNotEmpty)
              pw.SizedBox(width: 12),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    config.companyName.toUpperCase(),
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: primaryColor),
                  ),
                  if (config.businessType != null && config.businessType!.isNotEmpty)
                    pw.Text(config.businessType!, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  if (config.style.showRuc && config.ruc.isNotEmpty)
                    pw.Text('RUC: ${config.ruc}', style: const pw.TextStyle(fontSize: 9)),
                  if (config.style.showAddress && config.address.isNotEmpty)
                    pw.Text(config.address, style: const pw.TextStyle(fontSize: 9)),
                  if (config.style.showPhone || config.style.showEmail)
                    pw.Row(children: [
                      if (config.style.showPhone && config.phone.isNotEmpty)
                        pw.Text('Tel: ${config.phone}  ', style: const pw.TextStyle(fontSize: 9)),
                      if (config.style.showEmail && config.email.isNotEmpty)
                        pw.Text('Email: ${config.email}', style: const pw.TextStyle(fontSize: 9)),
                    ]),
                ],
              ),
            ),
            pw.Flexible(
              child: pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  children: [
                    pw.Text('ORDEN', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      data.saleNumber,
                      style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(DateFormat('dd/MM/yyyy').format(data.date), style: const pw.TextStyle(fontSize: 8, color: PdfColors.white)),
                  ],
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Divider(color: primaryColor, thickness: 2),
      ],
    );
  }

  pw.Widget _a4Footer(ReceiptConfigModel config, WorkshopReceiptData data, int pageNum, int totalPages) {
    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey300),
        pw.SizedBox(height: 4),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: _buildQrPayload(data),
              width: 45,
              height: 45,
            ),
            pw.SizedBox(width: 10),
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(config.receiptFooter ?? 'Gracias por su preferencia', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey)),
                  pw.SizedBox(height: 2),
                  pw.Text('Página $pageNum de $totalPages', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─ Secciones A4 ─

  pw.Widget _a4ClientSection(WorkshopReceiptData data) {
    return _a4Box('DATOS DEL CLIENTE', [
      pw.Row(children: [
        pw.Expanded(child: _a4Field('Nombre', data.clientName)),
        pw.SizedBox(width: 10),
        pw.Expanded(child: _a4Field('Documento', data.clientId.isNotEmpty ? data.clientId : '—')),
      ]),
      pw.SizedBox(height: 6),
      pw.Row(children: [
        pw.Expanded(child: _a4Field('Teléfono', data.clientPhone.isNotEmpty ? data.clientPhone : '—')),
        pw.SizedBox(width: 10),
        pw.Expanded(child: _a4Field('Email', data.clientEmail.isNotEmpty ? data.clientEmail : '—')),
      ]),
      if (data.clientAddress.isNotEmpty) ...[
        pw.SizedBox(height: 6),
        _a4Field('Dirección', data.clientAddress),
      ],
    ]);
  }

  pw.Widget _a4EquipmentSection(WorkshopReceiptData data, PdfColor primaryColor) {
    return _a4Box('DATOS DEL EQUIPO', [
      pw.Row(children: [
        if (data.deviceType.isNotEmpty)
          pw.Expanded(child: _a4Field('Tipo', data.deviceType)),
        if (data.brand.isNotEmpty || data.model.isNotEmpty) ...[
          pw.SizedBox(width: 10),
          pw.Expanded(child: _a4Field('Marca / Modelo', '${data.brand} ${data.model}'.trim())),
        ],
      ]),
      if (data.serialNumber.isNotEmpty || data.pin != null) ...[
        pw.SizedBox(height: 6),
        pw.Row(children: [
          if (data.serialNumber.isNotEmpty)
            pw.Expanded(child: _a4Field('Serie / IMEI', data.serialNumber)),
          if (data.pin != null && data.pin!.isNotEmpty) ...[
            pw.SizedBox(width: 10),
            pw.Expanded(child: _a4Field('PIN', data.pin!)),
          ],
        ]),
      ],
      if (data.accessories.isNotEmpty) ...[
        pw.SizedBox(height: 6),
        _a4Field('Accesorios Entregados', data.accessories),
      ],
      pw.SizedBox(height: 6),
      pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(color: PdfColors.red50, borderRadius: pw.BorderRadius.circular(4)),
        child: pw.Row(children: [
          pw.Text('Falla reportada: ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          pw.Expanded(child: pw.Text(data.reportedFault.isNotEmpty ? data.reportedFault : '—', style: const pw.TextStyle(fontSize: 9))),
        ]),
      ),
      pw.SizedBox(height: 6),
      pw.Row(children: [
        pw.Expanded(child: _a4Field('Fecha Recepción', DateFormat('dd/MM/yyyy').format(data.receptionDate))),
        pw.SizedBox(width: 10),
        pw.Expanded(child: _a4Field(
          'Entrega Estimada',
          data.estimatedDeliveryDate != null ? DateFormat('dd/MM/yyyy').format(data.estimatedDeliveryDate!) : '—',
        )),
      ]),
    ]);
  }

  pw.Widget _a4WorkSection(WorkshopReceiptData data, PdfColor primaryColor) {
    final widgets = <pw.Widget>[];
    if (data.diagnosis.isNotEmpty) {
      widgets.add(pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(color: PdfColors.blue50, borderRadius: pw.BorderRadius.circular(4)),
        child: pw.Row(children: [
          pw.Text('Diagnóstico: ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          pw.Expanded(child: pw.Text(data.diagnosis, style: const pw.TextStyle(fontSize: 9))),
        ]),
      ));
    }
    return _a4Box('DESCRIPCIÓN DEL TRABAJO', widgets);
  }

  pw.Widget _a4ItemsTable(WorkshopReceiptData data) {
    final allItems = [...data.services, ...data.parts];
    if (allItems.isEmpty) return pw.SizedBox.shrink();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 9),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          columnWidths: {
            0: const pw.FlexColumnWidth(1),
            1: const pw.FlexColumnWidth(4),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(2),
            4: const pw.FlexColumnWidth(2),
          },
          headers: ['#', 'Descripción', 'Cant.', 'P. Unit.', 'Total'],
          data: List.generate(allItems.length, (i) {
            final item = allItems[i];
            return [
              '${i + 1}',
              item.description,
              item.quantity.toString(),
              '\$${item.unitPrice.toStringAsFixed(2)}',
              '\$${item.total.toStringAsFixed(2)}',
            ];
          }),
        ),
      ],
    );
  }

  pw.Widget _a4PaymentSection(WorkshopReceiptData data, PdfColor primaryColor) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 3,
          child: _a4Box('FORMA DE PAGO', [
            if (data.paymentMethod.isNotEmpty) _a4Field('Método', data.paymentMethod),
            if (data.advance > 0) ...[
              pw.SizedBox(height: 4),
              _a4Field('Abono / Seña', '\$${data.advance.toStringAsFixed(2)}'),
            ],
            if (data.pendingBalance > 0) ...[
              pw.SizedBox(height: 4),
              pw.Container(
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  color: PdfColors.orange50,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: _a4Field('Saldo Pendiente', '\$${data.pendingBalance.toStringAsFixed(2)}'),
              ),
            ],
          ]),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          flex: 2,
          child: pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey50,
              borderRadius: pw.BorderRadius.circular(6),
              border: pw.Border.all(color: PdfColors.grey200),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('RESUMEN', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                pw.SizedBox(height: 8),
                _a4TotalRow('Subtotal:', '\$${data.subtotal.toStringAsFixed(2)}'),
                if (data.iva > 0) _a4TotalRow('IVA 15%:', '\$${data.iva.toStringAsFixed(2)}'),
                if (data.discount > 0) _a4TotalRow('Descuento:', '-\$${data.discount.toStringAsFixed(2)}'),
                pw.Divider(color: PdfColors.grey300),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('TOTAL:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.Text('\$${data.total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  pw.Widget _a4WarrantySection(WorkshopReceiptData data) {
    if (data.warrantyTerms.isEmpty) return pw.SizedBox.shrink();
    return _a4Box('GARANTÍA', [
      pw.Text(data.warrantyTerms, style: const pw.TextStyle(fontSize: 9)),
    ]);
  }

  pw.Widget _a4SignaturesSection(WorkshopReceiptData data) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
          child: pw.Column(children: [
            pw.Text('_' * 30, style: const pw.TextStyle(fontSize: 8)),
            pw.SizedBox(height: 4),
            pw.Text('Firma del Técnico', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            if (data.technicianName != null)
              pw.Text(data.technicianName!, style: const pw.TextStyle(fontSize: 8)),
          ]),
        ),
        pw.SizedBox(width: 30),
        pw.Expanded(
          child: pw.Column(children: [
            pw.Text('_' * 30, style: const pw.TextStyle(fontSize: 8)),
            pw.SizedBox(height: 4),
            pw.Text('Firma del Cliente', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          ]),
        ),
      ],
    );
  }

  pw.Widget _a4NotesSection(WorkshopReceiptData data) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('OBSERVACIONES', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
          pw.SizedBox(height: 4),
          pw.Text(data.additionalNotes!, style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  // ─ Helpers A4 ─

  pw.Widget _a4Box(String title, List<pw.Widget> children) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.grey200),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(title, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
          pw.SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  pw.Widget _a4Field(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label, style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
        pw.Text(value, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
      ],
    );
  }

  pw.Widget _a4TotalRow(String label, String value, {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : null)),
          pw.Text(value, style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : null)),
        ],
      ),
    );
  }

  String _buildQrPayload(WorkshopReceiptData data) {
    final services = data.services.map((s) => '${s.description} (\$${s.total.toStringAsFixed(2)})').join(', ');
    final parts = data.parts.map((p) => '${p.description} x${p.quantity} (\$${p.total.toStringAsFixed(2)})').join(', ');
    final lines = <String>[
      'ORDEN: ${data.saleNumber}',
      'Fecha: ${DateFormat('dd/MM/yyyy').format(data.date)}',
      'Cliente: ${data.clientName}',
      if (data.clientId.isNotEmpty) 'ID: ${data.clientId}',
      'Equipo: ${data.deviceType} ${data.brand} ${data.model}'.trim(),
      if (services.isNotEmpty) 'Servicios: $services',
      if (parts.isNotEmpty) 'Repuestos: $parts',
      'Total: \$${data.total.toStringAsFixed(2)}',
      if (data.paymentMethod.isNotEmpty) 'Pago: ${data.paymentMethod}',
      if (data.pendingBalance > 0) 'Saldo: \$${data.pendingBalance.toStringAsFixed(2)}',
      if (data.technicianName != null) 'Técnico: ${data.technicianName}',
    ];
    return lines.join('\n');
  }

  Future<void> shareReceipt(Uint8List pdfBytes, String saleNumber) async {
    await shareBytes(pdfBytes, 'recibo_$saleNumber.pdf');
  }
}
