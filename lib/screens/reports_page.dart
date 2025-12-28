import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../services/role_service.dart';
import '../widgets/app_drawer.dart';

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
      drawer: AppDrawer(
        currentRoute: '/reports',
        userName: FirebaseAuth.instance.currentUser?.displayName ?? 'Admin',
      ),
      appBar: AppBar(
        title: const Text('Generación de Reportes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: () => _selectDateRange(context),
            tooltip: 'Filtrar por fecha',
          ),
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

    return _ReportList(
      collection: 'orders',
      startDate: _startDate,
      endDate: _endDate,
      title: 'Reporte de Ventas',
      builder: (docs) => _generateSalesPDF(docs),
    );
  }

  Widget _buildServicesReport() {
    if (_userRole == RoleService.SELLER) {
      return const Center(
        child: Text('Acceso Restringido: Solo Admin/Técnico'),
      );
    }

    return _ReportList(
      collection: 'reservations',
      startDate: _startDate,
      endDate: _endDate,
      title: 'Reporte de Servicios Técnicos',
      builder: (docs) => _generateServicesPDF(docs),
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
    final pdf = pw.Document();
    final dateRange =
        'Del ${DateFormat('dd/MM/yyyy').format(_startDate)} al ${DateFormat('dd/MM/yyyy').format(_endDate)}';

    double totalRecaudado = 0;
    final tableData = <List<String>>[
      ['ID Pedido', 'Fecha', 'Cliente', 'Estado', 'Total'],
      for (var doc in docs) ...[
        () {
          final data = doc.data() as Map<String, dynamic>;
          final total = (data['total'] ?? 0.0).toDouble();
          totalRecaudado += total;
          return [
            doc.id.substring(0, 8).toUpperCase(),
            DateFormat(
              'dd/MM/yy',
            ).format((data['createdAt'] as Timestamp).toDate()),
            (data['userName'] ?? 'Desconocido').toString(),
            (data['status'] ?? 'pendiente').toString().toUpperCase(),
            '\$${total.toStringAsFixed(2)}',
          ];
        }(),
      ],
    ];

    pdf.addPage(
      pw.MultiPage(
        header: (context) => _buildPDFHeader('Reporte de Ventas', dateRange),
        build: (context) => [
          pw.Table.fromTextArray(
            data: tableData,
            border: pw.TableBorder.all(width: 0.5),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
          ),
          pw.SizedBox(height: 20),
          pw.Divider(),
          pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'TOTAL RECAUDADO: \$${totalRecaudado.toStringAsFixed(2)}',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  Future<void> _generateServicesPDF(List<QueryDocumentSnapshot> docs) async {
    final pdf = pw.Document();
    final dateRange =
        'Del ${DateFormat('dd/MM/yyyy').format(_startDate)} al ${DateFormat('dd/MM/yyyy').format(_endDate)}';

    final tableData = <List<String>>[
      ['Fecha', 'Servicio', 'Cliente', 'Dispositivo', 'Estado'],
      for (var doc in docs) ...[
        () {
          final data = doc.data() as Map<String, dynamic>;
          return [
            DateFormat(
              'dd/MM/yy',
            ).format((data['scheduledDate'] as Timestamp).toDate()),
            (data['serviceType'] ?? 'General').toString(),
            (data['clientName'] ?? '—').toString(),
            (data['device'] ?? '—').toString(),
            (data['status'] ?? 'pendiente').toString().toUpperCase(),
          ];
        }(),
      ],
    ];

    pdf.addPage(
      pw.MultiPage(
        header: (context) =>
            _buildPDFHeader('Reporte de Servicios Técnicos', dateRange),
        build: (context) => [
          pw.Table.fromTextArray(
            data: tableData,
            border: pw.TableBorder.all(width: 0.5),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) => pdf.save());
  }

  Future<void> _generateCatalogPDF() async {
    final productsDocs = await FirebaseFirestore.instance
        .collection('products')
        .get();
    final servicesDocs = await FirebaseFirestore.instance
        .collection('services')
        .get();

    final pdf = pw.Document();

    // Group products by category
    Map<String, List<Map<String, dynamic>>> groupedProducts = {};
    for (var doc in productsDocs.docs) {
      final data = doc.data();
      final category = (data['category'] ?? 'General').toString().toUpperCase();
      if (!groupedProducts.containsKey(category)) {
        groupedProducts[category] = [];
      }
      groupedProducts[category]!.add(data);
    }

    pdf.addPage(
      pw.MultiPage(
        header: (context) => _buildPDFHeader(
          'CATÁLOGO DE PRODUCTOS Y SERVICIOS',
          DateFormat('dd/MM/yyyy').format(DateTime.now()),
        ),
        footer: (context) => _buildPDFFooter(),
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
            pw.Header(
              level: 1,
              text: entry.key,
              textStyle: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey700,
              ),
            ),
            pw.Table.fromTextArray(
              data: [
                ['Producto', 'Descripción', 'Precio'],
                for (var p in entry.value)
                  [
                    p['name'] ?? '—',
                    p['specs'] ?? p['description'] ?? '—',
                    '\$${p['price'] ?? 0}',
                  ],
              ],
              border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blue700,
              ),
              cellAlignment: pw.Alignment.centerLeft,
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(5),
                2: const pw.FlexColumnWidth(2),
              },
            ),
            pw.SizedBox(height: 15),
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
                  (doc.data())['title'] ?? '—',
                  (doc.data())['description'] ?? '—',
                  '\$${(doc.data())['price'] ?? 0}',
                ],
            ],
            border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.green700),
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
  }

  pw.Widget _buildPDFFooter() {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Divider(color: PdfColors.grey400),
          pw.Text(
            'Contacto: techservicecomputer@hotmail.com | Tel: 099 109 0805',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
          pw.Text(
            'Ubicación: De los Guabos n47-313, Quito',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            'Generado por TechService Pro',
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

  pw.Widget _buildPDFHeader(String title, String subtitle) {
    return pw.Column(
      children: [
        pw.Center(
          child: pw.Text(
            'TECHSERVICE PRO',
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
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: ListTile(
                      title: Text(
                        collection == 'orders'
                            ? 'Pedido #${docs[index].id.substring(0, 6)}'
                            : (data['serviceType'] ?? 'Servicio'),
                      ),
                      subtitle: Text(
                        DateFormat(
                          'dd/MM/yyyy',
                        ).format((data[dateField] as Timestamp).toDate()),
                      ),
                      trailing: Text(
                        '\$${data['total'] ?? data['price'] ?? '0'}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
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
