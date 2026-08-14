import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tscomputer/core/theme/app_colors.dart';
import 'package:tscomputer/features/receipt/models/receipt_config_model.dart';
import 'package:tscomputer/features/receipt/services/receipt_service.dart';

class CompanySettingsPage extends StatefulWidget {
  const CompanySettingsPage({super.key});

  @override
  State<CompanySettingsPage> createState() => _CompanySettingsPageState();
}

class _CompanySettingsPageState extends State<CompanySettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _receiptService = ReceiptService();
  final _imagePicker = ImagePicker();

  late TextEditingController _nameCtrl;
  late TextEditingController _rucCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _footerCtrl;
  late TextEditingController _businessTypeCtrl;
  late TextEditingController _warrantyCtrl;

  // A4 Margins
  late TextEditingController _marginTopCtrl;
  late TextEditingController _marginBottomCtrl;
  late TextEditingController _marginLeftCtrl;
  late TextEditingController _marginRightCtrl;

  // Style
  String _primaryColor = '1565C0';
  bool _showLogo = true;
  bool _showRuc = true;
  bool _showAddress = true;
  bool _showPhone = true;
  bool _showEmail = true;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _logoUrl;
  Uint8List? _logoBytes;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _rucCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _footerCtrl = TextEditingController(text: 'Gracias por su preferencia');
    _businessTypeCtrl = TextEditingController();
    _warrantyCtrl = TextEditingController(text: '30 días sobre mano de obra. No cubre daños por líquidos.');
    _marginTopCtrl = TextEditingController(text: '20');
    _marginBottomCtrl = TextEditingController(text: '20');
    _marginLeftCtrl = TextEditingController(text: '15');
    _marginRightCtrl = TextEditingController(text: '15');
    _loadConfig();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _rucCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _footerCtrl.dispose();
    _businessTypeCtrl.dispose();
    _warrantyCtrl.dispose();
    _marginTopCtrl.dispose();
    _marginBottomCtrl.dispose();
    _marginLeftCtrl.dispose();
    _marginRightCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final config = await _receiptService.loadConfig();
    setState(() {
      _nameCtrl.text = config.companyName;
      _rucCtrl.text = config.ruc;
      _addressCtrl.text = config.address;
      _phoneCtrl.text = config.phone;
      _emailCtrl.text = config.email;
      _footerCtrl.text = config.receiptFooter ?? 'Gracias por su preferencia';
      _businessTypeCtrl.text = config.businessType ?? '';
      _warrantyCtrl.text = config.warrantyDefault ?? '30 días sobre mano de obra. No cubre daños por líquidos.';
      _marginTopCtrl.text = config.a4Margins.top.toString();
      _marginBottomCtrl.text = config.a4Margins.bottom.toString();
      _marginLeftCtrl.text = config.a4Margins.left.toString();
      _marginRightCtrl.text = config.a4Margins.right.toString();
      _primaryColor = config.style.primaryColor;
      _showLogo = config.style.showLogo;
      _showRuc = config.style.showRuc;
      _showAddress = config.style.showAddress;
      _showPhone = config.style.showPhone;
      _showEmail = config.style.showEmail;
      _logoUrl = config.logoUrl;
      _isLoading = false;
    });
  }

  Future<void> _pickLogo() async {
    final picked = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _logoBytes = bytes;
    });
  }

  Future<String?> _uploadLogo() async {
    if (_logoBytes == null) return _logoUrl;
    try {
      final ref = FirebaseStorage.instance.ref().child('company/logo.jpg');
      await ref.putData(_logoBytes!, SettableMetadata(contentType: 'image/jpeg'));
      return await ref.getDownloadURL();
    } catch (e) {
      debugPrint('Error uploading logo: $e');
      return _logoUrl;
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final logoUrl = await _uploadLogo();

      final config = ReceiptConfigModel(
        companyName: _nameCtrl.text.trim(),
        ruc: _rucCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        logoUrl: logoUrl,
        receiptFooter: _footerCtrl.text.trim(),
        businessType: _businessTypeCtrl.text.trim().isEmpty ? null : _businessTypeCtrl.text.trim(),
        warrantyDefault: _warrantyCtrl.text.trim().isEmpty ? null : _warrantyCtrl.text.trim(),
        a4Margins: A4Margins(
          top: double.tryParse(_marginTopCtrl.text) ?? 20,
          bottom: double.tryParse(_marginBottomCtrl.text) ?? 20,
          left: double.tryParse(_marginLeftCtrl.text) ?? 15,
          right: double.tryParse(_marginRightCtrl.text) ?? 15,
        ),
        style: ReceiptStyle(
          primaryColor: _primaryColor,
          showLogo: _showLogo,
          showRuc: _showRuc,
          showAddress: _showAddress,
          showPhone: _showPhone,
          showEmail: _showEmail,
        ),
      );

      await _receiptService.saveConfig(config);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Configuración guardada')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurar Recibos'),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.save),
            onPressed: _isSaving ? null : _save,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Logo
                  _buildSectionTitle('Logo de la Empresa'),
                  const SizedBox(height: 8),
                  Center(
                    child: GestureDetector(
                      onTap: _pickLogo,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: _logoBytes != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.memory(_logoBytes!, fit: BoxFit.cover),
                              )
                            : _logoUrl != null && _logoUrl!.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.network(_logoUrl!, fit: BoxFit.cover),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.add_a_photo, size: 32, color: Colors.grey[400]),
                                      const SizedBox(height: 8),
                                      Text('Subir Logo', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                                    ],
                                  ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Datos de la empresa
                  _buildSectionTitle('Datos de la Empresa'),
                  const SizedBox(height: 8),
                  _buildTextField(_nameCtrl, 'Nombre de la Empresa', Icons.business),
                  const SizedBox(height: 12),
                  _buildTextField(_rucCtrl, 'RUC', Icons.badge_outlined),
                  const SizedBox(height: 12),
                  _buildTextField(_addressCtrl, 'Dirección', Icons.location_on),
                  const SizedBox(height: 12),
                  _buildTextField(_phoneCtrl, 'Teléfono', Icons.phone),
                  const SizedBox(height: 12),
                  _buildTextField(_emailCtrl, 'Email', Icons.email),
                  const SizedBox(height: 12),
                  _buildTextField(_footerCtrl, 'Mensaje del Pie de Página', Icons.text_snippet),
                  const SizedBox(height: 12),
                  _buildTextField(_businessTypeCtrl, 'Tipo de Negocio (ej: Taller Técnico)', Icons.category),
                  const SizedBox(height: 12),
                  _buildTextField(_warrantyCtrl, 'Texto de Garantía por Defecto', Icons.verified, maxLines: 2),
                  const SizedBox(height: 24),

                  // Márgenes A4
                  _buildSectionTitle('Márgenes A4 (mm)'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: _buildTextField(_marginTopCtrl, 'Superior', Icons.arrow_upward, isNumber: true)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildTextField(_marginBottomCtrl, 'Inferior', Icons.arrow_downward, isNumber: true)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildTextField(_marginLeftCtrl, 'Izquierdo', Icons.arrow_back, isNumber: true)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildTextField(_marginRightCtrl, 'Derecho', Icons.arrow_forward, isNumber: true)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Estilo
                  _buildSectionTitle('Estilo del Recibo'),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Mostrar Logo', style: TextStyle(fontSize: 14)),
                    value: _showLogo,
                    onChanged: (v) => setState(() => _showLogo = v),
                    secondary: const Icon(Icons.image, size: 20),
                  ),
                  SwitchListTile(
                    title: const Text('Mostrar RUC', style: TextStyle(fontSize: 14)),
                    value: _showRuc,
                    onChanged: (v) => setState(() => _showRuc = v),
                    secondary: const Icon(Icons.badge_outlined, size: 20),
                  ),
                  SwitchListTile(
                    title: const Text('Mostrar Dirección', style: TextStyle(fontSize: 14)),
                    value: _showAddress,
                    onChanged: (v) => setState(() => _showAddress = v),
                    secondary: const Icon(Icons.location_on, size: 20),
                  ),
                  SwitchListTile(
                    title: const Text('Mostrar Teléfono', style: TextStyle(fontSize: 14)),
                    value: _showPhone,
                    onChanged: (v) => setState(() => _showPhone = v),
                    secondary: const Icon(Icons.phone, size: 20),
                  ),
                  SwitchListTile(
                    title: const Text('Mostrar Email', style: TextStyle(fontSize: 14)),
                    value: _showEmail,
                    onChanged: (v) => setState(() => _showEmail = v),
                    secondary: const Icon(Icons.email, size: 20),
                  ),
                  const SizedBox(height: 24),

                  // Color primario
                  _buildSectionTitle('Color Primario'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _colorOption('1565C0', Colors.blue[800]!),
                      _colorOption('2E7D32', Colors.green[800]!),
                      _colorOption('C62828', Colors.red[800]!),
                      _colorOption('6A1B9A', Colors.purple[800]!),
                      _colorOption('E65100', Colors.orange[800]!),
                      _colorOption('00838F', Colors.teal[800]!),
                      _colorOption('37474F', Colors.blueGrey[800]!),
                      _colorOption('000000', Colors.black),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.primaryBlue,
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {bool isNumber = false, int maxLines = 1}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
    );
  }

  Widget _colorOption(String hex, Color color) {
    final isSelected = _primaryColor == hex;
    return GestureDetector(
      onTap: () => setState(() => _primaryColor = hex),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 3,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8)]
              : null,
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white, size: 20)
            : null,
      ),
    );
  }
}
