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
  late TextEditingController _imageUrlController;

  // Lista dinámica de componentes del servicio
  late List<String> _components;

  late String _selectedType;

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
    _imageUrlController = TextEditingController(
      text: widget.initialData?['imageUrl'] ?? '',
    );
    _selectedType = widget.initialData?['type'] ?? _serviceTypes[0];

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
    _imageUrlController.dispose();
    super.dispose();
  }

  // 🖼️ Validar URL de imagen usando Uri.tryParse
  bool _isImageUrlValid(String url) {
    if (url.isEmpty) return true;
    return Uri.tryParse(url)?.hasAbsolutePath ?? false;
  }

  // ➕ Añadir componente a la lista mediante un diálogo emergente
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

  // ➖ Eliminar componente de la lista por índice
  void _removeComponent(int index) {
    setState(() {
      _components.removeAt(index);
    });
  }

  // 💾 Guardar o actualizar servicio
  // Realiza validaciones campos obligatorios y URL antes de enviar a Firestore.
  Future<void> _saveService() async {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final price = double.tryParse(_priceController.text) ?? 0.0;
    final imageUrl = _imageUrlController.text.trim();

    // Validaciones manuales adicionales
    if (title.isEmpty || description.isEmpty || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Título, descripción y precio son obligatorios'),
        ),
      );
      return;
    }

    if (!_isImageUrlValid(imageUrl)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('URL de imagen inválida')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final serviceData = {
        'title': title,
        'description': description,
        'price': price,
        'duration': _durationController.text.trim(),
        'imageUrl': imageUrl,
        'type': _selectedType,
        'components': _components,
        if (widget.serviceId == null) 'createdAt': FieldValue.serverTimestamp(),
      };

      final db = FirebaseFirestore.instance;
      if (widget.serviceId == null) {
        // ✅ Crear nuevo documento
        await db.collection('services').add(serviceData);
      } else {
        // ✏️ Actualizar documento existente
        await db
            .collection('services')
            .doc(widget.serviceId)
            .update(serviceData);
      }

      Navigator.pop(context, true); // Éxito
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Error: ${e.toString()}')));
    }
  }

  // 🖼️ Vista previa de imagen desde URL
  Widget _buildImagePreview() {
    final url = _imageUrlController.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'URL de imagen (opcional)',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _imageUrlController,
          decoration: InputDecoration(
            hintText: 'https://ejemplo.com/imagen.jpg',
            border: OutlineInputBorder(),
            suffixIcon: url.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => _imageUrlController.clear(),
                  )
                : null,
          ),
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 12),
        if (url.isNotEmpty)
          Container(
            height: 150,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[200],
                  child: const Center(
                    child: Icon(Icons.broken_image, color: Colors.grey),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // 🔧 Chips de componentes
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
                    // 🖼️ URL de imagen
                    _buildImagePreview(),
                    const SizedBox(height: 24),

                    // 🏷️ Título
                    TextFormField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: 'Título del servicio *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Obligatorio';
                        }
                        if (value.trim().length < 3) {
                          return 'Mínimo 3 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // 📝 Descripción
                    TextFormField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: 'Descripción *',
                        hintText: 'Detalla qué incluye este servicio...',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 4,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Obligatorio'
                          : null,
                    ),
                    const SizedBox(height: 20),

                    // 💰 Precio
                    TextFormField(
                      controller: _priceController,
                      decoration: InputDecoration(
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

                    // ⏱️ Duración
                    TextFormField(
                      controller: _durationController,
                      decoration: InputDecoration(
                        labelText: 'Duración estimada',
                        hintText: 'Ej: 1 hora, 30 min',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 🛠️ Tipo de servicio
                    DropdownButtonFormField<String>(
                      initialValue: _selectedType,
                      decoration: InputDecoration(
                        labelText: 'Tipo de servicio *',
                        border: OutlineInputBorder(),
                      ),
                      items: _serviceTypes.map((type) {
                        final label = _capitalize(type);
                        return DropdownMenuItem(
                          value: type,
                          child: Text(label),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setState(() => _selectedType = value!),
                      validator: (value) =>
                          value == null ? 'Selecciona un tipo' : null,
                    ),
                    const SizedBox(height: 20),

                    // 🔧 Componentes
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
