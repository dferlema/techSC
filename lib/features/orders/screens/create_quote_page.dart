import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:typed_data';
import 'package:tscomputer/features/orders/models/quote_model.dart';
import 'package:tscomputer/core/utils/pdf_helper.dart';
import 'package:printing/printing.dart';
import 'package:tscomputer/features/orders/providers/quote_providers.dart';
import 'package:tscomputer/core/providers/providers.dart';
import 'package:tscomputer/core/theme/app_colors.dart';
import 'package:tscomputer/features/catalog/providers/product_providers.dart';
import 'package:tscomputer/features/catalog/models/product_model.dart';
import 'package:tscomputer/features/reservations/providers/service_providers.dart';
import 'package:tscomputer/features/reservations/models/service_model.dart';
import 'package:tscomputer/core/widgets/app_loading_indicator.dart';
import 'package:tscomputer/core/widgets/app_error_widget.dart';

/// Formulario de creación/edición de cotizaciones.
///
/// Permite registrar datos del cliente (manual o buscando en usuarios),
/// elegir forma de pago (efectivo/tarjeta, que ajusta los precios activos),
/// agregar productos/servicios del catálogo, aplicar IVA y guardar como
/// borrador o guardar y compartir el PDF por WhatsApp.
///
/// Si se recibe [existingQuote] funciona en modo edición: precarga los datos
/// y al guardar actualiza el documento en lugar de crear uno nuevo.
class CreateQuotePage extends ConsumerStatefulWidget {
  final QuoteModel? existingQuote;
  const CreateQuotePage({super.key, this.existingQuote});

  @override
  ConsumerState<CreateQuotePage> createState() => _CreateQuotePageState();
}

class _CreateQuotePageState extends ConsumerState<CreateQuotePage> {
  // Client Info Controllers
  final _clientNameController = TextEditingController();
  final _clientIdController = TextEditingController();
  final _clientPhoneController = TextEditingController();
  final _clientEmailController = TextEditingController();
  String? _customerUid;

  // Settings
  bool _applyIVA = false;
  bool _isSaving = false;
  String _paymentMethod = 'efectivo';

  // Quote Items
  final List<Map<String, dynamic>> _selectedItems = [];

  @override
  void initState() {
    super.initState();
    if (widget.existingQuote != null) {
      final q = widget.existingQuote!;
      _clientNameController.text = q.clientName;
      _clientIdController.text = q.clientId;
      _clientPhoneController.text = q.clientPhone;
      _clientEmailController.text = q.clientEmail;
      _customerUid = q.customerUid;
      _applyIVA = q.applyTax;
      _paymentMethod = (q.paymentMethod == 'tarjeta') ? 'tarjeta' : 'efectivo';

      for (var item in q.items) {
        _selectedItems.add({
          'id': item.id,
          'name': item.name,
          'type': item.type,
          'price': item.price,
          'quantity': item.quantity,
          'description': item.description,
          'imageUrl': item.imageUrl,
          'cashPrice': item.cashPrice ?? item.price,
          'cardPrice': item.cardPrice ?? item.price,
        });
      }
    }
  }

  double get _subtotal => _selectedItems.fold(
        0,
        (sum, item) => sum + (item['price'] * item['quantity']),
      );

  double get _tax => _applyIVA ? _subtotal * 0.15 : 0.0;
  double get _total => _subtotal + _tax;

  void _onPaymentMethodChanged(String newMethod) {
    if (_paymentMethod == newMethod) return;
    setState(() {
      _paymentMethod = newMethod;
      for (var item in _selectedItems) {
        final cashP =
            (item['cashPrice'] as num?)?.toDouble() ?? (item['price'] as num).toDouble();
        final cardP =
            (item['cardPrice'] as num?)?.toDouble() ?? (item['price'] as num).toDouble();
        item['price'] = newMethod == 'tarjeta' ? cardP : cashP;
      }
    });
  }

  @override
  void dispose() {
    _clientNameController.dispose();
    _clientIdController.dispose();
    _clientPhoneController.dispose();
    _clientEmailController.dispose();
    super.dispose();
  }

