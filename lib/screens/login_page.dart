// lib/screens/login_page.dart

import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
    });
  }

  bool _isLoading = false;

  void _onLoginPressed() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa correo y contraseña')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = AuthService();
      final user = await authService.loginWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (user != null && mounted) {
        Navigator.pushReplacementNamed(context, '/main');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1976D2),
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Ícono grande circular
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward,
                        color: Color(0xFF1976D2),
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Título y subtítulo
                    const Text(
                      'Iniciar Sesión',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Accede a tu cuenta de TechService Pro',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    const SizedBox(height: 32),

                    // Campo Correo Electrónico
                    TextField(
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
                    ),
                    const SizedBox(height: 20),

                    // Campo Contraseña
                    TextField(
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
                    ),
                    const SizedBox(height: 16),

                    // Recordarme + ¿Olvidaste tu contraseña?
                    Row(
                      children: [
                        Checkbox(
                          value: _rememberMe,
                          onChanged: (value) {
                            setState(() {
                              _rememberMe = value ?? false;
                            });
                          },
                        ),
                        const Text('Recordarme'),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            // Acción para recuperar contraseña
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Funcionalidad en desarrollo'),
                              ),
                            );
                          },
                          child: const Text(
                            '¿Olvidaste tu contraseña?',
                            style: TextStyle(color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Botón de Iniciar Sesión
                    ElevatedButton(
                      onPressed: _onLoginPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1976D2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Iniciar Sesión',
                              style: TextStyle(fontSize: 18),
                            ),
                    ),
                    const SizedBox(height: 20),

                    // Enlace de Registro
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('¿No tienes una cuenta? '),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/register');
                          },
                          child: const Text(
                            'Regístrate aquí',
                            style: TextStyle(
                              color: Colors.blue,
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
    );
  }
}
