import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:share_plus/share_plus.dart';
import 'package:techsc/core/services/role_service.dart';
import 'package:techsc/core/services/config_service.dart';
import 'package:techsc/core/models/config_model.dart';
import 'package:techsc/core/widgets/cart_badge.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  int _selectedIndex = 0;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String _userRole = RoleService.CLIENT;
  bool _isLoadingRole = true;

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  Future<void> _checkRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final role = await RoleService().getUserRole(user.uid);
      if (mounted) {
        setState(() {
          _userRole = role;
          _isLoadingRole = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoadingRole = false);
    }
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRole) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacementNamed('/main');
            }
          },
        ),
        title: const Text('Generación de Reportes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: () => _selectDateRange(context),
            tooltip: 'Filtrar por fecha',
          ),
          const CartBadge(),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildSalesReport(),
          _buildServicesReport(),
          _buildCatalogReport(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart),
            label: 'Ventas',
          ),
          NavigationDestination(
            icon: Icon(Icons.build_outlined),
            selectedIcon: Icon(Icons.build),
            label: 'Servicios',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Catálogo',
          ),
        ],
      ),
    );
  }

  Widget _buildSalesReport() {
    if (_userRole == RoleService.TECHNICIAN) {
      return const Center(
        child: Text('Acceso Restringido: Solo Admin/Vendedor'),
      );
    }

    return _SalesReportWidget(
      startDate: _startDate,
      endDate: _endDate,
      onExportPDF: _generateSalesPDF,
      onExportCSV: _generateSalesCSV,
      onExportExcel: _generateSalesExcel,
    );
  }

  Widget _buildServicesReport() {
    if (_userRole == RoleService.SELLER) {
      return const Center(
        child: Text('Acceso Restringido: Solo Admin/Técnico'),
      );
    }

    return _ServicesReportWidget(
      startDate: _startDate,
      endDate: _endDate,
      onExportPDF: _generateServicesPDF,
      onExportCSV: _generateServicesCSV,
      onExportExcel: _generateServicesExcel,
    );
  }

  Widget _buildCatalogReport() {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Listado de precios actual del catálogo',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: Center(
            child: ElevatedButton.icon(
              onPressed: () => _generateCatalogPDF(),
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Generar PDF del Catálogo'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- PDF GENERATION LOGIC ---

  Future<void> _generateSalesPDF(List<QueryDocumentSnapshot> docs) async {
    final config = await ConfigService().getConfig();
    final pdf = pw.Document();
    final dateRange =
        'Del ${DateFormat('dd/MM/yyyy').format(_startDate)} al ${DateFormat('dd/MM/yyyy').format(_endDate)}';

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

  Future<void> _generateSalesCSV(List<QueryDocumentSnapshot> docs) async {
    try {
      final StringBuffer buffer = StringBuffer();
      buffer.writeln(
        'Pedido ID,Fecha,Vendedor,Cliente,Teléfono,Productos,Método Pago,Estado Pago,Total',
      );

      // Fetch sellers
      Map<String, String> sellerNames = {};
      final userDocs = await FirebaseFirestore.instance
          .collection('users')
          .get();
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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Reporte CSV generado correctamente')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Error al exportar CSV: $e')));
    }
  }

  Future<void> _generateSalesExcel(List<QueryDocumentSnapshot> docs) async {
    try {
      final excel = excel_pkg.Excel.createExcel();
      final sheet = excel['Reporte de Ventas'];

      // Fetch sellers
      Map<String, String> sellerNames = {};
      final userDocs = await FirebaseFirestore.instance
          .collection('users')
          .get();
      for (var doc in userDocs.docs) {
        final data = doc.data();
        if (data.containsKey('name')) {
          sellerNames[doc.id] = data['name'];
        }
      }

      // Headers
      sheet.appendRow([
        excel_pkg.TextCellValue('Pedido ID'),
        excel_pkg.TextCellValue('Fecha'),
        excel_pkg.TextCellValue('Vendedor'),
        excel_pkg.TextCellValue('Cliente'),
        excel_pkg.TextCellValue('Teléfono'),
        excel_pkg.TextCellValue('Productos'),
        excel_pkg.TextCellValue('Método Pago'),
        excel_pkg.TextCellValue('Estado Pago'),
        excel_pkg.TextCellValue('Total'),
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
          excel_pkg.TextCellValue(doc.id.substring(0, 8).toUpperCase()),
          excel_pkg.TextCellValue(date),
          excel_pkg.TextCellValue(sellerName),
          excel_pkg.TextCellValue(clientName),
          excel_pkg.TextCellValue(clientPhone),
          excel_pkg.TextCellValue(productsStr),
          excel_pkg.TextCellValue(paymentMethod),
          excel_pkg.TextCellValue(paymentStatus),
          excel_pkg.DoubleCellValue(total),
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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Reporte Excel generado correctamente')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Error al exportar Excel: $e')));
    }
  }

  Future<void> _generateServicesPDF(List<QueryDocumentSnapshot> docs) async {
    final config = await ConfigService().getConfig();
    final pdf = pw.Document();
    final dateRange =
        'Del ${DateFormat('dd/MM/yyyy').format(_startDate)} al ${DateFormat('dd/MM/yyyy').format(_endDate)}';

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

  Future<void> _generateServicesCSV(List<QueryDocumentSnapshot> docs) async {
    try {
      final StringBuffer buffer = StringBuffer();
      buffer.writeln(
        'Reserva ID,Fecha,Técnico,Cliente,Dispositivo,Problema,Solución,Repuestos,Método Pago,Estado Pago,Costo',
      );

      // Fetch technicians
      Map<String, String> techNames = {};
      final userDocs = await FirebaseFirestore.instance
          .collection('users')
          .get();
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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Reporte CSV generado correctamente')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Error al exportar CSV: $e')));
    }
  }

  Future<void> _generateServicesExcel(List<QueryDocumentSnapshot> docs) async {
    try {
      final excel = excel_pkg.Excel.createExcel();
      final sheet = excel['Reporte de Servicios'];

      // Fetch technicians
      Map<String, String> techNames = {};
      final userDocs = await FirebaseFirestore.instance
          .collection('users')
          .get();
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
        excel_pkg.TextCellValue('ID Reserva'),
        excel_pkg.TextCellValue('Fecha'),
        excel_pkg.TextCellValue('Técnico'),
        excel_pkg.TextCellValue('Cliente'),
        excel_pkg.TextCellValue('Dispositivo'),
        excel_pkg.TextCellValue('Problema'),
        excel_pkg.TextCellValue('Solución'),
        excel_pkg.TextCellValue('Repuestos'),
        excel_pkg.TextCellValue('Método Pago'),
        excel_pkg.TextCellValue('Estado Pago'),
        excel_pkg.TextCellValue('Costo'),
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
          excel_pkg.TextCellValue(doc.id.substring(0, 8).toUpperCase()),
          excel_pkg.TextCellValue(date),
          excel_pkg.TextCellValue(techName),
          excel_pkg.TextCellValue(data['clientName'] ?? ''),
          excel_pkg.TextCellValue(data['device'] ?? ''),
          excel_pkg.TextCellValue(data['description'] ?? ''),
          excel_pkg.TextCellValue(data['solution'] ?? ''),
          excel_pkg.TextCellValue(data['spareParts'] ?? ''),
          excel_pkg.TextCellValue(payMethod),
          excel_pkg.TextCellValue(isPaid),
          excel_pkg.DoubleCellValue(cost),
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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Reporte Excel generado correctamente')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Error al exportar Excel: $e')));
    }
  }

  Future<void> _generateCatalogPDF() async {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error al generar catálogo: $e')),
        );
      }
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

