import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:tscomputer/features/auth/services/auth_service.dart';
import 'package:tscomputer/core/utils/branding_helper.dart';
import 'package:tscomputer/core/utils/validators.dart';
import 'package:tscomputer/core/theme/app_colors.dart';
import 'package:tscomputer/l10n/app_localizations.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _idController = TextEditingController();
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;
  bool _isLoading = false;

  late TapGestureRecognizer _termsRecognizer;
  late TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()..onTap = () => Navigator.pushNamed(context, '/legal', arguments: 0);
    _privacyRecognizer = TapGestureRecognizer()..onTap = () => Navigator.pushNamed(context, '/legal', arguments: 1);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _idController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    super.dispose();
  }

  void _onRegisterPressed() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Las contraseñas no coinciden')));
      return;
    }
    if (!_acceptTerms) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debes aceptar los términos')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = await _authService.registerWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        name: _nameController.text.trim(),
        id: _idController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
      );
      if (user != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.emailSentSuccess)));
        Navigator.pushReplacementNamed(context, '/main');
      }
    } on String catch (message) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('⚠️ $message')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context)!.errorLoading)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = kIsWeb && screenWidth > 800;

    if (isWide) {
      return _buildWideLayout();
    }
    return _buildMobileLayout();
  }

  Widget _buildWideLayout() {
    return Scaffold(
      body: Row(
        children: [
          // Left panel - Branding
          Expanded(
            flex: 5,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0D1B2A), Color(0xFF1B2838), Color(0xFF0D1B2A)],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -120,
                    right: -120,
                    child: Container(
                      width: 400,
                      height: 400,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryBlue.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(60),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [AppColors.primaryBlue, AppColors.primaryBlue.withValues(alpha: 0.7)],
                              ),
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryBlue.withValues(alpha: 0.4),
                                  blurRadius: 40,
                                  offset: const Offset(0, 16),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 50),
                          ),
                          const SizedBox(height: 40),
                          Text(
                            'Únete a',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 18, fontWeight: FontWeight.w300),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            BrandingHelper.appName,
                            style: const TextStyle(color: Colors.white, fontSize: 42, fontWeight: FontWeight.w800, letterSpacing: -1),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Crea tu cuenta y accede a nuestros servicios\nde reparación y mantenimiento tecnológico.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 16, height: 1.6),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Right panel - Register form
          Expanded(
            flex: 5,
            child: Container(
              color: const Color(0xFFF8F9FC),
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 40),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: _buildRegisterForm(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      appBar: AppBar(
        title: Text(BrandingHelper.appName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF0D1B2A),
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF8F9FC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: _buildRegisterForm(),
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Crear Cuenta', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: 8),
          Text('Completa tus datos para registrarte', style: TextStyle(color: const Color(0xFF6B7280), fontSize: 14)),
          const SizedBox(height: 32),

          _fieldLabel('Nombre Completo'),
          const SizedBox(height: 8),
          _textFormField(
            controller: _nameController,
            hint: 'Ej. Diego Lema',
            icon: Icons.person_outline_rounded,
            validator: (v) => v!.trim().isEmpty ? 'Por favor ingresa tu nombre' : null,
          ),
          const SizedBox(height: 18),

          _fieldLabel('Cédula o RUC'),
          const SizedBox(height: 8),
          _textFormField(
            controller: _idController,
            hint: 'Ingrese su identificación',
            icon: Icons.badge_outlined,
            keyboard: TextInputType.number,
            formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(13)],
            validator: (v) {
              if (v == null || v.isEmpty) return 'La identificación es obligatoria';
              if (!Validators.isValidEcuadorianId(v)) return 'Cédula o RUC inválido';
              return null;
            },
          ),
          const SizedBox(height: 18),

          _fieldLabel('Teléfono'),
          const SizedBox(height: 8),
          _textFormField(
            controller: _phoneController,
            hint: '0991234567',
            icon: Icons.phone_outlined,
            keyboard: TextInputType.phone,
            formatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) {
              if (v == null || v.isEmpty) return 'El teléfono es obligatorio';
              if (v.length != 10) return 'El teléfono debe tener 10 dígitos';
              if (!v.startsWith('09')) return 'El teléfono debe empezar con 09';
              return null;
            },
          ),
          const SizedBox(height: 18),

          _fieldLabel('Dirección'),
          const SizedBox(height: 8),
          _textFormField(
            controller: _addressController,
            hint: 'Ej. Av. Amazonas y Naciones Unidas',
            icon: Icons.location_on_outlined,
            maxLines: 2,
            keyboard: TextInputType.streetAddress,
            validator: (v) => v!.trim().isEmpty ? 'La dirección es obligatoria' : null,
          ),
          const SizedBox(height: 18),

          _fieldLabel('Correo Electrónico'),
          const SizedBox(height: 8),
          _textFormField(
            controller: _emailController,
            hint: 'tu@email.com',
            icon: Icons.email_outlined,
            keyboard: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Correo es obligatorio';
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) return 'Formato de correo inválido';
              return null;
            },
          ),
          const SizedBox(height: 18),

          _fieldLabel('Contraseña'),
          const SizedBox(height: 8),
          _textFormField(
            controller: _passwordController,
            hint: '••••••••',
            icon: Icons.lock_outline,
            obscure: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Contraseña es obligatoria';
              if (v.length < 6) return 'Mínimo 6 caracteres';
              return null;
            },
          ),
          const SizedBox(height: 18),

          _fieldLabel('Confirmar Contraseña'),
          const SizedBox(height: 8),
          _textFormField(
            controller: _confirmPasswordController,
            hint: '••••••••',
            icon: Icons.lock_outline,
            obscure: _obscureConfirmPassword,
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
            ),
            validator: (v) => v!.isEmpty ? AppLocalizations.of(context)!.confirmPasswordLabel : null,
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: Checkbox(
                  value: _acceptTerms,
                  onChanged: (v) => setState(() => _acceptTerms = v ?? false),
                  activeColor: AppColors.primaryBlue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    text: 'Acepto los ',
                    style: TextStyle(color: const Color(0xFF6B7280), fontSize: 13),
                    children: [
                      TextSpan(
                        text: 'Términos y Condiciones',
                        style: TextStyle(color: AppColors.primaryBlue, decoration: TextDecoration.underline),
                        recognizer: _termsRecognizer,
                      ),
                      const TextSpan(text: ' y la '),
                      TextSpan(
                        text: 'Política de Privacidad',
                        style: TextStyle(color: AppColors.primaryBlue, decoration: TextDecoration.underline),
                        recognizer: _privacyRecognizer,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _onRegisterPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.primaryBlue.withValues(alpha: 0.5),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Text('Crear Cuenta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 24),

          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('¿Ya tienes cuenta? ', style: TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
                GestureDetector(
                  onTap: () => Navigator.pushReplacementNamed(context, '/login'),
                  child: Text(
                    'Inicia sesión',
                    style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _fieldLabel(String label) {
    return Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1F36)));
  }

  Widget _textFormField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
    bool obscure = false,
    Widget? suffixIcon,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      inputFormatters: formatters,
      obscureText: obscure,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF), size: 20),
        suffixIcon: suffixIcon != null ? IconTheme(data: const IconThemeData(color: Color(0xFF9CA3AF)), child: suffixIcon) : null,
        filled: true,
        fillColor: const Color(0xFFF3F4F6),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.error, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
