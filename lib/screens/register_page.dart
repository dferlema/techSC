// lib/screens/register_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart'; // ✅ Necesario para TapGestureRecognizer

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

  late TapGestureRecognizer _termsRecognizer;
  late TapGestureRecognizer _privacyRecognizer;

  @override
  void initState() {
    super.initState();
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Abriendo términos y condiciones...')),
        );
      };
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Abriendo política de privacidad...')),
        );
      };
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

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  void _toggleConfirmPasswordVisibility() {
    setState(() {
      _obscureConfirmPassword = !_obscureConfirmPassword;
    });
  }

  final bool _isLoading = false;

  void _onRegisterPressed() async {
    if (_formKey.currentState!.validate()) {
      // Validación cruzada de contraseñas
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Las contraseñas no coinciden')),
        );
        return;
      }

      if (!_acceptTerms) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Debes aceptar los términos')),
        );
        return;
      }

      // 🌀 Mostrar indicador de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        // ✅ Registrar en Firebase
        final user = await _authService.registerWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          name: _nameController.text.trim(),
          id: _idController.text.trim(),
          phone: _phoneController.text.trim(),
          address: _addressController.text.trim(),
        );

        if (user != null) {
          Navigator.pop(context); // Cierra el loading
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('¡Registro exitoso!')));

          // 👉 Navegar a Home
          Navigator.pushReplacementNamed(context, '/main');
        }
      } on String catch (message) {
        Navigator.pop(context); // Cierra el loading
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('⚠️ $message')));
      } catch (e) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Error al registrar. Inténtalo de nuevo.'),
          ),
        );
      }
    }
  }

  // 🔢 Función para validar cédula ecuatoriana (algoritmo oficial)
  bool isValidEcuadorianId(String id) {
    if (id.length != 10 || !RegExp(r'^\d{10}$').hasMatch(id)) return false;

    final digits = id.split('').map(int.parse).toList();
    final province = digits[0] * 10 + digits[1];
    if (province < 1 || province > 24) {
      return false; // Provincias válidas: 01-24
    }

    // Algoritmo de verificación (módulo 10)
    int sum = 0;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(Icons.computer, color: Colors.white),
            const SizedBox(width: 8),
            Text('TechService Pro', style: TextStyle(color: Colors.white)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.menu, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Menú presionado')));
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 400),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person_add,
                          color: Theme.of(context).colorScheme.primary,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 24),

                      const Text(
                        'Crear Cuenta',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Únete a TechService Pro y accede a servicios exclusivos',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                      const SizedBox(height: 32),

                      // Nombre completo
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.person),
                          labelText: 'Nombre Completo',
                          hintText: 'Ej. Diego Lema',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Por favor ingresa tu nombre';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Cédula (antes del correo, por ser dato identificatorio)
                      TextFormField(
                        controller: _idController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.badge),
                          labelText: 'Cédula',
                          hintText: '1798745823',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'La cédula es obligatoria';
                          }
                          if (value.length != 10) {
                            return 'La cédula debe tener 10 dígitos';
                          }
                          if (!isValidEcuadorianId(value)) {
                            return 'Cédula ecuatoriana inválida';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Teléfono
                      TextFormField(
                        controller: _phoneController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.phone),
                          labelText: 'Teléfono',
                          hintText: '0991234567',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'El teléfono es obligatorio';
                          }
                          if (value.length != 10) {
                            return 'El teléfono debe tener 10 dígitos';
                          }
                          if (!value.startsWith('09')) {
                            return 'El teléfono debe empezar con 09';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Dirección
                      TextFormField(
                        controller: _addressController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.location_on),
                          labelText: 'Dirección',
                          hintText: 'Ej. Av. Amazonas y Naciones Unidas',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        maxLines: 2,
                        keyboardType: TextInputType.streetAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'La dirección es obligatoria';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Correo electrónico
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.email),
                          labelText: 'Correo Electrónico',
                          hintText: 'tu@email.com',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Correo es obligatorio';
                          }
                          if (!RegExp(
                            r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                          ).hasMatch(value)) {
                            return 'Formato de correo inválido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Contraseña
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.lock),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.grey,
                            ),
                            onPressed: _togglePasswordVisibility,
                          ),
                          labelText: 'Contraseña',
                          hintText: '••••••••',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Contraseña es obligatoria';
                          }
                          if (value.length < 6) {
                            return 'Mínimo 6 caracteres';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Confirmar contraseña
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.grey,
                            ),
                            onPressed: _toggleConfirmPasswordVisibility,
                          ),
                          labelText: 'Confirmar Contraseña',
                          hintText: '••••••••',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Confirmación es obligatoria';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Checkbox: Términos
                      Row(
                        children: [
                          Checkbox(
                            value: _acceptTerms,
                            onChanged: (value) {
                              setState(() {
                                _acceptTerms = value ?? false;
                              });
                            },
                          ),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                text: 'Acepto los ',
                                style: const TextStyle(
                                  color: Colors.black87,
                                  fontSize: 14,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'términos y condiciones',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: _termsRecognizer,
                                  ),
                                  const TextSpan(text: ' y la '),
                                  TextSpan(
                                    text: 'política de privacidad',
                                    style: TextStyle(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: _privacyRecognizer,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Botón de Registro
                      ElevatedButton(
                        onPressed: _onRegisterPressed,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'Registrarse',
                                style: TextStyle(fontSize: 18),
                              ),
                      ),
                      const SizedBox(height: 20),

                      // Enlace a login
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('¿Ya tienes una cuenta? '),
                          TextButton(
                            onPressed: () {
                              Navigator.pushReplacementNamed(context, '/login');
                            },
                            child: Text(
                              'Inicia sesión',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