class _ReportList extends StatelessWidget {
  final String collection;
  final DateTime startDate;
  final DateTime endDate;
  final String title;
  final Function(List<QueryDocumentSnapshot>) builder;

  const _ReportList({
    required this.collection,
    required this.startDate,
    required this.endDate,
    required this.title,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    final startTimestamp = Timestamp.fromDate(startDate);
    final endTimestamp = Timestamp.fromDate(
      endDate.add(const Duration(days: 1)),
    );

    // Determine correct date field based on collection
    final String dateField = collection == 'orders'
        ? 'createdAt'
        : 'scheduledDate';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection(collection)
          .where(dateField, isGreaterThanOrEqualTo: startTimestamp)
          .where(dateField, isLessThanOrEqualTo: endTimestamp)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.search_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text('No se encontraron datos para este rango'),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${docs.length} registros encontrados',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => builder(docs),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Exportar PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final double displayCost = collection == 'orders'
                      ? (data['total'] ?? 0.0).toDouble()
                      : (data['repairCost'] ?? 0.0).toDouble();

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  collection == 'orders'
                                      ? 'PEDIDO #${docs[index].id.substring(0, 6).toUpperCase()}'
                                      : (data['serviceType'] ??
                                                'SERVICIO GENERAL')
                                            .toString()
                                            .toUpperCase(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.indigo,
                                  ),
                                ),
                              ),
                              Text(
                                DateFormat('dd/MM/yyyy').format(
                                  (data[dateField] as Timestamp).toDate(),
                                ),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 18,
                                color: Colors.grey[700],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Cliente: ${data['userName'] ?? data['clientName'] ?? 'Cliente General'}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (collection != 'orders') ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.devices_other,
                                  size: 18,
                                  color: Colors.grey[700],
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Dispositivo: ${data['device'] ?? 'No especificado'}',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 18,
                                  color: Colors.grey[700],
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Trabajo: ${data['description'] ?? 'Revisión técnica'}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                    data['status'],
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _getStatusColor(
                                      data['status'],
                                    ).withOpacity(0.5),
                                  ),
                                ),
                                child: Text(
                                  (data['status'] ?? 'pendiente')
                                      .toString()
                                      .toUpperCase(),
                                  style: TextStyle(
                                    color: _getStatusColor(data['status']),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                '\$${displayCost.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'completado':
      case 'entregado':
        return Colors.green;
      case 'en proceso':
      case 'aprobado':
        return Colors.blue;
      case 'rechazado':
      case 'cancelado':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }
}

