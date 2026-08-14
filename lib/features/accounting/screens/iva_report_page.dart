import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tscomputer/core/theme/app_colors.dart';
import 'package:tscomputer/features/accounting/models/transaction_model.dart';
import 'package:tscomputer/features/accounting/services/financial_report_service.dart';

class IvaReportPage extends StatefulWidget {
  const IvaReportPage({super.key});

  @override
  State<IvaReportPage> createState() => _IvaReportPageState();
}

class _IvaReportPageState extends State<IvaReportPage> {
  final _service = FinancialReportService();
  Map<String, dynamic>? _data;
  List<TransactionModel>? _transactions;
  bool _loading = true;
  DateTime _start = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _end = DateTime.now();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final iva = await _service.getIvaReport(_start, _end);
      if (mounted) setState(() {
        _data = iva;
        _transactions = (iva['transacciones'] as List<TransactionModel>);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: _start, end: _end),
      locale: const Locale('es', 'ES'),
    );
    if (picked != null) {
      _start = picked.start;
      _end = picked.end;
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: const Text('Reporte de IVA'),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.date_range), onPressed: _pickDateRange),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _data == null
              ? const Center(child: Text('Error al cargar'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [Colors.indigo[700]!, Colors.indigo[500]!], begin: Alignment.topLeft, end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Período', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
                              const SizedBox(height: 4),
                              Text('${DateFormat('dd/MM/yy').format(_start)} - ${DateFormat('dd/MM/yy').format(_end)}',
                                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        _ivaCard('IVA VENTAS (Cobrado)', _data!['ivaVentas'] as double, _data!['baseVentas'] as double, _data!['totalVentasConIva'] as double, Colors.green),
                        const SizedBox(height: 12),
                        _ivaCard('IVA COMPRAS (Pagado)', _data!['ivaCompras'] as double, _data!['baseCompras'] as double, _data!['totalComprasConIva'] as double, Colors.red),
                        const Divider(height: 24),
                        _netoCard(_data!['ivaNeto'] as double),
                        const SizedBox(height: 24),
                        if (_transactions != null && _transactions!.isNotEmpty) ...[
                          Text('Transacciones con IVA', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          const SizedBox(height: 8),
                          ...(_transactions!.map((t) => Card(
                            margin: const EdgeInsets.only(bottom: 4),
                            elevation: 0,
                            color: Colors.grey.withValues(alpha: 0.03),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: (t.type == TransactionType.ingreso ? Colors.green : Colors.red).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(t.type == TransactionType.ingreso ? Icons.arrow_upward : Icons.arrow_downward,
                                        size: 16, color: t.type == TransactionType.ingreso ? Colors.green[700] : Colors.red[700]),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(t.description, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                        Text('${DateFormat('dd/MM/yy').format(t.date)}  ·  ${t.category}  ·  IVA \$${t.vatAmount.toStringAsFixed(2)}',
                                            style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                                      ],
                                    ),
                                  ),
                                  Text('\$${t.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                            ),
                          ))),
                        ],
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _ivaCard(String title, double iva, double base, double total, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
          const SizedBox(height: 10),
          _row('Base Imponible', '\$${base.toStringAsFixed(2)}'),
          _row('IVA', '\$${iva.toStringAsFixed(2)}'),
          _row('Total', '\$${total.toStringAsFixed(2)}'),
        ],
      ),
    );
  }

  Widget _netoCard(double neto) {
    final isFavorable = neto <= 0;
    return Card(
      elevation: 0,
      color: (isFavorable ? Colors.green : Colors.red).withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('IVA NETO A ${isFavorable ? "FAVOR" : "PAGAR"}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isFavorable ? Colors.green[800] : Colors.red[800])),
            Text('\$${neto.abs().toStringAsFixed(2)}',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isFavorable ? Colors.green[700] : Colors.red[700])),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        ],
      ),
    );
  }
}
