import 'package:flutter/material.dart';
import 'package:tscomputer/core/utils/validators.dart';
import 'package:tscomputer/features/catalog/models/supplier_model.dart';
import 'package:tscomputer/features/catalog/services/supplier_service.dart';

/// Página de formulario para crear o editar proveedores.
///
/// Permite ingresar nombre, RUC, información de contacto y sitio web del proveedor.
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
  late TextEditingController _rucController;
  late TextEditingController _contactNameController;
  late TextEditingController _contactPhoneController;
  late TextEditingController _websiteController;
  late TextEditingController _addressController;
  late TextEditingController _emailController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.supplier?.name ?? '');
    _rucController = TextEditingController(text: widget.supplier?.ruc ?? '');
    _contactNameController = TextEditingController(
      text: widget.supplier?.contactName ?? '',
    );
    _contactPhoneController = TextEditingController(
      text: widget.supplier?.contactPhone ?? '',
    );
    _websiteController = TextEditingController(
      text: widget.supplier?.website ?? '',
    );
    _addressController = TextEditingController(
      text: widget.supplier?.address ?? '',
    );
    _emailController = TextEditingController(
      text: widget.supplier?.email ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rucController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _websiteController.dispose();
    _addressController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  /// Valida que el RUC tenga el formato correcto (13 dígitos, provincia válida).
  /// Para SAS/Sociedades (tercer dígito ≥ 6) solo valida formato, no el
  /// dígito verificador módulo 11, porque el SRI a veces asigna RUCs que
  /// no pasan la validación matemática estándar.
  String? _validateRuc(String? value) {
    final ruc = (value ?? '').trim();
    if (ruc.isEmpty) return 'Ingrese el RUC';
    if (ruc.length != 13) return 'El RUC debe tener 13 dígitos';
    if (!RegExp(r'^\d+$').hasMatch(ruc)) return 'El RUC solo debe contener números';

    // Validar provincia (primeros 2 dígitos: 01-24 o 30)
    final province = int.tryParse(ruc.substring(0, 2));
    if (province == null || ((province < 1 || province > 24) && province != 30)) {
      return 'Código de provincia inválido';
    }

    // Validar que el establecimiento no sea 000
    if (ruc.substring(10) == '000') return 'Número de establecimiento inválido';

    // Para personas naturales (tercer dígito < 6), validar dígito verificador
    final thirdDigit = int.parse(ruc[2]);
    if (thirdDigit < 6) {
      if (!Validators.isValidEcuadorianId(ruc)) {
        return 'RUC de persona natural no válido';
      }
    }
    // Para SAS (9), sociedades públicas (6) y otros, solo validar formato
    return null;
  }

  Future<void> _saveSupplier() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final name = _nameController.text.trim();
      final ruc = _rucController.text.trim();
      final contactName = _contactNameController.text.trim();
      final contactPhone = _contactPhoneController.text.trim();
      final website = _websiteController.text.trim();
      final address = _addressController.text.trim();
      final email = _emailController.text.trim();

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

      // Verificar si el RUC ya está registrado
      final rucExists = await _supplierService.supplierRucExists(
        ruc,
        excludeId: widget.supplier?.id,
      );

      if (rucExists) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Ya existe un proveedor con ese RUC'),
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
          ruc: ruc,
          contactName: contactName,
          contactPhone: contactPhone,
          website: website,
          address: address,
          email: email,
          createdAt: DateTime.now(),
        );
        await _supplierService.addSupplier(newSupplier);
      } else {
        // Actualizar proveedor existente
        final updatedSupplier = widget.supplier!.copyWith(
          name: name,
          ruc: ruc,
          contactName: contactName,
          contactPhone: contactPhone,
          website: website,
          address: address,
          email: email,
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
                      controller: _rucController,
                      decoration: const InputDecoration(
                        labelText: 'RUC *',
                        hintText: '13 dígitos, ej: 1790010019001',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 13,
                      validator: _validateRuc,
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
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        labelText: 'Dirección',
                        hintText: 'Ej: Av. Principal 123, Quito',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      keyboardType: TextInputType.streetAddress,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        hintText: 'ejemplo@correo.com',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v != null && v.trim().isNotEmpty) {
                          final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                          if (!emailRegex.hasMatch(v.trim())) {
                            return 'Ingrese un email válido';
                          }
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
