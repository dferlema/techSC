// lib/screens/product_form_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  late TextEditingController
  _imageUrlController; // 👈 Nuevo controlador para URL
  late String _selectedCategory;
  late double _rating;

  bool _isSaving = false;

  // Lista de categorías predefinidas
  static const List<String> _categories = [
    'computadoras',
    'accesorios',
    'repuestos',
  ];

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
    _imageUrlController = TextEditingController(
      text: widget.initialData?['image'] ?? '', // 👈 Cargar URL existente
    );
    _selectedCategory = widget.initialData?['category'] ?? _categories[0];
    _rating = (widget.initialData?['rating'] as num?)?.toDouble() ?? 4.5;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _specsController.dispose();
    _priceController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  /// Guarda el producto en Firebase Firestore.
  /// Si [widget.productId] es null, crea un nuevo documento.
  /// Si no, actualiza el existente.
  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final name = _nameController.text.trim();
    final specs = _specsController.text.trim();
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final imageUrl = _imageUrlController.text.trim();

    try {
      final productData = {
        'name': name,
        'specs': specs,
        'price': price,
        'category': _selectedCategory,
        'rating': _rating,
        'image': imageUrl.isNotEmpty ? imageUrl : null,
        // Agregar timestamp solo si es nuevo registro
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
      Navigator.pop(context, true); // Retorna true para indicar éxito
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Error: ${e.toString()}')));
    }
  }

  /// Construye el campo de entrada de URL y la vista previa de la imagen.
  Widget _buildImagePreview() {
    // Escuchar cambios en el controlador para actualizar vista previa
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _imageUrlController,
      builder: (context, value, child) {
        final currentUrl = value.text.trim();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Imagen URL',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _imageUrlController,
              decoration: const InputDecoration(
                hintText: 'https://ejemplo.com/imagen.jpg',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            // Contenedor de vista previa
            Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[50],
              ),
              child: currentUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        currentUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(),
                      ),
                    )
                  : _placeholder(),
            ),
          ],
        );
      },
    );
  }

  Widget _placeholder() => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: const [
      Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
      SizedBox(height: 8),
      Text('Vista previa no disponible', style: TextStyle(color: Colors.grey)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1976D2),
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
                    _buildImagePreview(),
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
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: 'Categoría *',
                        border: OutlineInputBorder(),
                      ),
                      items: _categories
                          .map(
                            (c) => DropdownMenuItem(
                              value: c,
                              child: Text(c.capitalize()),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _selectedCategory = v!),
                      validator: (v) => v == null ? 'Selecciona' : null,
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

extension on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
