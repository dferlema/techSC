import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:tscomputer/core/theme/app_colors.dart';
import 'package:tscomputer/features/receipt/models/receipt_config_model.dart';
import 'package:tscomputer/features/receipt/services/receipt_service.dart';
import 'package:tscomputer/features/receipt/screens/company_settings_page.dart';

class ReceiptPreviewPage extends StatefulWidget {
  final WorkshopReceiptData data;

  const ReceiptPreviewPage({super.key, required this.data});

  @override
  State<ReceiptPreviewPage> createState() => _ReceiptPreviewPageState();
}

class _ReceiptPreviewPageState extends State<ReceiptPreviewPage> {
  final _receiptService = ReceiptService();
  ReceiptFormat _selectedFormat = ReceiptFormat.a4;
  ReceiptConfigModel? _config;
  bool _isLoading = true;
  bool _isGenerating = false;
  final _df = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await _receiptService.loadConfig();
    setState(() {
      _config = config;
      _isLoading = false;
    });
  }

  Future<void> _generateAndPreview() async {
    if (_config == null) return;
    setState(() => _isGenerating = true);
    try {
      final pdfBytes = await _receiptService.generateReceipt(
        config: _config!,
        format: _selectedFormat,
        data: widget.data,
      );
      if (mounted) {
        await Printing.layoutPdf(
          onLayout: (format) => pdfBytes,
          name: 'Recibo ${widget.data.saleNumber}',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _shareReceipt() async {
    if (_config == null) return;
    setState(() => _isGenerating = true);
    try {
      final pdfBytes = await _receiptService.generateReceipt(
        config: _config!,
        format: _selectedFormat,
        data: widget.data,
      );
      await _receiptService.shareReceipt(pdfBytes, widget.data.saleNumber);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vista Previa del Recibo'),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configurar empresa',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CompanySettingsPage()),
              );
              if (result == true) _loadConfig();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildFormatSelector(),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildHeaderCard(d),
                      _buildClientCard(d),
                      _buildEquipmentCard(d),
                      if (d.diagnosis.isNotEmpty) _buildDiagnosisCard(d),
                      _buildItemsCard(d),
                      _buildPaymentCard(d),
                      if (d.warrantyTerms.isNotEmpty) _buildWarrantyCard(d),
                      if (d.additionalNotes != null && d.additionalNotes!.isNotEmpty)
                        _buildNotesCard(d),
                      _buildSignatureSection(),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildFormatSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Formato de Impresión', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[700])),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _formatCard(ReceiptFormat.thermal80mm, 'Térmica 80mm', Icons.receipt_long, 'Tickets')),
              const SizedBox(width: 12),
              Expanded(child: _formatCard(ReceiptFormat.a4, 'Hoja A4', Icons.description, 'Impresora normal')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _formatCard(ReceiptFormat format, String title, IconData icon, String subtitle) {
    final isSelected = _selectedFormat == format;
    return GestureDetector(
      onTap: () => setState(() => _selectedFormat = format),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryBlue.withAlpha(25) : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? AppColors.primaryBlue : Colors.grey[200]!, width: isSelected ? 2 : 1),
        ),
        child: Column(children: [
          Icon(icon, color: isSelected ? AppColors.primaryBlue : Colors.grey[500], size: 32),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? AppColors.primaryBlue : Colors.grey[700])),
          const SizedBox(height: 2),
          Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ]),
      ),
    );
  }

  // ─ Cards de resumen ─

  Widget _buildHeaderCard(WorkshopReceiptData d) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            Icon(Icons.receipt, color: AppColors.primaryBlue),
            const SizedBox(width: 8),
            Text('Orden: ${d.saleNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Spacer(),
            Text(_df.format(d.date), style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          ]),
          if (d.technicianName != null && d.technicianName!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _infoRow('Técnico', d.technicianName!),
          ],
        ]),
      ),
    );
  }

  Widget _buildClientCard(WorkshopReceiptData d) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionHeader(Icons.person, 'Datos del Cliente'),
          const SizedBox(height: 8),
          _infoRow('Nombre', d.clientName),
          if (d.clientId.isNotEmpty) _infoRow('Documento', d.clientId),
          if (d.clientPhone.isNotEmpty) _infoRow('Teléfono', d.clientPhone),
          if (d.clientEmail.isNotEmpty) _infoRow('Email', d.clientEmail),
          if (d.clientAddress.isNotEmpty) _infoRow('Dirección', d.clientAddress),
        ]),
      ),
    );
  }

  Widget _buildEquipmentCard(WorkshopReceiptData d) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionHeader(Icons.devices, 'Equipo'),
          const SizedBox(height: 8),
          if (d.deviceType.isNotEmpty) _infoRow('Tipo', d.deviceType),
          if (d.brand.isNotEmpty || d.model.isNotEmpty)
            _infoRow('Marca/Modelo', '${d.brand} ${d.model}'.trim()),
          if (d.serialNumber.isNotEmpty) _infoRow('Serie/IMEI', d.serialNumber),
          if (d.pin != null && d.pin!.isNotEmpty) _infoRow('PIN', d.pin!),
          if (d.accessories.isNotEmpty) _infoRow('Accesorios', d.accessories),
          if (d.reportedFault.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Falla reportada', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                const SizedBox(height: 4),
                Text(d.reportedFault, style: const TextStyle(fontWeight: FontWeight.w500)),
              ]),
            ),
          ],
          const SizedBox(height: 8),
          _infoRow('Recepción', _df.format(d.receptionDate)),
          if (d.estimatedDeliveryDate != null)
            _infoRow('Entrega Est.', _df.format(d.estimatedDeliveryDate!)),
          if (d.actualDeliveryDate != null)
            _infoRow('Entrega Real', _df.format(d.actualDeliveryDate!)),
        ]),
      ),
    );
  }

  Widget _buildDiagnosisCard(WorkshopReceiptData d) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionHeader(Icons.build, 'Diagnóstico'),
          const SizedBox(height: 8),
          Text(d.diagnosis),
        ]),
      ),
    );
  }

  Widget _buildItemsCard(WorkshopReceiptData d) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionHeader(Icons.list_alt, 'Detalle del Trabajo'),
          const SizedBox(height: 8),
          if (d.services.isNotEmpty) ...[
            Text('Servicios', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700], fontSize: 13)),
            const SizedBox(height: 4),
            ...d.services.map((item) => _itemRow(item)),
            const SizedBox(height: 8),
          ],
          if (d.parts.isNotEmpty) ...[
            Text('Repuestos', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700], fontSize: 13)),
            const SizedBox(height: 4),
            ...d.parts.map((item) => _itemRow(item)),
            const SizedBox(height: 8),
          ],
          const Divider(),
          _totalsRow('Subtotal', d.subtotal),
          if (d.iva > 0) _totalsRow('IVA 15%', d.iva),
          if (d.discount > 0) _totalsRow('Descuento', -d.discount),
          const Divider(),
          _totalsRow('TOTAL', d.total, bold: true),
        ]),
      ),
    );
  }

  Widget _buildPaymentCard(WorkshopReceiptData d) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionHeader(Icons.payment, 'Pago'),
          const SizedBox(height: 8),
          if (d.paymentMethod.isNotEmpty) _infoRow('Método', d.paymentMethod),
          if (d.advance > 0) _infoRow('Abono / Seña', '\$${d.advance.toStringAsFixed(2)}'),
          if (d.pendingBalance > 0) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(8)),
              child: _infoRow('Saldo Pendiente', '\$${d.pendingBalance.toStringAsFixed(2)}'),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _buildWarrantyCard(WorkshopReceiptData d) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionHeader(Icons.verified, 'Garantía'),
          const SizedBox(height: 8),
          Text(d.warrantyTerms),
        ]),
      ),
    );
  }

  Widget _buildNotesCard(WorkshopReceiptData d) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionHeader(Icons.notes, 'Observaciones'),
          const SizedBox(height: 8),
          Text(d.additionalNotes!),
        ]),
      ),
    );
  }

  Widget _buildSignatureSection() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(children: [
                Text('_' * 25, style: TextStyle(color: Colors.grey[400])),
                const SizedBox(height: 4),
                Text('Firma Técnico', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey[700])),
              ]),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(children: [
                Text('_' * 25, style: TextStyle(color: Colors.grey[400])),
                const SizedBox(height: 4),
                Text('Firma Cliente', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey[700])),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  // ─ Helpers ─

  Widget _sectionHeader(IconData icon, String title) {
    return Row(children: [
      Icon(icon, size: 18, color: AppColors.primaryBlue),
      const SizedBox(width: 8),
      Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primaryBlue)),
    ]);
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13))),
        ],
      ),
    );
  }

  Widget _itemRow(ReceiptItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(flex: 3, child: Text(item.description, style: const TextStyle(fontSize: 13))),
        if (item.quantity > 1)
          Expanded(
            child: Text('${item.quantity}x', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          ),
        Expanded(
          flex: 2,
          child: Text(
            '\$${item.total.toStringAsFixed(2)}',
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
          ),
        ),
      ]),
    );
  }

  Widget _totalsRow(String label, double value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: bold ? 14 : 12)),
          Text(
            '\$${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontSize: bold ? 14 : 12,
              color: bold ? AppColors.primaryBlue : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))],
      ),
      child: Row(children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _isGenerating ? null : _shareReceipt,
            icon: const Icon(Icons.share),
            label: const Text('Compartir'),
            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton.icon(
            onPressed: _isGenerating ? null : _generateAndPreview,
            icon: _isGenerating
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.print),
            label: Text(_isGenerating ? 'Generando...' : 'Imprimir'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ]),
    );
  }
}
