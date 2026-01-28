import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:techsc/core/models/config_model.dart';
import 'package:techsc/core/services/config_service.dart';
import 'package:techsc/features/auth/services/auth_service.dart';
import 'package:techsc/core/services/role_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:techsc/core/widgets/cart_badge.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _currentIndex = 0;
  final ConfigService _configService = ConfigService();
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  // Company Info Controllers
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;

  bool _isLoading = false;
  bool _isBiometricEnabled = false;
  bool _isAdmin = false;
  bool _checkingRole = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
    _loadCurrentConfig();
    _loadBiometricStatus();
    _checkRole();
  }

  Future<void> _checkRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final role = await RoleService().getUserRole(user.uid);
      if (mounted) {
        setState(() {
          _isAdmin = role == RoleService.ADMIN;
          _checkingRole = false;
        });
      }
    } else {
      if (mounted) setState(() => _checkingRole = false);
    }
  }

  Future<void> _loadBiometricStatus() async {
    final enabled = await _authService.isBiometricAuthEnabled();
    setState(() {
      _isBiometricEnabled = enabled;
    });
  }

  Future<void> _toggleBiometrics(bool value) async {
    if (value) {
      // No permitimos habilitar desde aquí, solo desde el login
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Para habilitar la biometría, cierra sesión e inicia sesión manualmente. '
              'Se te preguntará si deseas activarla.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }
      setState(() => _isBiometricEnabled = false);
    } else {
      // Deshabilitar biometría
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Deshabilitar Biometría'),
          content: const Text(
            '¿Estás seguro de que deseas deshabilitar el inicio de sesión biométrico?\n\n'
            'Tendrás que iniciar sesión manualmente la próxima vez.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Deshabilitar'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        await _authService.disableBiometrics();
        setState(() => _isBiometricEnabled = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Inicio de sesión biométrico desactivado.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else {
        setState(() => _isBiometricEnabled = true);
      }
    }
  }

  Future<void> _loadCurrentConfig() async {
    final config = await _configService.getConfig();
    setState(() {
      _nameController.text = config.companyName;
      _emailController.text = config.companyEmail;
      _phoneController.text = config.companyPhone;
      _addressController.text = config.companyAddress;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveCompanyInfo() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final config = ConfigModel(
        companyName: _nameController.text.trim(),
        companyEmail: _emailController.text.trim(),
        companyPhone: _phoneController.text.trim(),
        companyAddress: _addressController.text.trim(),
      );
      await _configService.updateConfig(config);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Información actualizada correctamente'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addBanner() async {
    final TextEditingController urlController = TextEditingController();
    final String? imageUrl = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar Banner por URL'),
        content: TextField(
          controller: urlController,
          decoration: const InputDecoration(
            hintText: 'https://ejemplo.com/imagen.jpg',
            labelText: 'URL de la imagen',
          ),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, urlController.text.trim()),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );

    if (imageUrl != null && imageUrl.isNotEmpty) {
      setState(() => _isLoading = true);
      try {
        await _configService.addBannerByUrl(imageUrl);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Banner agregado correctamente')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al agregar banner: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteBanner(String docId, String imageUrl) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Banner'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar este banner?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _configService.deleteBanner(docId, imageUrl);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Banner eliminado correctamente')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar banner: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_checkingRole) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // If not admin, show only security settings
    if (!_isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Configuraciones'),
          actions: const [CartBadge(), SizedBox(width: 8)],
        ),
        body: _buildSecurityTab(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacementNamed('/main');
            }
          },
        ),
        title: const Text('Configuraciones'),
        actions: const [CartBadge(), SizedBox(width: 8)],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildCompanyInfoTab(),
          _buildBannersTab(),
          _buildSecurityTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.business_outlined),
            selectedIcon: Icon(Icons.business),
            label: 'Información',
          ),
          NavigationDestination(
            icon: Icon(Icons.image_outlined),
            selectedIcon: Icon(Icons.image),
            label: 'Banners',
          ),
          NavigationDestination(
            icon: Icon(Icons.security_outlined),
            selectedIcon: Icon(Icons.security),
            label: 'Seguridad',
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyInfoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildTextField(
              controller: _nameController,
              label: 'Nombre de la Empresa',
              icon: Icons.store,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _emailController,
              label: 'Correo Electrónico',
              icon: Icons.email,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _phoneController,
              label: 'Teléfono (WhatsApp, sin +)',
              icon: Icons.phone,
              keyboardType: TextInputType.phone,
              helperText: 'Ej: 593991090805',
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _addressController,
              label: 'Dirección',
              icon: Icons.location_on,
              maxLines: 2,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveCompanyInfo,
                icon: const Icon(Icons.save),
                label: const Text('Guardar Cambios'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? helperText,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        helperText: helperText,
      ),
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Este campo es requerido';
        }
        return null;
      },
    );
  }

  Widget _buildBannersTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: _addBanner,
            icon: const Icon(Icons.add_photo_alternate),
            label: const Text('Agregar Nuevo Banner'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: _configService.getBannersStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No hay banners configurados'));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: snapshot.data!.docs.length,
                itemBuilder: (context, index) {
                  final doc = snapshot.data!.docs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final imageUrl = data['imageUrl'] as String;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 3,
                    child: Stack(
                      children: [
                        Image.network(
                          imageUrl,
                          height: 150,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 150,
                            color: Colors.grey[200],
                            child: const Icon(Icons.broken_image),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: CircleAvatar(
                            backgroundColor: Colors.white,
                            child: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteBanner(doc.id, imageUrl),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              ListTile(
                leading: Icon(
                  Icons.fingerprint,
                  size: 32,
                  color: _isBiometricEnabled ? Colors.green : Colors.grey,
                ),
                title: const Text('Inicio de Sesión Biométrico'),
                subtitle: Text(
                  _isBiometricEnabled
                      ? 'Habilitado - Puedes iniciar sesión con tu huella o rostro'
                      : 'Deshabilitado - Inicia sesión manualmente para habilitar',
                ),
                trailing: Switch(
                  value: _isBiometricEnabled,
                  onChanged: _toggleBiometrics,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Text(
                  _isBiometricEnabled
                      ? 'Para deshabilitar, apaga el interruptor arriba.'
                      : 'Para habilitar la biometría, cierra sesión e inicia sesión manualmente. Se te preguntará si deseas activarla.',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }
}
