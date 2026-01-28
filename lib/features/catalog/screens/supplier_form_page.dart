import 'package:flutter/material.dart';
import 'package:techsc/features/catalog/models/supplier_model.dart';
import 'package:techsc/features/catalog/services/supplier_service.dart';

/// Página de formulario para crear o editar proveedores.
///
/// Permite ingresar nombre, información de contacto y sitio web del proveedor.
class SupplierFormPage extends StatefulWidget {
  final SupplierModel? supplier;

  const SupplierFormPage({super.key, this.supplier});

  @override
  State<SupplierFormPage> createState() => _SupplierFormPageState();
}

class _SupplierFormPageState extends State<SupplierFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _supplierService = SupplierService();

  late TextEditingController _nameController;
  late TextEditingController _contactNameController;
  late TextEditingController _contactPhoneController;
  late TextEditingController _websiteController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.supplier?.name ?? '');
    _contactNameController = TextEditingController(
      text: widget.supplier?.contactName ?? '',
    );
    _contactPhoneController = TextEditingController(
      text: widget.supplier?.contactPhone ?? '',
    );
    _websiteController = TextEditingController(
      text: widget.supplier?.website ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _saveSupplier() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final name = _nameController.text.trim();
      final contactName = _contactNameController.text.trim();
      final contactPhone = _contactPhoneController.text.trim();
      final website = _websiteController.text.trim();

      // Verificar si el nombre ya existe
      final nameExists = await _supplierService.supplierNameExists(
        name,
        excludeId: widget.supplier?.id,
      );

      if (nameExists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Ya existe un proveedor con ese nombre'),
          ),
        );
        setState(() => _isSaving = false);
        return;
      }

      if (widget.supplier == null) {
        // Crear nuevo proveedor
        final newSupplier = SupplierModel(
          id: '',
          name: name,
          contactName: contactName,
          contactPhone: contactPhone,
          website: website,
          createdAt: DateTime.now(),
        );
        await _supplierService.addSupplier(newSupplier);
      } else {
        // Actualizar proveedor existente
        final updatedSupplier = widget.supplier!.copyWith(
          name: name,
          contactName: contactName,
          contactPhone: contactPhone,
          website: website,
        );
        await _supplierService.updateSupplier(updatedSupplier);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.supplier == null ? 'Nuevo Proveedor' : 'Editar Proveedor',
        ),
        actions: [
          IconButton(
            icon: _isSaving
                ? const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  )
                : const Icon(Icons.check, color: Colors.white),
            onPressed: _isSaving ? null : _saveSupplier,
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
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del Proveedor *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.business),
                      ),
                      validator: (v) =>
                          v!.trim().isEmpty ? 'Campo obligatorio' : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _contactNameController,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del Contacto *',
                        hintText: 'Ej: Juan Pérez',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (v) =>
                          v!.trim().isEmpty ? 'Campo obligatorio' : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _contactPhoneController,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono del Contacto *',
                        hintText: 'Ej: 0987654321',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (v) {
                        if (v!.trim().isEmpty) return 'Campo obligatorio';
                        final phone = v.replaceAll(RegExp(r'\D'), '');
                        if (phone.length < 9) {
                          return 'Ingrese un número válido (mín. 9 dígitos)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _websiteController,
                      decoration: const InputDecoration(
                        labelText: 'Sitio Web',
                        hintText: 'https://ejemplo.com',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.language),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