  // --- ITEM MANAGEMENT ---

  void _addItem(Map<String, dynamic> item) {
    setState(() {
      final existingIndex = _selectedItems.indexWhere(
        (i) => i['id'] == item['id'] && i['type'] == item['type'],
      );

      final cashP =
          (item['cashPrice'] as num?)?.toDouble() ?? (item['price'] as num).toDouble();
      final cardP =
          (item['cardPrice'] as num?)?.toDouble() ?? (item['price'] as num).toDouble();
      final activePrice = _paymentMethod == 'tarjeta' ? cardP : cashP;

      if (existingIndex != -1) {
        _selectedItems[existingIndex]['quantity']++;
        _selectedItems[existingIndex]['price'] = activePrice;
        _selectedItems[existingIndex]['cashPrice'] = cashP;
        _selectedItems[existingIndex]['cardPrice'] = cardP;
      } else {
        _selectedItems.add({
          'id': item['id'],
          'name': item['name'],
          'type': item['type'],
          'price': activePrice,
          'cashPrice': cashP,
          'cardPrice': cardP,
          'quantity': 1,
          'description': item['specs'] ?? item['description'] ?? '',
          'imageUrl': item['imageUrl'],
        });
      }
    });
  }

  void _removeItem(int index) {
    setState(() => _selectedItems.removeAt(index));
  }

  void _updateQuantity(int index, int delta) {
    setState(() {
      final newQuantity = _selectedItems[index]['quantity'] + delta;
      if (newQuantity > 0) {
        _selectedItems[index]['quantity'] = newQuantity;
      }
    });
  }

  // --- QUOTE ACTIONS ---

