import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:techsc/core/services/notification_service.dart';
import 'package:techsc/features/catalog/services/supplier_service.dart';
import 'package:techsc/core/services/role_service.dart';
import 'package:techsc/core/theme/app_colors.dart';
import 'package:techsc/features/catalog/widgets/supplier_link_dialog.dart';
import 'package:techsc/features/catalog/models/category_model.dart';
import 'package:techsc/features/catalog/models/supplier_model.dart';
import 'package:techsc/features/catalog/services/category_service.dart';
import 'package:techsc/features/admin/providers/admin_providers.dart';
import 'package:techsc/l10n/app_localizations.dart';
import 'package:techsc/core/services/config_service.dart';
import 'package:techsc/features/admin/models/profit_range_model.dart';
import 'package:techsc/core/widgets/app_loading_indicator.dart';
import 'dart:async';

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

  // Pricing controllers
  late TextEditingController _costWithoutIvaController;
  late TextEditingController _costWithIvaController;
  late TextEditingController _cardPriceController;
  late TextEditingController _profitMarginController;
  late TextEditingController _fixedProfitController;

  bool _isAutoPriceEnabled = true;
  bool _useFixedProfit = false;
  List<ProfitRange> _profitRanges = [];
  double _vatPercentage = 15.0;
  StreamSubscription? _profitRangesSub;
  StreamSubscription? _configSub;

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

    _costWithoutIvaController = TextEditingController(
      text: widget.initialData?['purchaseCost']?.toString() ?? '',
    );
    _costWithIvaController = TextEditingController(
      text: widget.initialData?['purchaseCostWithTax']?.toString() ?? '',
    );
    _profitMarginController = TextEditingController(
      text: widget.initialData?['profitMargin']?.toString() ?? '',
    );
    _cardPriceController = TextEditingController(
      text: widget.initialData?['cardPrice']?.toString() ?? '',
    );
    _fixedProfitController = TextEditingController(
      text: widget.initialData?['fixedProfit']?.toString() ?? '',
    );

    _isAutoPriceEnabled = widget.productId == null;
    _useFixedProfit = widget.initialData?['useFixedProfit'] ?? false;

    // Listeners for auto-calculation
    _costWithoutIvaController.addListener(_onCostChanged);

    // Initial load of profit ranges
    _profitRangesSub = ConfigService().getProfitRangesStream().listen((ranges) {
      setState(() => _profitRanges = ranges);
      if (_isAutoPriceEnabled) _calculatePrices();
    });

    _configSub = ConfigService().getConfigStream().listen((config) {
      setState(() => _vatPercentage = config.vatPercentage);
      if (_isAutoPriceEnabled) _calculatePrices();
    });
  }

  void _onCostChanged() {
    if (!_isAutoPriceEnabled) return;
    _calculatePrices();
  }

  void _onProfitChanged({
    bool isMarginChange = false,
    bool isFixedChange = false,
  }) {
    if (!_isAutoPriceEnabled) return;
    _calculatePrices(
      isMarginChange: isMarginChange,
      isFixedChange: isFixedChange,
    );
  }

  void _calculatePrices({
    bool isMarginChange = false,
    bool isFixedChange = false,
  }) {
    final costWithoutIva = double.tryParse(_costWithoutIvaController.text) ?? 0;
    if (costWithoutIva <= 0) return;

    final costWithIva = costWithoutIva * (1 + (_vatPercentage / 100));
    _costWithIvaController.text = costWithIva.toStringAsFixed(2);

    double margin = 0;
    double fixedProfit = 0;

    if (_useFixedProfit) {
      // Modo Ganancia Fija: El usuario ingresa $ y calculamos %
      fixedProfit = double.tryParse(_fixedProfitController.text) ?? 0;
      if (costWithIva > 0) {
        margin = (fixedProfit / costWithIva) * 100;
        _profitMarginController.text = margin.toStringAsFixed(1);
      }
    } else {
      // Modo Porcentaje:
      if (isMarginChange) {
        // Si el usuario cambió manualmente el %, calculamos el $
        margin = double.tryParse(_profitMarginController.text) ?? 0;
        fixedProfit = (costWithIva * margin) / 100;
        _fixedProfitController.text = fixedProfit.toStringAsFixed(2);
      } else {
        // Si no es un cambio manual de %, usamos los rangos automáticos
        bool found = false;
        for (final range in _profitRanges) {
          if (costWithIva >= range.minPrice && costWithIva <= range.maxPrice) {
            margin = range.profitPercentage;
            found = true;
            break;
          }
        }

        if (found) {
          _profitMarginController.text = margin.toStringAsFixed(1);
        } else {
          margin = double.tryParse(_profitMarginController.text) ?? 0;
        }

        fixedProfit = (costWithIva * margin) / 100;
        _fixedProfitController.text = fixedProfit.toStringAsFixed(2);
      }
    }

    final pvp = costWithIva + fixedProfit;
    // El precio principal es el de tarjeta (incluye comisión 6%)
    final cardPrice = pvp / (1 - 0.06);

    _priceController.text = cardPrice.toStringAsFixed(2);
    _cardPriceController.text = pvp.toStringAsFixed(2); // Cash price

    // Necesario para que los widgets que no son controllers se actualicen (ej. PVP y Efectivo)
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _specsController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _newImageUrlController.dispose();
    _supplierProductLinkController.dispose();
    _costWithoutIvaController.dispose();
    _costWithIvaController.dispose();
    _profitMarginController.dispose();
    _cardPriceController.dispose();
    _fixedProfitController.dispose();
    _profitRangesSub?.cancel();
    _configSub?.cancel();
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
        'purchaseCost': double.tryParse(_costWithoutIvaController.text) ?? 0.0,
        'purchaseCostWithTax':
            double.tryParse(_costWithIvaController.text) ?? 0.0,
        'profitMargin': double.tryParse(_profitMarginController.text) ?? 0.0,
        'fixedProfit': double.tryParse(_fixedProfitController.text) ?? 0.0,
        'useFixedProfit': _useFixedProfit,
        'cardPrice': double.tryParse(_cardPriceController.text) ?? 0.0,
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

  Widget _buildCard({
    required List<Widget> children,
    Color? color,
    EdgeInsets? padding,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildInfoItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.nearBlack,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeaderCard(
    String title,
    IconData icon,
    List<Color> colors,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGalleryCard(AppLocalizations l10n) {
    return _buildCard(
      padding: EdgeInsets.zero,
      children: [
        _buildSectionHeaderCard('Imágenes del Producto', Icons.image_outlined, [
          AppColors.primaryBlue,
          AppColors.accentBlue,
        ]),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _newImageUrlController,
                      decoration: InputDecoration(
                        hintText: l10n.imageLinkHint,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.link),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primaryBlue, AppColors.accentBlue],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: () {
                        final url = _newImageUrlController.text.trim();
                        if (url.isNotEmpty) {
                          setState(() {
                            _imageUrls.add(url);
                            _newImageUrlController.clear();
                          });
                        }
                      },
                      icon: const Icon(
                        Icons.add_photo_alternate,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (_imageUrls.isNotEmpty)
                SizedBox(
                  height: 140,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _imageUrls.length,
                    itemBuilder: (context, index) {
                      return Container(
                        margin: const EdgeInsets.only(right: 12),
                        width: 130,
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.grey.withOpacity(0.2),
                                ),
                                image: DecorationImage(
                                  image: NetworkImage(_imageUrls[index]),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _imageUrls.removeAt(index)),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                            if (index == 0)
                              Positioned(
                                bottom: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryBlue,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Principal',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                )
              else
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.1),
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        size: 32,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.noImagesAdded,
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGeneralInfoCard(AppLocalizations l10n) {
    return _buildCard(
      padding: EdgeInsets.zero,
      children: [
        _buildSectionHeaderCard('Información Básica', Icons.info_outline, [
          AppColors.roleClient,
          AppColors.success,
        ]),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.productName,
                  prefixIcon: const Icon(Icons.shopping_bag_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) => v!.trim().isEmpty ? l10n.errorPrefix : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _specsController,
                decoration: InputDecoration(
                  labelText: l10n.productSpecs,
                  prefixIcon: const Icon(Icons.list_alt_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: l10n.productDescription,
                  prefixIcon: const Icon(Icons.description_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPricingCard(AppLocalizations l10n) {
    return _buildCard(
      padding: EdgeInsets.zero,
      children: [
        _buildSectionHeaderCard(
          'Dashboard de Precios',
          Icons.analytics_outlined,
          [AppColors.goldAccent, AppColors.warning],
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Método de Cálculo',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.nearBlack,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        'Manual',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Switch(
                        value: _isAutoPriceEnabled,
                        onChanged: (v) {
                          setState(() {
                            _isAutoPriceEnabled = v;
                            if (v) _calculatePrices();
                          });
                        },
                        activeColor: AppColors.goldAccent,
                      ),
                      Text(
                        'Auto',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.goldAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('% Ganancia')),
                        selected: !_useFixedProfit,
                        selectedColor: AppColors.primaryBlue,
                        labelStyle: TextStyle(
                          color: !_useFixedProfit
                              ? Colors.white
                              : AppColors.textPrimary,
                          fontSize: 12,
                        ),
                        onSelected: (selected) {
                          if (selected)
                            setState(() {
                              _useFixedProfit = false;
                              _calculatePrices();
                            });
                        },
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: ChoiceChip(
                        label: const Center(child: Text('\$ Ganancia Fija')),
                        selected: _useFixedProfit,
                        selectedColor: AppColors.primaryBlue,
                        labelStyle: TextStyle(
                          color: _useFixedProfit
                              ? Colors.white
                              : AppColors.textPrimary,
                          fontSize: 12,
                        ),
                        onSelected: (selected) {
                          if (selected)
                            setState(() {
                              _useFixedProfit = true;
                              _calculatePrices();
                            });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _costWithoutIvaController,
                      decoration: InputDecoration(
                        labelText: 'Costo (sin IVA)',
                        prefixText: '\$ ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _costWithIvaController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Costo (con IVA)',
                        prefixText: '\$ ',
                        filled: true,
                        fillColor: Colors.grey[50],
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _profitMarginController,
                      readOnly: _isAutoPriceEnabled && _useFixedProfit,
                      onChanged: (v) => _onProfitChanged(isMarginChange: true),
                      decoration: InputDecoration(
                        labelText: 'Ganancia (%)',
                        prefixText: '% ',
                        filled: _isAutoPriceEnabled && _useFixedProfit,
                        fillColor: (_isAutoPriceEnabled && _useFixedProfit)
                            ? Colors.grey[100]
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _fixedProfitController,
                      readOnly: _isAutoPriceEnabled && !_useFixedProfit,
                      onChanged: (v) => _onProfitChanged(isFixedChange: true),
                      decoration: InputDecoration(
                        labelText: 'Ganancia (\$)',
                        prefixText: '\$ ',
                        filled: _isAutoPriceEnabled && !_useFixedProfit,
                        fillColor: (_isAutoPriceEnabled && !_useFixedProfit)
                            ? Colors.grey[100]
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              _buildInfoItem(
                'PVP FINAL (TARJETA)',
                '\$ ${_priceController.text}',
                Icons.credit_card,
                AppColors.accentBlue,
              ),
              const SizedBox(height: 12),
              _buildInfoItem(
                'PRECIO EFECTIVO',
                '\$ ${_cardPriceController.text}',
                Icons.payments_outlined,
                AppColors.success,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsCard(AppLocalizations l10n) {
    return _buildCard(
      padding: EdgeInsets.zero,
      children: [
        _buildSectionHeaderCard(
          'Clasificación y Atributos',
          Icons.settings_outlined,
          [AppColors.primaryBlue, AppColors.roleTechnician],
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              StreamBuilder<List<CategoryModel>>(
                stream: CategoryService().getCategories(CategoryType.product),
                builder: (context, snapshot) {
                  final categories = snapshot.data ?? [];
                  return DropdownButtonFormField<String>(
                    initialValue: _selectedCategoryId,
                    decoration: InputDecoration(
                      labelText: l10n.productCategory,
                      prefixIcon: const Icon(Icons.category_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                  );
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedLabel,
                decoration: InputDecoration(
                  labelText: l10n.productLabel,
                  prefixIcon: const Icon(Icons.label_important_outline),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: ['Ninguna', 'Oferta', 'Agotado']
                    .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedLabel = v!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedTaxStatus,
                decoration: InputDecoration(
                  labelText: l10n.taxStatus,
                  prefixIcon: const Icon(Icons.receipt_long_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: ['Incluye impuesto', 'Más impuesto', 'Ninguno']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedTaxStatus = v!),
              ),
              const SizedBox(height: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'Calificación Inicial',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.nearBlack,
                      ),
                    ),
                  ),
                  Slider(
                    value: _rating,
                    min: 1,
                    max: 5,
                    activeColor: AppColors.goldAccent,
                    divisions: 8,
                    onChanged: (v) => setState(() => _rating = v),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                title: const Text(
                  'Producto Destacado',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Mostrar en la sección principal'),
                value: _isFeatured,
                activeColor: AppColors.goldAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                tileColor: Colors.grey[50],
                onChanged: (bool value) => setState(() => _isFeatured = value),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSupplierCard(AppLocalizations l10n, String role) {
    if (role != RoleService.ADMIN && role != RoleService.SELLER) {
      return const SizedBox.shrink();
    }
    return _buildCard(
      padding: EdgeInsets.zero,
      children: [
        _buildSectionHeaderCard(
          'Información de Proveedor',
          Icons.business_outlined,
          [AppColors.primaryDark, AppColors.primaryBlue],
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              StreamBuilder<List<SupplierModel>>(
                stream: SupplierService().getSuppliers(),
                builder: (context, snapshot) {
                  final suppliers = snapshot.data ?? [];
                  return DropdownButtonFormField<String>(
                    initialValue: _selectedSupplierId,
                    decoration: InputDecoration(
                      labelText: l10n.supplierInfo,
                      prefixIcon: const Icon(Icons.business),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('—')),
                      ...suppliers.map(
                        (s) =>
                            DropdownMenuItem(value: s.id, child: Text(s.name)),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _selectedSupplierId = v;
                        _selectedSupplierName = v != null
                            ? suppliers.firstWhere((s) => s.id == v).name
                            : null;
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _supplierProductLinkController,
                      decoration: InputDecoration(
                        labelText: l10n.supplierLink,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.link),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        final url = _supplierProductLinkController.text.trim();
                        if (url.isNotEmpty) {
                          showDialog(
                            context: context,
                            builder: (context) => SupplierLinkWebViewDialog(
                              url: url,
                              supplierName: _selectedSupplierName,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Icon(Icons.visibility),
                    ),
                  ),
                ],
              ),
            ],
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
      backgroundColor: AppColors.backgroundGray,
      body: _isSaving
          ? const Center(child: AppLoadingIndicator())
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  expandedHeight: 120,
                  pinned: true,
                  stretch: true,
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      widget.productId == null
                          ? l10n.productFormTitleNew
                          : l10n.productFormTitleEdit,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    centerTitle: false,
                    titlePadding: const EdgeInsets.only(left: 56, bottom: 16),
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primaryBlue,
                            AppColors.primaryDark,
                          ],
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: IconButton(
                        icon: const Icon(Icons.check_circle, size: 28),
                        onPressed: _isSaving ? null : () => _saveProduct(l10n),
                      ),
                    ),
                  ],
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildImageGalleryCard(l10n),
                          _buildGeneralInfoCard(l10n),
                          _buildPricingCard(l10n),
                          _buildDetailsCard(l10n),
                          userRoleAsync.when(
                            data: (role) => _buildSupplierCard(l10n, role),
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
