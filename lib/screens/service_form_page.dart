import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Pagina de formulario para crear o editar servicios.
/// Incluye gestión de componentes dinámicos y validación de campos.
class ServiceFormPage extends StatefulWidget {
  final String? serviceId;
  final Map<String, dynamic>? initialData;

  const ServiceFormPage({super.key, this.serviceId, this.initialData});

  @override
  State<ServiceFormPage> createState() => _ServiceFormPageState();
}

class _ServiceFormPageState extends State<ServiceFormPage> {
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

  late String _selectedType;
  late String _selectedTaxStatus;
  bool _isSaving = false;

  // Tipos de servicio disponibles
  static const List<String> _serviceTypes = [
    'reparacion',
    'instalacion',
    'diagnostico',
    'mantenimiento',
  ];

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
    _selectedType = widget.initialData?['type'] ?? _serviceTypes[0];
    _selectedTaxStatus = widget.initialData?['taxStatus'] ?? 'Incluye impuesto';

    // Cargar imágenes existentes
    if (widget.initialData?['imageUrls'] != null) {
      _imageUrls = List<String>.from(widget.initialData!['imageUrls']);
    } else if (widget.initialData?['imageUrl'] != null) {
      _imageUrls = [widget.initialData!['imageUrl']];
    }

    // Inicializar lista de componentes (copia para evitar modificar referencia original)
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

  void _addNewComponent() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Nuevo componente'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Ej: Reemplazo de disco SSD',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
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
              child: const Text('Agregar'),
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

  Future<void> _saveService() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Agrega al menos una imagen')),
      );
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
        'type': _selectedType,
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
      ).showSnackBar(SnackBar(content: Text('❌ Error: ${e.toString()}')));
    }
  }

  Widget _buildImageGallery() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Imágenes del Servicio *',
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
      ],
    );
  }

  Widget _buildComponentsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Componentes incluidos',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              onPressed: _addNewComponent,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Agregar'),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.serviceId == null ? 'Nuevo Servicio' : 'Editar Servicio',
        ),
        actions: [
          IconButton(
            icon: _isSaving
                ? const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  )
                : const Icon(Icons.check, color: Colors.white),
            onPressed: _isSaving ? null : _saveService,
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
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Título del servicio *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty)
                          return 'Obligatorio';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Descripción *',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 4,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Obligatorio'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Precio base *',
                        prefixText: '\$ ',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        final num = double.tryParse(value ?? '');
                        if (num == null || num <= 0) return 'Precio > 0';
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
                    DropdownButtonFormField<String>(
                      initialValue: _selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de servicio *',
                        border: OutlineInputBorder(),
                      ),
                      items: _serviceTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(_capitalize(type)),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setState(() => _selectedType = value!),
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
                    _buildComponentsList(),
                  ],
                ),
              ),
            ),
    );
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return '${text[0].toUpperCase()}${text.substring(1)}';
  }
}
