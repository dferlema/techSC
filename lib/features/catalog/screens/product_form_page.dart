import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:techsc/core/services/notification_service.dart';
import 'package:techsc/features/catalog/services/supplier_service.dart';
import 'package:techsc/core/services/role_service.dart';
import 'package:techsc/features/catalog/widgets/supplier_link_dialog.dart';
import 'package:techsc/features/catalog/models/category_model.dart';
import 'package:techsc/features/catalog/models/supplier_model.dart';
import 'package:techsc/features/catalog/services/category_service.dart';
import 'package:techsc/features/admin/providers/admin_providers.dart';
import 'package:techsc/l10n/app_localizations.dart';

/// Pagina de formulario para crear o editar productos.
/// Permite ingresar nombre, especificaciones, precio, categoría y URL de imagen.
class ProductFormPage extends ConsumerStatefulWidget {
  final String? productId;
  final Map<String, dynamic>? initialData;

  const ProductFormPage({super.key, this.productId, this.initialData});

  @override
  ConsumerState<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends ConsumerState<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();

  // Controladores para los campos de texto
  late TextEditingController _nameController;
  late TextEditingController _specsController;
  late TextEditingController _priceController;
  late TextEditingController _descriptionController;

  // Guardamos el ID de la categoría seleccionada
  String? _selectedCategoryId;
  // Guardamos el nombre para denormalización (compatibilidad y facilidad de lectura)
  String? _selectedCategoryName;

  String? _selectedLabel;
  String? _selectedTaxStatus;
  late double _rating;
  bool _isFeatured = false;

  // Lista de URLs de imágenes
  List<String> _imageUrls = [];
  final TextEditingController _newImageUrlController = TextEditingController();

  // Supplier fields
  String? _selectedSupplierId;
  String? _selectedSupplierName;
  late TextEditingController _supplierProductLinkController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Inicializar controladores con datos existentes si es edición, o vacíos si es nuevo
    _nameController = TextEditingController(
      text: widget.initialData?['name'] ?? '',
    );
    _specsController = TextEditingController(
      text: widget.initialData?['specs'] ?? '',
    );
    _priceController = TextEditingController(
      text: widget.initialData?['price'] != null
          ? widget.initialData!['price'].toString()
          : '',
    );
    _descriptionController = TextEditingController(
      text: widget.initialData?['description'] ?? '',
    );

    // Cargar vinculación de categoría
    _selectedCategoryId = widget.initialData?['categoryId'];
    _selectedCategoryName = widget.initialData?['category'];

    _selectedLabel = widget.initialData?['label'] ?? 'Ninguna';
    _selectedTaxStatus = widget.initialData?['taxStatus'] ?? 'Incluye impuesto';
    _rating = (widget.initialData?['rating'] as num?)?.toDouble() ?? 4.5;
    _isFeatured = widget.initialData?['isFeatured'] ?? false;

    // Cargar imágenes existentes
    if (widget.initialData?['images'] != null) {
      _imageUrls = List<String>.from(widget.initialData!['images']);
    } else if (widget.initialData?['image'] != null) {
      // Compatibilidad con formato antiguo (una sola imagen)
      _imageUrls = [widget.initialData!['image']];
    }

