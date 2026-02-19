import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:techsc/features/catalog/models/category_model.dart';
import 'package:techsc/features/catalog/services/category_service.dart';
import 'package:techsc/l10n/app_localizations.dart';

/// Pagina de formulario para crear o editar servicios.
/// Incluye gestión de componentes dinámicos y validación de campos.
class ServiceFormPage extends ConsumerStatefulWidget {
  final String? serviceId;
  final Map<String, dynamic>? initialData;

  const ServiceFormPage({super.key, this.serviceId, this.initialData});

  @override
  ConsumerState<ServiceFormPage> createState() => _ServiceFormPageState();
}

class _ServiceFormPageState extends ConsumerState<ServiceFormPage> {
  final _formKey = GlobalKey<FormState>();

  // Controladores para los campos de texto
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _priceController;
  late TextEditingController _durationController;

  // Lista de URLs de imágenes
  List<String> _imageUrls = [];
  final TextEditingController _newImageUrlController = TextEditingController();

  // Lista dinámica de componentes del servicio
  late List<String> _components;

  // Guardamos el ID de la categoría seleccionada
  String? _selectedCategoryId;
  // Guardamos el nombre para denormalización
  String? _selectedCategoryName;

  String? _selectedTaxStatus;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    // Inicializar controladores. Si hay datos iniciales (edición), se precargan.
    _titleController = TextEditingController(
      text: widget.initialData?['title'] ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.initialData?['description'] ?? '',
    );
    _priceController = TextEditingController(
      text: widget.initialData?['price']?.toString() ?? '',
    );
    _durationController = TextEditingController(
      text: widget.initialData?['duration'] ?? '',
    );

    // Cargar vinculación de categoría
    _selectedCategoryId = widget.initialData?['categoryId'];
    _selectedCategoryName =
        widget.initialData?['category'] ?? widget.initialData?['type'];

    _selectedTaxStatus = widget.initialData?['taxStatus'] ?? 'Incluye impuesto';

    // Cargar imágenes existentes
    if (widget.initialData?['imageUrls'] != null) {
      _imageUrls = List<String>.from(widget.initialData!['imageUrls']);
    } else if (widget.initialData?['imageUrl'] != null) {
      _imageUrls = [widget.initialData!['imageUrl']];
    }

    // Inicializar lista de componentes
    _components = List<String>.from(
      widget.initialData?['components'] ?? ['Diagnóstico básico'],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _durationController.dispose();
    _newImageUrlController.dispose();
    super.dispose();
  }

  void _addNewComponent(AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text(l10n.serviceFormTitleNew),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Ej: Reemplazo de disco SSD',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  setState(() {
                    _components.add(controller.text.trim());
                  });
                }
                Navigator.pop(context);
              },
              child: Text(
                l10n.addImage,
              ), // Using addImage as label for Consistency if no specific key
            ),
          ],
        );
      },
    );
  }

  void _removeComponent(int index) {
    setState(() {
      _components.removeAt(index);
    });
  }

  Future<void> _saveService(AppLocalizations l10n) async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageUrls.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.atLeastOneImage)));
      return;
    }

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final price = double.tryParse(_priceController.text) ?? 0.0;

    setState(() => _isSaving = true);

    try {
      final serviceData = {
        'title': title,
        'description': description,
        'price': price,
        'duration': _durationController.text.trim(),
        'imageUrls': _imageUrls,
        'imageUrl': _imageUrls.first,
        'categoryId': _selectedCategoryId,
        'category': _selectedCategoryName,
        'type': _selectedCategoryName,
        'taxStatus': _selectedTaxStatus,
        'components': _components,
        if (widget.serviceId == null) 'createdAt': FieldValue.serverTimestamp(),
      };

      final db = FirebaseFirestore.instance;
      if (widget.serviceId == null) {
        await db.collection('services').add(serviceData);
      } else {
        await db
            .collection('services')
            .doc(widget.serviceId)
            .update(serviceData);
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
          l10n.serviceImages,
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.image_outlined, size: 40, color: Colors.grey),
                Text(
                  l10n.noImagesAdded,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildComponentsList(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Componentes incluidos', // This could also be localized if a key is added
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              onPressed: () => _addNewComponent(l10n),
              icon: const Icon(Icons.add, size: 16),
              label: Text(
                l10n.addImage,
              ), // Reuse for consistency or add specific key
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(100, 32),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_components.length, (index) {
            final component = _components[index];
            return Chip(
              label: Text(component),
              deleteIcon: const Icon(Icons.close, size: 16),
              onDeleted: () => _removeComponent(index),
              backgroundColor: Colors.blue[100],
            );
          }),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.serviceId == null
              ? l10n.serviceFormTitleNew
              : l10n.serviceFormTitleEdit,
        ),
        actions: [
          IconButton(
            icon: _isSaving
                ? const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  )
                : const Icon(Icons.check, color: Colors.white),
            onPressed: _isSaving ? null : () => _saveService(l10n),
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
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: '${l10n.productName} *',
                        border: const OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return l10n.errorPrefix;
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: '${l10n.productDescription} *',
                        border: const OutlineInputBorder(),
                      ),
                      maxLines: 4,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? l10n.errorPrefix
                          : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _priceController,
                      decoration: InputDecoration(
                        labelText: '${l10n.productPrice} *',
                        prefixText: '\$ ',
                        border: const OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final num = double.tryParse(value ?? '');
                        if (num == null || num <= 0) return l10n.invalidPrice;
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _durationController,
                      decoration: const InputDecoration(
                        labelText: 'Duración estimada',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),
                    StreamBuilder<List<CategoryModel>>(
                      stream: CategoryService().getCategories(
                        CategoryType.service,
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
                            labelText: '${l10n.productCategory} *',
                            border: const OutlineInputBorder(),
                          ),
                          items: categories.map((c) {
                            return DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name.toUpperCase()),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedCategoryId = value;
                              _selectedCategoryName = categories
                                  .firstWhere((c) => c.id == value)
                                  .name;
                            });
                          },
                          validator: (v) => v == null ? l10n.errorPrefix : null,
                        );
                      },
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
                    _buildComponentsList(l10n),
                  ],
                ),
              ),
            ),
    );
  }
}
