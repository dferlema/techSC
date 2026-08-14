import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tscomputer/core/services/document_id_service.dart';
import 'package:tscomputer/core/services/notification_service.dart';
import 'package:tscomputer/features/catalog/services/supplier_service.dart';
import 'package:tscomputer/core/services/role_service.dart';
import 'package:tscomputer/core/theme/app_colors.dart';
import 'package:tscomputer/features/catalog/widgets/supplier_link_dialog.dart';
import 'package:tscomputer/features/catalog/models/category_model.dart';
import 'package:tscomputer/features/catalog/models/supplier_model.dart';
import 'package:tscomputer/features/catalog/services/category_service.dart';
import 'package:tscomputer/features/admin/providers/admin_providers.dart';
import 'package:tscomputer/l10n/app_localizations.dart';
import 'package:tscomputer/core/services/config_service.dart';
import 'package:tscomputer/features/admin/models/profit_range_model.dart';
import 'package:tscomputer/core/widgets/app_loading_indicator.dart';
import 'dart:async';

/// Página de formulario para crear o editar productos con UI/UX moderno e intuitivo.
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

  // Cuentas de categoría
  String? _selectedCategoryId;
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

    _selectedCategoryId = widget.initialData?['categoryId'];
    _selectedCategoryName = widget.initialData?['category'];

    _selectedLabel = widget.initialData?['label'] ?? 'Ninguna';
    _selectedTaxStatus = widget.initialData?['taxStatus'] ?? 'Incluye impuesto';
    _rating = (widget.initialData?['rating'] as num?)?.toDouble() ?? 4.5;
    _isFeatured = widget.initialData?['isFeatured'] ?? false;

    if (widget.initialData?['images'] != null) {
      _imageUrls = List<String>.from(widget.initialData!['images']);
    } else if (widget.initialData?['image'] != null) {
      _imageUrls = [widget.initialData!['image']];
    }

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

    _costWithoutIvaController.addListener(_onCostChanged);

    _profitRangesSub = ConfigService().getProfitRangesStream().listen((ranges) {
      if (mounted) setState(() => _profitRanges = ranges);
      if (_isAutoPriceEnabled) _calculatePrices();
    });

    _configSub = ConfigService().getConfigStream().listen((config) {
      if (mounted) setState(() => _vatPercentage = config.vatPercentage);
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
      fixedProfit = double.tryParse(_fixedProfitController.text) ?? 0;
      if (costWithIva > 0) {
        margin = (fixedProfit / costWithIva) * 100;
        _profitMarginController.text = margin.toStringAsFixed(1);
      }
    } else {
      if (isMarginChange) {
        margin = double.tryParse(_profitMarginController.text) ?? 0;
        fixedProfit = (costWithIva * margin) / 100;
        _fixedProfitController.text = fixedProfit.toStringAsFixed(2);
      } else {
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
    final cardPrice = pvp / (1 - 0.06);

    _priceController.text = cardPrice.toStringAsFixed(2);
    _cardPriceController.text = pvp.toStringAsFixed(2);

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
      final idService = DocumentIdService();
      String finalProductId;

      if (widget.productId == null) {
        finalProductId = await idService.generateId(prefix: 'prod');
        await db.collection('products').doc(finalProductId).set(productData);
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

  // --- UI BUILDERS ---

  Widget _buildCard({
    required List<Widget> children,
    Color? color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.nearBlack,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration({
    required String labelText,
    required IconData prefixIcon,
    String? prefixText,
    String? hintText,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixText: prefixText,
      prefixIcon: Icon(prefixIcon, color: AppColors.primaryBlue),
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: AppColors.primaryBlue, width: 2),
      ),
    );
  }

  Widget _buildImageGalleryCard(AppLocalizations l10n) {
    return _buildCard(
      children: [
        _buildSectionHeader(
          title: 'Imágenes del Producto',
          subtitle: 'Añada los enlaces de las imágenes de alta calidad',
          icon: Icons.photo_library_outlined,
          color: AppColors.primaryBlue,
        ),
        const Divider(height: 1),
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
                      decoration: _buildInputDecoration(
                        labelText: 'URL de Imagen',
                        hintText: l10n.imageLinkHint,
                        prefixIcon: Icons.link,
                      ),
                      keyboardType: TextInputType.url,
                    ),
                  ),
                  const SizedBox(width: 12),
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
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add, size: 20),
                        SizedBox(width: 4),
                        Text('Agregar', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
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
                      final isMain = index == 0;
                      return Container(
                        margin: const EdgeInsets.only(right: 12),
                        width: 130,
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isMain
                                      ? AppColors.primaryBlue
                                      : Colors.grey.shade300,
                                  width: isMain ? 2 : 1,
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
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Color(0xB3000000),
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
                            if (isMain)
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
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.star,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Principal',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
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
                      color: Colors.grey.shade300,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        size: 36,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.noImagesAdded,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
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
      children: [
        _buildSectionHeader(
          title: 'Información del Producto',
          subtitle: 'Nombre, especificaciones y descripción comercial',
          icon: Icons.inventory_2_outlined,
          color: Colors.teal,
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: _buildInputDecoration(
                  labelText: '${l10n.productName} *',
                  prefixIcon: Icons.shopping_bag_outlined,
                ),
                validator: (v) => v!.trim().isEmpty ? l10n.errorPrefix : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _specsController,
                decoration: _buildInputDecoration(
                  labelText: l10n.productSpecs,
                  prefixIcon: Icons.list_alt_outlined,
                  hintText: 'Ej: RAM 16GB, SSD 512GB, Core i7',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: _buildInputDecoration(
                  labelText: l10n.productDescription,
                  prefixIcon: Icons.description_outlined,
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
      children: [
        _buildSectionHeader(
          title: 'Precios y Márgenes de Ganancia',
          subtitle: 'Calculadora automática de PVP Efectivo y Tarjeta',
          icon: Icons.calculate_outlined,
          color: Colors.orange.shade800,
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Auto vs Manual Mode Switch
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_mode, color: Colors.orange.shade800),
                        const SizedBox(width: 10),
                        Text(
                          'Cálculo Automático',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: _isAutoPriceEnabled,
                      activeThumbColor: Colors.orange.shade800,
                      onChanged: (v) {
                        setState(() {
                          _isAutoPriceEnabled = v;
                          if (v) _calculatePrices();
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Ganancia Porcentaje vs Fija Selector
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment<bool>(
                    value: false,
                    label: Text('% Ganancia'),
                    icon: Icon(Icons.percent),
                  ),
                  ButtonSegment<bool>(
                    value: true,
                    label: Text('\$ Ganancia Fija'),
                    icon: Icon(Icons.attach_money),
                  ),
                ],
                selected: {_useFixedProfit},
                onSelectionChanged: (selection) {
                  setState(() {
                    _useFixedProfit = selection.first;
                    _calculatePrices();
                  });
                },
              ),
              const SizedBox(height: 20),

              // Cost inputs
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _costWithoutIvaController,
                      decoration: _buildInputDecoration(
                        labelText: 'Costo (sin IVA)',
                        prefixIcon: Icons.payments_outlined,
                        prefixText: '\$ ',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _costWithIvaController,
                      readOnly: true,
                      decoration: _buildInputDecoration(
                        labelText: 'Costo (con IVA ${(_vatPercentage).toInt()}%)',
                        prefixIcon: Icons.receipt_long,
                        prefixText: '\$ ',
                      ).copyWith(
                        fillColor: Colors.grey[100],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Profit margin inputs
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _profitMarginController,
                      readOnly: _isAutoPriceEnabled && _useFixedProfit,
                      onChanged: (v) => _onProfitChanged(isMarginChange: true),
                      decoration: _buildInputDecoration(
                        labelText: 'Ganancia (%)',
                        prefixIcon: Icons.trending_up,
                        prefixText: '% ',
                      ).copyWith(
                        fillColor: (_isAutoPriceEnabled && _useFixedProfit)
                            ? Colors.grey[100]
                            : Colors.grey[50],
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
                      decoration: _buildInputDecoration(
                        labelText: 'Ganancia (\$) ',
                        prefixIcon: Icons.attach_money,
                        prefixText: '\$ ',
                      ).copyWith(
                        fillColor: (_isAutoPriceEnabled && !_useFixedProfit)
                            ? Colors.grey[100]
                            : Colors.grey[50],
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // Financial Result Cards
              Row(
                children: [
                  // PVP Efectivo
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.payments,
                                color: Colors.green.shade700,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'PVP EFECTIVO',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green.shade800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '\$ ${_cardPriceController.text.isEmpty ? '0.00' : _cardPriceController.text}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.green.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // PVP Tarjeta
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.credit_card,
                                color: Colors.blue.shade700,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'PVP TARJETA',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue.shade800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '\$ ${_priceController.text.isEmpty ? '0.00' : _priceController.text}',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildDetailsCard(AppLocalizations l10n) {
    return _buildCard(
      children: [
        _buildSectionHeader(
          title: 'Clasificación y Atributos',
          subtitle: 'Categoría del producto, estado de IVA y visibilidad',
          icon: Icons.tune_outlined,
          color: Colors.indigo,
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StreamBuilder<List<CategoryModel>>(
                stream: CategoryService().getCategories(CategoryType.product),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, color: Colors.orange, size: 32),
                            const SizedBox(height: 8),
                            Text('Error al cargar datos', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text('${snapshot.error}', style: TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    );
                  }
                  final categories = snapshot.data ?? [];
                  return DropdownButtonFormField<String>(
                    initialValue: _selectedCategoryId,
                    decoration: _buildInputDecoration(
                      labelText: l10n.productCategory,
                      prefixIcon: Icons.category_outlined,
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
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedLabel,
                      decoration: _buildInputDecoration(
                        labelText: l10n.productLabel,
                        prefixIcon: Icons.label_outlined,
                      ),
                      items: ['Ninguna', 'Oferta', 'Agotado']
                          .map(
                            (l) => DropdownMenuItem(value: l, child: Text(l)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedLabel = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedTaxStatus,
                      decoration: _buildInputDecoration(
                        labelText: l10n.taxStatus,
                        prefixIcon: Icons.monetization_on_outlined,
                      ),
                      items: ['Incluye impuesto', 'Más impuesto', 'Ninguno']
                          .map(
                            (t) => DropdownMenuItem(value: t, child: Text(t)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedTaxStatus = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Rating Slider
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Calificación Inicial',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.nearBlack,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _rating.toStringAsFixed(1),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _rating,
                      min: 1,
                      max: 5,
                      activeColor: Colors.amber,
                      divisions: 8,
                      onChanged: (v) => setState(() => _rating = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Featured Switch
              SwitchListTile(
                title: const Text(
                  'Producto Destacado',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('Mostrar en el carrusel de inicio'),
                value: _isFeatured,
                activeThumbColor: AppColors.primaryBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Colors.grey.shade200),
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
      children: [
        _buildSectionHeader(
          title: 'Información de Proveedor',
          subtitle: 'Vínculo y compras directas',
          icon: Icons.business_outlined,
          color: Colors.purple,
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              StreamBuilder<List<SupplierModel>>(
                stream: SupplierService().getSuppliers(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, color: Colors.orange, size: 32),
                            const SizedBox(height: 8),
                            Text('Error al cargar datos', style: TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text('${snapshot.error}', style: TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    );
                  }
                  final suppliers = snapshot.data ?? [];
                  return DropdownButtonFormField<String>(
                    initialValue: _selectedSupplierId,
                    decoration: _buildInputDecoration(
                      labelText: l10n.supplierInfo,
                      prefixIcon: Icons.business,
                    ),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('— Sin Proveedor —')),
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
                      decoration: _buildInputDecoration(
                        labelText: l10n.supplierLink,
                        prefixIcon: Icons.link,
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
                          borderRadius: BorderRadius.circular(14),
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

    final titleText = widget.productId == null
        ? l10n.productFormTitleNew
        : l10n.productFormTitleEdit;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          titleText,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.check, size: 28),
            onPressed: _isSaving ? null : () => _saveProduct(l10n),
            tooltip: 'Guardar',
          ),
        ],
      ),
      body: _isSaving
          ? const Center(child: AppLoadingIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
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
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : () => _saveProduct(l10n),
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.save),
              label: Text(
                _isSaving
                    ? 'GUARDANDO...'
                    : (widget.productId == null
                        ? 'GUARDAR PRODUCTO'
                        : 'GUARDAR CAMBIOS'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