class _SalesReportWidget extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final Function(List<QueryDocumentSnapshot>) onExportPDF;
  final Function(List<QueryDocumentSnapshot>) onExportCSV;
  final Function(List<QueryDocumentSnapshot>) onExportExcel;

  const _SalesReportWidget({
    required this.startDate,
    required this.endDate,
    required this.onExportPDF,
    required this.onExportCSV,
    required this.onExportExcel,
  });

  @override
  Widget build(BuildContext context) {
    final startTimestamp = Timestamp.fromDate(startDate);
    final endTimestamp = Timestamp.fromDate(
      endDate.add(const Duration(days: 1)),
    );

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('orders')
          .where('createdAt', isGreaterThanOrEqualTo: startTimestamp)
          .where('createdAt', isLessThanOrEqualTo: endTimestamp)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.search_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text('No se encontraron ventas para este rango'),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;
        double totalSales = 0;
        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          totalSales += (data['total'] ?? 0.0).toDouble();
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${docs.length} ventas encontradas',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Total: \$${totalSales.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _ExportButton(
                          icon: Icons.picture_as_pdf,
                          label: 'PDF',
                          color: Colors.red[700]!,
                          onPressed: () => onExportPDF(docs),
                        ),
                        const SizedBox(width: 10),
                        _ExportButton(
                          icon: Icons.table_chart,
                          label: 'CSV',
                          color: Colors.green[700]!,
                          onPressed: () => onExportCSV(docs),
                        ),
                        const SizedBox(width: 10),
                        _ExportButton(
                          icon: Icons.grid_on,
                          label: 'Excel',
                          color: Colors.blue[700]!,
                          onPressed: () => onExportExcel(docs),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final originalQuote =
                      data['originalQuote'] as Map<String, dynamic>?;
                  final total = (data['total'] ?? 0.0).toDouble();
                  final clientName =
                      originalQuote?['clientName'] ??
                      data['userName'] ??
                      'Desconocido';

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'PEDIDO #${docs[index].id.substring(0, 6).toUpperCase()}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.indigo,
                                ),
                              ),
                              Text(
                                DateFormat('dd/MM/yyyy').format(
                                  (data['createdAt'] as Timestamp).toDate(),
                                ),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 18,
                                color: Colors.grey[700],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Cliente: $clientName',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.payment,
                                size: 18,
                                color: Colors.grey[700],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Pago: ${(data['paymentMethod'] ?? 'N/A').toString().toUpperCase()}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _StatusBadge(status: data['status']),
                              Text(
                                '\$${total.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ServicesReportWidget extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final Function(List<QueryDocumentSnapshot>) onExportPDF;
  final Function(List<QueryDocumentSnapshot>) onExportCSV;
  final Function(List<QueryDocumentSnapshot>) onExportExcel;

  const _ServicesReportWidget({
    required this.startDate,
    required this.endDate,
    required this.onExportPDF,
    required this.onExportCSV,
    required this.onExportExcel,
  });

  @override
  Widget build(BuildContext context) {
    final startTimestamp = Timestamp.fromDate(startDate);
    final endTimestamp = Timestamp.fromDate(
      endDate.add(const Duration(days: 1)),
    );

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reservations')
          .where('scheduledDate', isGreaterThanOrEqualTo: startTimestamp)
          .where('scheduledDate', isLessThanOrEqualTo: endTimestamp)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.search_off, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text('No se encontraron servicios para este rango'),
              ],
            ),
          );
        }

        final docs = snapshot.data!.docs;
        double totalCost = 0;
        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          totalCost += (data['repairCost'] as num?)?.toDouble() ?? 0.0;
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${docs.length} servicios encontrados',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Total: \$${totalCost.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _ExportButton(
                          icon: Icons.picture_as_pdf,
                          label: 'PDF',
                          color: Colors.red[700]!,
                          onPressed: () => onExportPDF(docs),
                        ),
                        const SizedBox(width: 10),
                        _ExportButton(
                          icon: Icons.table_chart,
                          label: 'CSV',
                          color: Colors.green[700]!,
                          onPressed: () => onExportCSV(docs),
                        ),
                        const SizedBox(width: 10),
                        _ExportButton(
                          icon: Icons.grid_on,
                          label: 'Excel',
                          color: Colors.blue[700]!,
                          onPressed: () => onExportExcel(docs),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  final cost = (data['repairCost'] as num?)?.toDouble() ?? 0.0;
                  final clientName =
                      data['clientName'] ?? data['userName'] ?? 'Desconocido';

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'RESERVA #${docs[index].id.substring(0, 6).toUpperCase()}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Colors.indigo,
                                ),
                              ),
                              Text(
                                DateFormat('dd/MM/yyyy').format(
                                  (data['scheduledDate'] as Timestamp).toDate(),
                                ),
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 24),
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 18,
                                color: Colors.grey[700],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Cliente: $clientName',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.payment,
                                size: 18,
                                color: Colors.grey[700],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Pago: ${(data['paymentMethod'] ?? 'N/A').toString().toUpperCase()}',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(
                                Icons.devices,
                                size: 18,
                                color: Colors.grey[700],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Dispositivo: ${data['device'] ?? 'N/A'}',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _StatusBadge(status: data['status']),
                              Text(
                                '\$${cost.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ExportButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ExportButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String? status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status?.toLowerCase()) {
      case 'completado':
      case 'entregado':
        color = Colors.green;
        break;
      case 'en proceso':
      case 'aprobado':
        color = Colors.blue;
        break;
      case 'rechazado':
      case 'cancelado':
        color = Colors.red;
        break;
      default:
        color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        (status ?? 'pendiente').toString().toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