    // Cargar datos de proveedor
    _selectedSupplierId = widget.initialData?['supplierId'];
    _selectedSupplierName = widget.initialData?['supplierName'];
    _supplierProductLinkController = TextEditingController(
      text: widget.initialData?['supplierProductLink'] ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _specsController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _newImageUrlController.dispose();
    _supplierProductLinkController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct(AppLocalizations l10n) async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageUrls.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.atLeastOneImage)));
      return;
    }

    setState(() => _isSaving = true);

    final name = _nameController.text.trim();
    final specs = _specsController.text.trim();
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final description = _descriptionController.text.trim();

    try {
      final productData = {
        'name': name,
        'specs': specs,
        'price': price,
        'description': description,
        'categoryId': _selectedCategoryId,
        'category': _selectedCategoryName,
        'label': _selectedLabel,
        'taxStatus': _selectedTaxStatus,
        'rating': _rating,
        'isFeatured': _isFeatured,
        'images': _imageUrls,
        'image': _imageUrls.first,
        if (_selectedSupplierId != null) 'supplierId': _selectedSupplierId,
        if (_selectedSupplierName != null)
          'supplierName': _selectedSupplierName,
        if (_supplierProductLinkController.text.trim().isNotEmpty)
          'supplierProductLink': _supplierProductLinkController.text.trim(),
        if (widget.productId == null) 'createdAt': FieldValue.serverTimestamp(),
      };

      final db = FirebaseFirestore.instance;
      String finalProductId;

      if (widget.productId == null) {
        final docRef = await db.collection('products').add(productData);
        finalProductId = docRef.id;
      } else {
        await db
            .collection('products')
            .doc(widget.productId!)
            .update(productData);
        finalProductId = widget.productId!;
      }

      if (_selectedLabel == 'Oferta') {
        await NotificationService().notifyNewOffer(name, price, finalProductId);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${l10n.errorPrefix}: $e')));
    }
  }

  Widget _buildImageGallery(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.productImages,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _newImageUrlController,
                decoration: InputDecoration(
                  hintText: l10n.imageLinkHint,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.link),
                ),
                keyboardType: TextInputType.url,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                final url = _newImageUrlController.text.trim();
                if (url.isNotEmpty) {
                  setState(() {
                    _imageUrls.add(url);
                    _newImageUrlController.clear();
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Icon(Icons.add_photo_alternate),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_imageUrls.isNotEmpty)
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _imageUrls.length,
              itemBuilder: (context, index) {
                return Stack(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                        image: DecorationImage(
                          image: NetworkImage(_imageUrls[index]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 12,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _imageUrls.removeAt(index);
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    if (index == 0)
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            l10n.mainImageLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          )
        else
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey[100],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.image_outlined,
                    size: 40,
                    color: Colors.grey,
                  ),
                  Text(
                    l10n.noImagesAdded,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final userRoleAsync = ref.watch(currentUserRoleProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.productId == null
              ? l10n.productFormTitleNew
              : l10n.productFormTitleEdit,
        ),
        actions: [
          IconButton(
            icon: _isSaving
                ? const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  )
                : const Icon(Icons.check, color: Colors.white),
            onPressed: _isSaving ? null : () => _saveProduct(l10n),
          ),
        ],
      ),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    _buildImageGallery(l10n),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: l10n.productName,
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v!.trim().isEmpty ? l10n.errorPrefix : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _specsController,
                      decoration: InputDecoration(
                        labelText: l10n.productSpecs,
                        border: const OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: l10n.productDescription,
                        border: const OutlineInputBorder(),
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _priceController,
                      decoration: InputDecoration(
                        labelText: l10n.productPrice,
                        prefixText: '\$ ',
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          double.tryParse(v!) == null || double.parse(v) <= 0
                          ? l10n.invalidPrice
                          : null,
                    ),
                    const SizedBox(height: 20),
                    StreamBuilder<List<CategoryModel>>(
                      stream: CategoryService().getCategories(
                        CategoryType.product,
                      ),
                      builder: (context, snapshot) {
                        final categories = snapshot.data ?? [];
                        bool categoryExists = categories.any(
                          (c) => c.id == _selectedCategoryId,
                        );
                        if (!categoryExists && categories.isNotEmpty) {
                          _selectedCategoryId = categories.first.id;
                          _selectedCategoryName = categories.first.name;
                        }

                        return DropdownButtonFormField<String>(
                          initialValue: _selectedCategoryId,
                          decoration: InputDecoration(
                            labelText: l10n.productCategory,
                            border: const OutlineInputBorder(),
                          ),
                          items: categories
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text(c.name.toUpperCase()),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            setState(() {
                              _selectedCategoryId = v;
                              _selectedCategoryName = categories
                                  .firstWhere((c) => c.id == v)
                                  .name;
                            });
                          },
                          validator: (v) => v == null ? l10n.errorPrefix : null,
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedLabel,
                      decoration: InputDecoration(
                        labelText: l10n.productLabel,
                        border: const OutlineInputBorder(),
                      ),
                      items: ['Ninguna', 'Oferta', 'Agotado']
                          .map(
                            (l) => DropdownMenuItem(value: l, child: Text(l)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedLabel = v!),
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedTaxStatus,
                      decoration: InputDecoration(
                        labelText: l10n.taxStatus,
                        border: const OutlineInputBorder(),
                      ),
                      items: ['Incluye impuesto', 'Más impuesto', 'Ninguno']
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedTaxStatus = v!),
                    ),
                    const SizedBox(height: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.ratingLabel,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Slider(
                          value: _rating,
                          min: 1,
                          max: 5,
                          divisions: 8,
                          onChanged: (v) => setState(() => _rating = v),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber),
                            Text(_rating.toStringAsFixed(1)),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SwitchListTile(
                          title: Text(
                            l10n.featuredProduct,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(l10n.featuredProductSubtitle),
                          value: _isFeatured,
                          activeThumbColor: Colors.amber,
                          onChanged: (bool value) =>
                              setState(() => _isFeatured = value),
                        ),
                        const SizedBox(height: 20),
                        userRoleAsync.when(
                          loading: () => const SizedBox(),
                          error: (_, __) => const SizedBox(),
                          data: (role) {
                            if (role != RoleService.ADMIN &&
                                role != RoleService.SELLER) {
                              return const SizedBox();
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Divider(height: 40),
                                Text(
                                  l10n.supplierInfo,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                StreamBuilder<List<SupplierModel>>(
                                  stream: SupplierService().getSuppliers(),
                                  builder: (context, snapshot) {
                                    final suppliers = snapshot.data ?? [];
                                    return DropdownButtonFormField<String>(
                                      initialValue: _selectedSupplierId,
                                      decoration: InputDecoration(
                                        labelText: l10n.supplierInfo,
                                        border: const OutlineInputBorder(),
                                        prefixIcon: const Icon(Icons.business),
                                      ),
                                      items: [
                                        const DropdownMenuItem(
                                          value: null,
                                          child: Text('—'),
                                        ),
                                        ...suppliers.map(
                                          (s) => DropdownMenuItem(
                                            value: s.id,
                                            child: Text(s.name),
                                          ),
                                        ),
                                      ],
                                      onChanged: (v) {
                                        setState(() {
                                          _selectedSupplierId = v;
                                          _selectedSupplierName = v != null
                                              ? suppliers
                                                    .firstWhere(
                                                      (s) => s.id == v,
                                                    )
                                                    .name
                                              : null;
                                        });
                                      },
                                    );
                                  },
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller:
                                            _supplierProductLinkController,
                                        decoration: InputDecoration(
                                          labelText: l10n.supplierLink,
                                          border: const OutlineInputBorder(),
                                          prefixIcon: const Icon(Icons.link),
                                        ),
                                        keyboardType: TextInputType.url,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      height: 56,
                                      child: ElevatedButton(
                                        onPressed: () {
                                          final url =
                                              _supplierProductLinkController
                                                  .text
                                                  .trim();
                                          if (url.isNotEmpty) {
                                            showDialog(
                                              context: context,
                                              builder: (context) =>
                                                  SupplierLinkWebViewDialog(
                                                    url: url,
                                                    supplierName:
                                                        _selectedSupplierName,
                                                  ),
                                            );
                                          } else {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  l10n.enterLinkFirst,
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(Icons.visibility),
                                            Text(
                                              l10n.preview,
                                              style: const TextStyle(
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
