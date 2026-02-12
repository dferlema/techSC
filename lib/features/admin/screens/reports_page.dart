import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:techsc/core/services/role_service.dart';
import 'package:techsc/core/widgets/cart_badge.dart';
import 'package:techsc/core/providers/providers.dart';
import 'package:techsc/features/admin/services/pdf_report_service.dart';
import 'package:techsc/features/admin/services/export_report_service.dart';
import 'package:techsc/features/admin/widgets/reports/sales_report_widget.dart';
import 'package:techsc/features/admin/widgets/reports/services_report_widget.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  int _selectedIndex = 0;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  final PdfReportService _pdfService = PdfReportService();
  final ExportReportService _exportService = ExportReportService();

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

  Future<void> _handleExport(
    Future<void> Function() exportFunc, {
    String? successMessage,
  }) async {
    try {
      await exportFunc();
      if (successMessage != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Por favor, inicie sesión.')),
      );
    }

    final roleAsync = ref.watch(userRoleProvider(user.uid));

    return roleAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) =>
          Scaffold(body: Center(child: Text('Error al cargar rol: $err'))),
      data: (userRole) {
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
              _buildSalesReport(userRole),
              _buildServicesReport(userRole),
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
      },
    );
  }

  Widget _buildSalesReport(String userRole) {
    if (userRole == RoleService.TECHNICIAN) {
      return const Center(
        child: Text('Acceso Restringido: Solo Admin/Vendedor'),
      );
    }

    return SalesReportWidget(
      startDate: _startDate,
      endDate: _endDate,
      onExportPDF: (docs) => _handleExport(
        () => _pdfService.generateSalesPDF(docs, _startDate, _endDate),
      ),
      onExportCSV: (docs) => _handleExport(
        () => _exportService.generateSalesCSV(docs),
        successMessage: '✅ Reporte CSV generado correctamente',
      ),
      onExportExcel: (docs) => _handleExport(
        () => _exportService.generateSalesExcel(docs),
        successMessage: '✅ Reporte Excel generado correctamente',
      ),
    );
  }

  Widget _buildServicesReport(String userRole) {
    if (userRole == RoleService.SELLER) {
      return const Center(
        child: Text('Acceso Restringido: Solo Admin/Técnico'),
      );
    }

    return ServicesReportWidget(
      startDate: _startDate,
      endDate: _endDate,
      onExportPDF: (docs) => _handleExport(
        () => _pdfService.generateServicesPDF(docs, _startDate, _endDate),
      ),
      onExportCSV: (docs) => _handleExport(
        () => _exportService.generateServicesCSV(docs),
        successMessage: '✅ Reporte CSV generado correctamente',
      ),
      onExportExcel: (docs) => _handleExport(
        () => _exportService.generateServicesExcel(docs),
        successMessage: '✅ Reporte Excel generado correctamente',
      ),
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
              onPressed: () =>
                  _handleExport(() => _pdfService.generateCatalogPDF()),
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
}