  Future<QuoteModel?> _saveQuote({String status = 'draft'}) async {
    if (_selectedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agregue al menos un item')),
      );
      return null;
    }
    if (_clientNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingrese el nombre del cliente')),
      );
      return null;
    }

    setState(() => _isSaving = true);

    try {
      final user = ref.read(authServiceProvider).currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      final quoteItems = _selectedItems.map((item) {
        return QuoteItem(
          id: item['id'] ?? '',
          name: item['name'],
          type: item['type'],
          price: (item['price'] as num).toDouble(),
          quantity: item['quantity'],
          description: item['description'] ?? '',
          imageUrl: item['imageUrl'],
          cashPrice: (item['cashPrice'] as num?)?.toDouble(),
          cardPrice: (item['cardPrice'] as num?)?.toDouble(),
        );
      }).toList();

      final quote = QuoteModel(
        id: widget.existingQuote?.id ?? '',
        clientId: _clientIdController.text,
        customerUid: _customerUid,
        clientName: _clientNameController.text,
        clientEmail: _clientEmailController.text,
        clientPhone: _clientPhoneController.text,
        creatorId: widget.existingQuote?.creatorId ?? user.uid,
        items: quoteItems,
        history: widget.existingQuote?.history ?? [],
        createdAt: widget.existingQuote?.createdAt ?? DateTime.now(),
        expirationDate: widget.existingQuote?.expirationDate ??
            DateTime.now().add(const Duration(days: 15)),
        status: widget.existingQuote != null
            ? widget.existingQuote!.status
            : status,
        paymentMethod: _paymentMethod,
        applyTax: _applyIVA,
      );

      String id;
      final quoteService = ref.read(quoteServiceProvider);
      if (widget.existingQuote != null) {
        id = widget.existingQuote!.id;
        final modificationDesc = 'Modificado por ${user.email ?? user.uid}';
        await quoteService.updateQuote(quote, user.uid, modificationDesc);
      } else {
        id = await quoteService.createQuote(quote);
      }

      return quote.copyWith(id: id);
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error guardando: $e')),
      );
      return null;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveAndShareQuote() async {
    final quote = await _saveQuote(
      status: widget.existingQuote?.status == 'draft'
          ? 'sent'
          : (widget.existingQuote?.status ?? 'sent'),
    );
    if (quote != null) {
      final Uint8List pdfBytes = await PdfHelper.generateQuotePdf(quote);
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'Cotizacion_${quote.clientName.replaceAll(' ', '_')}.pdf',
      );
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cotización guardada y compartida')),
      );
    }
  }

  // --- CLIENT SELECTION ---

  void _showClientSelectionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => _ClientSelectionSheet(
          scrollController: scrollController,
          onClientSelected: (client) {
            setState(() {
              _clientNameController.text = client['name'] ?? '';
              _clientIdController.text = client['id'] ?? '';
              _clientPhoneController.text = client['phone'] ?? '';
              _clientEmailController.text = client['email'] ?? '';
              _customerUid = client['firebaseUid'];
            });
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cliente seleccionado')),
            );
          },
        ),
      ),
    );
  }

  // --- ITEM SELECTION ---

  void _showItemSelectionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => _ItemSelectionSheet(
          scrollController: scrollController,
          paymentMethod: _paymentMethod,
          onItemSelected: (item) {
            _addItem(item);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Agregado: ${item['name']}')),
            );
          },
        ),
      ),
    );
  }

  // --- PDF GENERATION ---

  Future<void> _generateAndPreviewPDF() async {
    final quote = QuoteModel(
      id: 'TEMP',
      clientId: _clientIdController.text,
      clientName: _clientNameController.text.isEmpty
          ? 'Consumidor Final'
          : _clientNameController.text,
      clientEmail: _clientEmailController.text,
      clientPhone: _clientPhoneController.text,
      creatorId: ref.read(authServiceProvider).currentUser?.uid ?? 'unknown',
      items: _selectedItems
          .map((item) => QuoteItem(
                id: item['id'],
                name: item['name'],
                type: item['type'],
                price: item['price'],
                quantity: item['quantity'],
                description: item['specs'] ?? '',
                imageUrl: item['imageUrl'],
              ))
          .toList(),
      history: [],
      createdAt: DateTime.now(),
      applyTax: _applyIVA,
      taxRate: 0.15,
    );

    final bytes = await PdfHelper.generateQuotePdf(quote);
    await Printing.layoutPdf(
      onLayout: (format) => Future.value(bytes),
      name: 'Cotizacion_${quote.clientName.replaceAll(' ', '_')}.pdf',
    );
  }

  // ──────────────────────────────────────────────────────────
  //  BUILD
  // ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundGray,
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.description_outlined,
              color: Theme.of(context).colorScheme.onPrimary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              widget.existingQuote != null
                  ? 'Editar Cotización'
                  : 'Nueva Cotización',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.picture_as_pdf),
          onPressed:
              _selectedItems.isEmpty ? null : _generateAndPreviewPDF,
          tooltip: 'Vista Previa PDF',
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.save, size: 20),
            onPressed: _isSaving
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final nav = Navigator.of(context);
                    final quote = await _saveQuote(status: 'draft');
                    if (quote != null && mounted) {
                      messenger.showSnackBar(
                        const SnackBar(
                            content: Text('Borrador guardado exitosamente')),
                      );
                      nav.pop();
                    }
                  },
            tooltip: 'Guardar Borrador',
          ),
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  // Layout único y responsive: una sola columna centrada con ancho máximo.

  Widget _buildBody() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Center(
        heightFactor: 1.0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildClientInfoCard(),
              const SizedBox(height: 16),
              _buildPaymentMethodCard(),
              const SizedBox(height: 16),
              _buildItemsSection(),
              const SizedBox(height: 16),
              _buildTotalsCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(
      IconData icon, Color color, String title, {Widget? action}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title,
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold)),
        ),
        if (action != null) ...[
          const SizedBox(width: 8),
          action,
        ],
      ],
    );
  }

  Widget _sectionCard({Widget? header, required Widget child}) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (header != null) header,
            if (header != null) const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }

  // ── Section: Client Info ──

  Widget _buildClientInfoCard() {
    return _sectionCard(
      header: _sectionHeader(
        Icons.person,
        AppColors.primaryBlue,
        'Datos del Cliente',
        action: TextButton.icon(
          onPressed: _showClientSelectionSheet,
          icon: const Icon(Icons.search, size: 18),
          label: const Text('Buscar'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primaryBlue,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _clientNameController,
            decoration: InputDecoration(
              labelText: 'Nombre / Razón Social',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              prefixIcon: const Icon(Icons.person, size: 20),
            ),
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 500) {
                return Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _clientIdController,
                        decoration: InputDecoration(
                          labelText: 'Cédula / RUC',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          prefixIcon: const Icon(Icons.badge, size: 20),
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _clientPhoneController,
                        decoration: InputDecoration(
                          labelText: 'Teléfono',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10)),
                          prefixIcon: const Icon(Icons.phone, size: 20),
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                );
              }
              return Column(
                children: [
                  TextFormField(
                    controller: _clientIdController,
                    decoration: InputDecoration(
                      labelText: 'Cédula / RUC',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.badge, size: 20),
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _clientPhoneController,
                    decoration: InputDecoration(
                      labelText: 'Teléfono',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.phone, size: 20),
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _clientEmailController,
            decoration: InputDecoration(
              labelText: 'Correo Electrónico',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              prefixIcon: const Icon(Icons.email, size: 20),
            ),
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ── Section: Payment Method ──

  Widget _buildPaymentMethodCard() {
    return _sectionCard(
      header: _sectionHeader(
        Icons.payment,
        Colors.orange,
        'Forma de Pago',
      ),
      child: Row(
        children: [
          Expanded(
            child: _paymentOption('efectivo', Icons.payments, 'Efectivo'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _paymentOption('tarjeta', Icons.credit_card, 'Tarjeta'),
          ),
        ],
      ),
    );
  }

  Widget _paymentOption(String value, IconData icon, String label) {
    final selected = _paymentMethod == value;
    return GestureDetector(
      onTap: () => _onPaymentMethodChanged(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primaryBlue.withValues(alpha: 0.10)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primaryBlue : Colors.grey.shade300,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color: selected ? AppColors.primaryBlue : Colors.grey.shade600),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected
                      ? AppColors.primaryBlue
                      : Colors.grey.shade700,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section: Items ──

  Widget _buildItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader(
          Icons.shopping_cart_outlined,
          Colors.blue,
          'Items',
          action: ElevatedButton.icon(
            onPressed: _showItemSelectionSheet,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Agregar'),
            style: ElevatedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_selectedItems.isEmpty)
          _buildEmptyItemsPlaceholder()
        else
          Card(
            elevation: 0,
            color: Colors.white,
            shadowColor: Colors.black.withValues(alpha: 0.06),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Column(
                children: [
                  for (int i = 0; i < _selectedItems.length; i++) ...[
                    _buildItemTile(i),
                    if (i < _selectedItems.length - 1)
                      const Divider(height: 1),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildItemTile(int index) {
    final item = _selectedItems[index];
    final isProduct = item['type'] == 'product';
    final qty = item['quantity'] as int;
    final price = (item['price'] as num).toDouble();
    final total = price * qty;
    final hasPrices = item['cashPrice'] != null && item['cardPrice'] != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade100,
                  image: item['imageUrl'] != null &&
                          (item['imageUrl'] as String).isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(item['imageUrl']),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: (item['imageUrl'] == null ||
                        (item['imageUrl'] as String).isEmpty)
                    ? Icon(isProduct ? Icons.computer : Icons.build,
                        size: 18, color: Colors.grey[400])
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['name'] ?? 'Sin nombre',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '\$${price.toStringAsFixed(2)} c/u',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '\$${total.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _qtyBtn(Icons.remove, () => _updateQuantity(index, -1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('$qty',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
              ),
              _qtyBtn(Icons.add, () => _updateQuantity(index, 1)),
              const Spacer(),
              if (hasPrices)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Tooltip(
                    message: isProduct
                        ? 'Efectivo: \$${(item['cashPrice'] as num).toStringAsFixed(2)}\nTarjeta: \$${(item['cardPrice'] as num).toStringAsFixed(2)}'
                        : 'Precio: \$${price.toStringAsFixed(2)}',
                    child: const Icon(Icons.info_outline,
                        size: 14, color: Colors.grey),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: Colors.red),
                onPressed: () => _removeItem(index),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                splashRadius: 16,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300, width: 0.5),
        ),
        child: Icon(icon, size: 15, color: Colors.grey[600]),
      ),
    );
  }

  Widget _buildEmptyItemsPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
        borderRadius: BorderRadius.circular(14),
        color: Colors.grey.shade50,
      ),
      child: Column(
        children: [
          Icon(Icons.shopping_cart_outlined,
              size: 48, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text('No hay items agregados',
              style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 4),
          Text('Toca "Agregar" para añadir productos o servicios',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 12)),
        ],
      ),
    );
  }

  // ── Section: Totals ──

  Widget _buildTotalsCard() {
    return _sectionCard(
      header: _sectionHeader(
        Icons.account_balance_wallet,
        Colors.blue,
        'Resumen',
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Checkbox(
                value: _applyIVA,
                onChanged: (val) =>
                    setState(() => _applyIVA = val ?? true),
                activeColor: AppColors.primaryBlue,
                side: BorderSide(color: Colors.grey.shade400),
              ),
              Flexible(
                child: Text('Aplicar IVA (15%)',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.grey[700], fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildSummaryRow('Subtotal:', '\$${_subtotal.toStringAsFixed(2)}'),
          const SizedBox(height: 8),
          _buildSummaryRow(
              'IVA (${_applyIVA ? '15%' : '0%'}):',
              '\$${_tax.toStringAsFixed(2)}'),
          const Divider(height: 24),
          _buildSummaryRow('TOTAL:', '\$${_total.toStringAsFixed(2)}',
              isTotal: true),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(label,
              style: TextStyle(
                  fontSize: isTotal ? 16 : 14,
                  fontWeight:
                      isTotal ? FontWeight.bold : FontWeight.w500,
                  color: isTotal
                      ? AppColors.primaryBlue
                      : Colors.grey[700]),
              overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 8),
        Text(value,
            style: TextStyle(
                fontSize: isTotal ? 20 : 15,
                fontWeight:
                    isTotal ? FontWeight.bold : FontWeight.w500,
                color: isTotal
                    ? AppColors.primaryBlue
                    : Colors.grey[700])),
      ],
    );
  }

  // ── Bottom Bar (Save & Share) ──

  Widget _buildBottomBar() {
    final canSave = _selectedItems.isNotEmpty && !_isSaving;

    return Container(
      color: AppColors.backgroundGray,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Center(
            heightFactor: 1.0,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: canSave ? _saveAndShareQuote : null,
                  icon: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.share, size: 18),
                  label: const Text(
                    'Guardar y Compartir (WhatsApp)',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade600,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────
//  CLIENT SELECTION SHEET
// ────────────────────────────────────────────

class _ClientSelectionSheet extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  final Function(Map<String, dynamic>) onClientSelected;

  const _ClientSelectionSheet({
    required this.scrollController,
    required this.onClientSelected,
  });

  @override
  ConsumerState<_ClientSelectionSheet> createState() =>
      _ClientSelectionSheetState();
}

class _ClientSelectionSheetState extends ConsumerState<_ClientSelectionSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Drag handle
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const Text('Seleccionar Cliente',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o cédula...',
              prefixIcon: const Icon(Icons.search),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ref.watch(allUsersProvider).when(
                loading: () => const AppLoadingIndicator(),
                error: (err, _) => AppErrorWidget(error: err),
                data: (users) {
                  final filtered = users.where((user) {
                    final name = user.name.toLowerCase();
                    final id = user.id.toLowerCase();
                    final query = _searchQuery.toLowerCase();
                    return name.contains(query) || id.contains(query);
                  }).toList();

                  if (filtered.isEmpty) {
                    return const Center(
                      child: Text('No se encontraron clientes.'),
                    );
                  }

                  return ListView.builder(
                    controller: widget.scrollController,
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final user = filtered[index];
                      return ListTile(
                        leading: const CircleAvatar(
                            child: Icon(Icons.person)),
                        title: Text(user.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('Cédula: ${user.id}'),
                        onTap: () {
                          final clientData = {
                            'name': user.name,
                            'id': user.id,
                            'phone': user.phone,
                            'email': user.email,
                            'firebaseUid': user.uid,
                          };
                          widget.onClientSelected(clientData);
                        },
                      );
                    },
                  );
                },
              ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────
//  ITEM SELECTION SHEET
// ────────────────────────────────────────────

class _ItemSelectionSheet extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  final String paymentMethod;
  final Function(Map<String, dynamic>) onItemSelected;

  const _ItemSelectionSheet({
    required this.scrollController,
    this.paymentMethod = 'efectivo',
    required this.onItemSelected,
  });

  @override
  ConsumerState<_ItemSelectionSheet> createState() =>
      _ItemSelectionSheetState();
}

class _ItemSelectionSheetState extends ConsumerState<_ItemSelectionSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(productSearchQueryProvider.notifier).state = '';
      ref.read(serviceSearchQueryProvider.notifier).state = '';
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Drag handle
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const Text('Seleccionar Item',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        // Search
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar...',
              prefixIcon: const Icon(Icons.search),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (val) {
              ref.read(productSearchQueryProvider.notifier).state = val;
              ref.read(serviceSearchQueryProvider.notifier).state = val;
            },
          ),
        ),
        const SizedBox(height: 12),
        // Tabs
        TabBar(
          controller: _tabController,
          labelColor: AppColors.primaryBlue,
          unselectedLabelColor: Colors.grey,
          indicator: BoxDecoration(
            color: AppColors.primaryBlue.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
          ),
          dividerHeight: 0,
          labelPadding: const EdgeInsets.symmetric(vertical: 8),
          tabs: const [
            Tab(text: 'Productos', icon: Icon(Icons.computer)),
            Tab(text: 'Servicios', icon: Icon(Icons.build)),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [_buildList('products'), _buildList('services')],
          ),
        ),
      ],
    );
  }

  Widget _buildList(String collection) {
    final isProduct = collection == 'products';
    final asyncItems = isProduct
        ? ref.watch(filteredProductsProvider(''))
        : ref.watch(filteredServicesProvider(null));

    return asyncItems.when(
      loading: () => const AppLoadingIndicator(),
      error: (err, _) => AppErrorWidget(error: err),
      data: (items) {
        if (items.isEmpty) {
          return const Center(child: Text('No se encontraron items.'));
        }

        return ListView.builder(
          controller: widget.scrollController,
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            String id;
            String name;
            double activePrice;
            double cashPrice;
            double cardPrice;
            String description;
            String? imageUrl;

            if (item is ProductModel) {
              id = item.id;
              name = item.name;
              description = item.description;
              imageUrl = item.imageUrl;
              cashPrice = (item.cardPrice != null && item.cardPrice! > 0)
                  ? item.cardPrice!
                  : item.price;
              cardPrice = item.price;
              activePrice =
                  widget.paymentMethod == 'tarjeta' ? cardPrice : cashPrice;
            } else {
              final service = item as ServiceModel;
              id = service.id;
              name = service.name.isNotEmpty
                  ? service.name
                  : service.description;
              if (name.isEmpty) name = 'Servicio sin nombre';
              description = service.description;
              imageUrl = service.imageUrl;
              cashPrice = service.price;
              cardPrice = service.price;
              activePrice = service.price;
            }

            return ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  image: imageUrl != null && imageUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(imageUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: (imageUrl == null || imageUrl.isEmpty)
                    ? Icon(isProduct ? Icons.computer : Icons.build)
                    : null,
              ),
              title: Text(name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                isProduct
                    ? (widget.paymentMethod == 'tarjeta'
                        ? '\$${activePrice.toStringAsFixed(2)} (Tarjeta)'
                        : '\$${activePrice.toStringAsFixed(2)} (Efectivo)')
                    : '\$${activePrice.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.blue),
                onPressed: () => widget.onItemSelected({
                  'id': id,
                  'name': name,
                  'type': isProduct ? 'product' : 'service',
                  'price': activePrice,
                  'cashPrice': cashPrice,
                  'cardPrice': cardPrice,
                  'specs': description,
                  'imageUrl': imageUrl,
                }),
              ),
            );
          },
        );
      },
    );
  }
}