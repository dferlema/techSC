import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Pagina de formulario para crear o editar clientes.
/// Incluye validaciones específicas para cédula y teléfono de Ecuador.
class ClientFormPage extends StatefulWidget {
  final String? clientId;
  final Map<String, dynamic>? initialData;

  const ClientFormPage({super.key, this.clientId, this.initialData});

  @override
  State<ClientFormPage> createState() => _ClientFormPageState();
}

class _ClientFormPageState extends State<ClientFormPage> {
  final _formKey = GlobalKey<FormState>();

  // Controladores para los campos de texto
  late TextEditingController _idController;
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _companyNameController;

  late String _clientType;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    // Inicializar controladores con datos existentes si es edición
    _idController = TextEditingController(
      text: widget.initialData?['id'] ?? '',
    );
    _nameController = TextEditingController(
      text: widget.initialData?['name'] ?? '',
    );
    _emailController = TextEditingController(
      text: widget.initialData?['email'] ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.initialData?['phone'] ?? '',
    );
    _addressController = TextEditingController(
      text: widget.initialData?['address'] ?? '',
    );
    _companyNameController = TextEditingController(
      text: widget.initialData?['companyName'] ?? '',
    );
    _clientType = widget.initialData?['type'] ?? 'particular';
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _companyNameController.dispose();
    super.dispose();
  }

  // 🔢 Validación de cédula ecuatoriana
  // Verifica longitud, provincia y dígito verificador.
  bool _isValidEcuadorianId(String id) {
    if (id.length != 10 || !RegExp(r'^\d{10}$').hasMatch(id)) return false;
    final digits = id.split('').map(int.parse).toList();
    final province = digits[0] * 10 + digits[1];

    // Validar código de provincia (1-24)
    if (province < 1 || province > 24) return false;

    int sum = 0;
    // Algoritmo de validación del último dígito (módulo 10)
    for (int i = 0; i < 9; i++) {
      int digit = digits[i];
      if (i % 2 == 0) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
    }
    final verifier = (sum % 10 == 0) ? 0 : 10 - (sum % 10);
    return verifier == digits[9];
  }

  // 📱 Validación de teléfono ecuatoriano
  bool _isValidEcuadorianPhone(String phone) {
    return phone.length == 10 &&
        phone.startsWith('09') &&
        RegExp(r'^\d{10}$').hasMatch(phone);
  }

  // 💾 Guardar cliente
  // Valida todos los campos antes de guardar en Firestore.
  Future<void> _saveClient() async {
    if (!_formKey.currentState!.validate()) return;

    final id = _idController.text.trim();
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final address = _addressController.text.trim();
    final companyName = _companyNameController.text.trim();

    // Validaciones manuales adicionales
    if (id.isEmpty || !_isValidEcuadorianId(id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cédula ecuatoriana inválida')),
      );
      return;
    }

    if (name.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nombre completo requerido (mín. 5 caracteres)'),
        ),
      );
      return;
    }

    if (email.isEmpty ||
        !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Correo electrónico inválido')),
      );
      return;
    }

    if (phone.isEmpty || !_isValidEcuadorianPhone(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Teléfono ecuatoriano inválido (debe ser 09XXXXXXXX)'),
        ),
      );
      return;
    }

    if (address.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Dirección es obligatoria')));
      return;
    }

    if (_clientType == 'empresa' && companyName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nombre de empresa es obligatorio')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final clientData = {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'address': address,
        'type': _clientType,
        if (_clientType == 'empresa') 'companyName': companyName,
        'role': 'cliente',
        if (widget.clientId == null) 'createdAt': FieldValue.serverTimestamp(),
      };

      final db = FirebaseFirestore.instance;
      if (widget.clientId == null) {
        // ✅ Crear nuevo cliente en colección 'users'
        await db.collection('users').add(clientData);
      } else {
        // ✏️ Actualizar cliente existente
        await db.collection('users').doc(widget.clientId).update(clientData);
      }

      Navigator.pop(context, true); // Éxito
    } catch (e) {
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
          widget.clientId == null ? 'Nuevo Cliente' : 'Editar Cliente',
        ),
        actions: [
          IconButton(
            icon: _isSaving
                ? const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  )
                : const Icon(Icons.check, color: Colors.white),
            onPressed: _isSaving ? null : _saveClient,
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
                    // 📇 Cédula
                    TextFormField(
                      controller: _idController,
                      decoration: InputDecoration(
                        labelText: 'Cédula *',
                        hintText: 'Ej: 1716472038',
                        prefixIcon: const Icon(Icons.badge),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Obligatorio';
                        }
                        if (value.trim().length != 10) return '10 dígitos';
                        if (!_isValidEcuadorianId(value.trim())) {
                          return 'Cédula inválida';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // 👤 Nombre completo
                    TextFormField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Nombre Completo *',
                        hintText: 'Ej: Diego Fernando Lema',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Obligatorio';
                        }
                        if (value.trim().length < 5) return 'Mín. 5 caracteres';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // 📧 Correo
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Correo Electrónico *',
                        hintText: 'tu@email.com',
                        prefixIcon: const Icon(Icons.email),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Obligatorio';
                        }
                        if (!RegExp(
                          r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                        ).hasMatch(value.trim())) {
                          return 'Formato inválido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // 📱 Teléfono
                    TextFormField(
                      controller: _phoneController,
                      decoration: InputDecoration(
                        labelText: 'Teléfono *',
                        hintText: '09XXXXXXXX',
                        prefixIcon: const Icon(Icons.phone),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Obligatorio';
                        }
                        if (!_isValidEcuadorianPhone(value.trim())) {
                          return 'Teléfono ecuatoriano inválido';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // 📍 Dirección
                    TextFormField(
                      controller: _addressController,
                      decoration: InputDecoration(
                        labelText: 'Dirección *',
                        hintText: 'Ej: Av. Amazonas y Naciones Unidas',
                        prefixIcon: const Icon(Icons.location_on),
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Obligatorio'
                          : null,
                    ),
                    const SizedBox(height: 20),

                    // 🏢 Tipo de cliente
                    DropdownButtonFormField<String>(
                      initialValue: _clientType,
                      decoration: InputDecoration(
                        labelText: 'Tipo de Cliente *',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: 'particular',
                          child: Text('Particular'),
                        ),
                        const DropdownMenuItem(
                          value: 'empresa',
                          child: Text('Empresa'),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _clientType = value!),
                      validator: (value) =>
                          value == null ? 'Selecciona un tipo' : null,
                    ),
                    const SizedBox(height: 20),

                    // 🏢 Nombre empresa (solo si es empresa)
                    if (_clientType == 'empresa')
                      TextFormField(
                        controller: _companyNameController,
                        decoration: InputDecoration(
                          labelText: 'Nombre de la Empresa *',
                          hintText: 'Ej: TechService Pro Cía. Ltda.',
                          prefixIcon: const Icon(Icons.business),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Obligatorio'
                            : null,
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
