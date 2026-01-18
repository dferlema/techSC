import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/category_model.dart';
import '../services/category_service.dart';

/// Pagina de formulario para crear o editar productos.
/// Permite ingresar nombre, especificaciones, precio, categoría y URL de imagen.
class ProductFormPage extends StatefulWidget {
  final String? productId;
  final Map<String, dynamic>? initialData;

  const ProductFormPage({super.key, this.productId, this.initialData});

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
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

  late String _selectedLabel;
  late String _selectedTaxStatus;
  late double _rating;

  // Lista de URLs de imágenes
  List<String> _imageUrls = [];
  final TextEditingController _newImageUrlController = TextEditingController();

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

    // Cargar imágenes existentes
    if (widget.initialData?['images'] != null) {
      _imageUrls = List<String>.from(widget.initialData!['images']);
    } else if (widget.initialData?['image'] != null) {
      // Compatibilidad con formato antiguo (una sola imagen)
      _imageUrls = [widget.initialData!['image']];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _specsController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _newImageUrlController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Agrega al menos una imagen')),
      );
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
        'categoryId':
            _selectedCategoryId, // ID de la categoría (Vínculo fuerte)
        'category':
            _selectedCategoryName, // Nombre de la categoría (Denormalizado)
        'label': _selectedLabel,
        'taxStatus': _selectedTaxStatus,
        'rating': _rating,
        'images': _imageUrls,
        'image': _imageUrls.first,
        if (widget.productId == null) 'createdAt': FieldValue.serverTimestamp(),
      };

      final db = FirebaseFirestore.instance;
      if (widget.productId == null) {
        await db.collection('products').add(productData);
      } else {
        await db
            .collection('products')
            .doc(widget.productId)
            .update(productData);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Error: ${e.toString()}')));
    }
  }

  Widget _buildImageGallery() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Imágenes del Producto *',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _newImageUrlController,
                decoration: const InputDecoration(
                  hintText: 'https://ejemplo.com/imagen.jpg',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
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
                          child: const Text(
                            'Principal',
                            style: TextStyle(color: Colors.white, fontSize: 10),
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
                children: const [
                  Icon(Icons.image_outlined, size: 40, color: Colors.grey),
                  Text(
                    'No hay imágenes agregadas',
                    style: TextStyle(color: Colors.grey),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.productId == null ? 'Nuevo Producto' : 'Editar Producto',
        ),
        actions: [
          IconButton(
            icon: _isSaving
                ? const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  )
                : const Icon(Icons.check, color: Colors.white),
            onPressed: _isSaving ? null : _saveProduct,
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
                    _buildImageGallery(),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v!.trim().isEmpty ? 'Obligatorio' : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _specsController,
                      decoration: const InputDecoration(
                        labelText: 'Especificaciones',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Descripción',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Precio *',
                        prefixText: '\$ ',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) =>
                          double.tryParse(v!) == null || double.parse(v) <= 0
                          ? 'Válido > 0'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    StreamBuilder<List<CategoryModel>>(
                      stream: CategoryService().getCategories(
                        CategoryType.product,
                      ),
                      builder: (context, snapshot) {
                        final categories = snapshot.data ?? [];

                        // Manejar selección inicial o si la categoría ya no existe
                        bool categoryExists = categories.any(
                          (c) => c.id == _selectedCategoryId,
                        );
                        if (!categoryExists && categories.isNotEmpty) {
                          _selectedCategoryId = categories.first.id;
                          _selectedCategoryName = categories.first.name;
                        }

                        return DropdownButtonFormField<String>(
                          value: _selectedCategoryId,
                          decoration: const InputDecoration(
                            labelText: 'Categoría *',
                            border: OutlineInputBorder(),
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
                          validator: (v) => v == null ? 'Selecciona' : null,
                        );
                      },
                    ),

                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      value: _selectedLabel,
                      decoration: const InputDecoration(
                        labelText: 'Etiqueta (Opcional)',
                        border: OutlineInputBorder(),
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
                      value: _selectedTaxStatus,
                      decoration: const InputDecoration(
                        labelText: 'Estado de Impuestos',
                        border: OutlineInputBorder(),
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
                        const Text(
                          'Calificación',
                          style: TextStyle(fontWeight: FontWeight.bold),
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
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
