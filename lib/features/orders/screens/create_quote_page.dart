import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:typed_data';
import 'package:techsc/features/orders/models/quote_model.dart';
import 'package:techsc/core/utils/pdf_helper.dart';
import 'package:printing/printing.dart';
import 'package:techsc/features/orders/providers/quote_providers.dart';
import 'package:techsc/core/providers/providers.dart';
import 'package:techsc/features/catalog/providers/product_providers.dart';
import 'package:techsc/features/catalog/models/product_model.dart';
import 'package:techsc/features/reservations/providers/service_providers.dart';
import 'package:techsc/features/reservations/models/service_model.dart';

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
  bool _applyIVA = true;
  bool _isSaving = false;

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

      for (var item in q.items) {
        _selectedItems.add({
          'id': item.id,
          'name': item.name,
          'type': item.type,
          'price': item.price,
          'quantity': item.quantity,
          'description': item.description,
          'imageUrl': item.imageUrl,
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
      // Check if already exists to increment quantity
      final existingIndex = _selectedItems.indexWhere(
        (i) => i['id'] == item['id'] && i['type'] == item['type'],
      );

      if (existingIndex != -1) {
        _selectedItems[existingIndex]['quantity']++;
      } else {
        _selectedItems.add({
          'id': item['id'],
          'name': item['name'],
          'type': item['type'],
          'price': (item['price'] as num).toDouble(),
          'quantity': 1,
          'description': item['specs'] ?? item['description'] ?? '',
          'imageUrl': item['imageUrl'],
        });
      }
    });
  }

  void _removeItem(int index) {
    setState(() {
      _selectedItems.removeAt(index);
    });
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Agregue al menos un item')));
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
        );
      }).toList();

      final quote = QuoteModel(
        id: widget.existingQuote?.id ?? '', // Use existing ID if editing
        clientId: _clientIdController.text,
        customerUid: _customerUid,
        clientName: _clientNameController.text,
        clientEmail: _clientEmailController.text,
        clientPhone: _clientPhoneController.text,
        creatorId:
            widget.existingQuote?.creatorId ??
            user.uid, // Preserve creator or use current
        items: quoteItems,
        history: widget.existingQuote?.history ?? [],
        createdAt: widget.existingQuote?.createdAt ?? DateTime.now(),
        expirationDate:
            widget.existingQuote?.expirationDate ??
            DateTime.now().add(const Duration(days: 15)),
        status: status,
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error guardando: $e')));
      return null;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveAndShareQuote() async {
    final quote = await _saveQuote(status: 'sent');
    if (quote != null) {
      // Generate PDF
      final Uint8List pdfBytes = await PdfHelper.generateQuotePdf(quote);

      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'Cotizacion_${quote.clientName.replaceAll(' ', '_')}.pdf',
      );

      if (mounted) {
        Navigator.pop(context); // Close page after success?
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cotización guardada y compartida')),
        );
      }
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
              _clientIdController.text =
                  client['id'] ?? ''; // Use ID/RUC instead of Firebase UID
              _clientPhoneController.text = client['phone'] ?? '';
              _clientEmailController.text = client['email'] ?? '';
              _customerUid = client['firebaseUid']; // Correctly capture the UID
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

  // --- UI BUILDERS ---

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva Cotización'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _selectedItems.isEmpty ? null : _generateAndPreviewPDF,
            tooltip: 'Vista Previa PDF',
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isSaving
                ? null
                : () async {
                    final quote = await _saveQuote(status: 'draft');
                    if (quote != null && mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Borrador guardado exitosamente'),
                        ),
                      );
                      Navigator.pop(context);
                    }
                  },
            tooltip: 'Guardar Borrador',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Client Info Section
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Datos del Cliente',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _showClientSelectionSheet,
                          icon: const Icon(Icons.search),
                          label: const Text('Buscar Cliente'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _clientNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre / Razón Social',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _clientIdController,
                            decoration: const InputDecoration(
                              labelText: 'Cédula / RUC',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.badge),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _clientPhoneController,
                            decoration: const InputDecoration(
                              labelText: 'Teléfono',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.phone),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _clientEmailController,
                      decoration: const InputDecoration(
                        labelText: 'Correo Electrónico',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 2. Items Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Detalle de Productos/Servicios',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: _showItemSelectionSheet,
                  icon: const Icon(Icons.add),
                  label: const Text('Agregar Item'),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_selectedItems.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade50,
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.shopping_cart_outlined,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No hay items agregados',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: _selectedItems.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final item = _selectedItems[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: item['type'] == 'product'
                          ? Colors.blue.shade50
                          : Colors.green.shade50,
                      child: Icon(
                        item['type'] == 'product'
                            ? Icons.computer
                            : Icons.build,
                        color: item['type'] == 'product'
                            ? Colors.blue
                            : Colors.green,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      item['name'],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Price: \$${item['price'].toStringAsFixed(2)} | Subtotal: \$${(item['price'] * item['quantity']).toStringAsFixed(2)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => _updateQuantity(index, -1),
                          color: Colors.grey,
                        ),
                        Text(
                          '${item['quantity']}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => _updateQuantity(index, 1),
                          color: Colors.blue,
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _removeItem(index),
                          color: Colors.red,
                        ),
                      ],
                    ),
                  );
                },
              ),

            const SizedBox(height: 24),

            // 3. Totals Section
            Card(
              color: Colors.blue.shade50,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.blue.shade100),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // IVA Checkbox
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Checkbox(
                          value: _applyIVA,
                          onChanged: (val) =>
                              setState(() => _applyIVA = val ?? true),
                        ),
                        const Text('Aplicar IVA (15%)'),
                      ],
                    ),
                    const Divider(),
                    _buildSummaryRow(
                      'Subtotal:',
                      '\$${_subtotal.toStringAsFixed(2)}',
                    ),
                    const SizedBox(height: 8),
                    _buildSummaryRow(
                      'IVA (${_applyIVA ? '15%' : '0%'}):',
                      '\$${_tax.toStringAsFixed(2)}',
                    ),
                    const Divider(height: 24),
                    _buildSummaryRow(
                      'TOTAL:',
                      '\$${_total.toStringAsFixed(2)}',
                      isTotal: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          onPressed: (_selectedItems.isEmpty || _isSaving)
              ? null
              : _saveAndShareQuote,
          icon: _isSaving
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.share),
          label: Text(
            _isSaving ? 'GUARDANDO...' : 'GUARDAR Y COMPARTIR (WhatsApp)',
          ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 18 : 16,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            color: isTotal ? Colors.blue.shade900 : Colors.grey.shade800,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 20 : 16,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            color: isTotal ? Colors.blue.shade900 : Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  // --- PDF GENERATION ---

  Future<void> _generateAndPreviewPDF() async {
    // Convert current state to QuoteModel for the helper
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
          .map(
            (item) => QuoteItem(
              id: item['id'],
              name: item['name'],
              type: item['type'],
              price: item['price'],
              quantity: item['quantity'],
              description: item['specs'] ?? '',
              imageUrl: item['imageUrl'],
            ),
          )
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
}

// --- CLIENT SELECTION SHEET WIDGET ---
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
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const Text(
          'Seleccionar Cliente',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o cédula...',
              prefixIcon: const Icon(Icons.search),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (val) => setState(() => _searchQuery = val),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ref
              .watch(allUsersProvider)
              .when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, stack) => Center(child: Text('Error: $err')),
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
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(user.name),
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

// --- ITEM SELECTION SHEET WIDGET ---

class _ItemSelectionSheet extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  final Function(Map<String, dynamic>) onItemSelected;

  const _ItemSelectionSheet({
    required this.scrollController,
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
        // Header handle
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const Text(
          'Seleccionar Item',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        // Search
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar...',
              prefixIcon: const Icon(Icons.search),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
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
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
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
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
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
            double price;
            String description;
            String? imageUrl;

            if (item is ProductModel) {
              id = item.id;
              name = item.name;
              price = item.price;
              description = item.description;
              imageUrl = item.imageUrl;
            } else {
              final service = item as ServiceModel;
              id = service.id;
              name = service.name;
              price = service.price;
              description = service.description;
              imageUrl = service.imageUrl;
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
              title: Text(name),
              subtitle: Text('\$${price.toStringAsFixed(2)}'),
              trailing: IconButton(
                icon: const Icon(Icons.add_circle, color: Colors.blue),
                onPressed: () => widget.onItemSelected({
                  'id': id,
                  'name': name,
                  'type': isProduct ? 'product' : 'service',
                  'price': price,
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
