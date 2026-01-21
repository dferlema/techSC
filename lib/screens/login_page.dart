// lib/screens/login_page.dart

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/preferences_service.dart';
import '../utils/prefs.dart';
import '../utils/branding_helper.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _preferencesService = PreferencesService();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;
  bool _hasBiometricHardware = false;
  bool _isBiometricConfigured = false;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    final hasHardware = await _authService.isBiometricHardwareAvailable();
    final isConfigured = await _authService.isBiometricAuthEnabled();
    if (mounted) {
      setState(() {
        _hasBiometricHardware = hasHardware;
        _isBiometricConfigured = isConfigured;
      });
    }
  }

  // Cargar email guardado si "Recordarme" está activado
  Future<void> _loadSavedEmail() async {
    final rememberMe = await _preferencesService.getRememberMe();
    if (rememberMe) {
      final savedEmail = await _preferencesService.getSavedEmail();
      if (savedEmail != null && mounted) {
        setState(() {
          _emailController.text = savedEmail;
          _rememberMe = true;
        });
      }
    }
  }

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
        // 🛡️ Seguridad: Verificar si el correo está confirmado
        if (!user.emailVerified) {
          await authService.signOut();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'Por favor verifica tu correo electrónico antes de ingresar.',
                ),
                backgroundColor: Colors.orange,
                action: SnackBarAction(
                  label: 'Reenviar',
                  textColor: Colors.white,
                  onPressed: () async {
                    try {
                      await user.sendEmailVerification();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Correo de verificación enviado.'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
            );
          }
          return; // No permitir entrar si no está verificado
        }

        // Registrar inicio de sesión para el timeout de 10 min
        await AppPreferences().setSessionStart(DateTime.now());

        // Guardar email si "Recordarme" está marcado
        if (_rememberMe) {
          await _preferencesService.saveRememberMe(true);
          await _preferencesService.saveEmail(email);
        } else {
          await _preferencesService.clearSavedEmail();
        }

        // 🔐 Verificar si debemos ofrecer configurar biometría
        await _promptBiometricSetup(email, password);

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

  void _onBiometricLoginPressed() async {
    setState(() => _isLoading = true);
    try {
      final user = await _authService.loginWithBiometrics();
      if (user != null && mounted) {
        // Registrar inicio de sesión
        await AppPreferences().setSessionStart(DateTime.now());
        Navigator.pushReplacementNamed(context, '/main');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Pregunta al usuario si desea habilitar la autenticación biométrica
  Future<void> _promptBiometricSetup(String email, String password) async {
    try {
      // 1. Verificar si ya está habilitada
      final alreadyEnabled = await _authService.isBiometricAuthEnabled();
      if (alreadyEnabled) return;

      // 2. Verificar si el hardware biométrico está disponible
      if (!_hasBiometricHardware) return;

      // 3. Mostrar diálogo de confirmación
      if (mounted) {
        final shouldEnable = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.fingerprint, color: Colors.blue, size: 32),
                SizedBox(width: 12),
                Text('Habilitar Biometría'),
              ],
            ),
            content: const Text(
              '¿Deseas usar tu huella o rostro para iniciar sesión más rápido la próxima vez?\n\n'
              'Tus credenciales se guardarán de forma segura en el hardware de tu dispositivo.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Ahora no'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.check),
                label: const Text('Habilitar'),
              ),
            ],
          ),
        );

        // 4. Si acepta, guardar credenciales
        if (shouldEnable == true) {
          await _authService.saveCredentialsForBiometrics(email, password);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '✓ Biometría habilitada. Podrás usarla en tu próximo inicio de sesión.',
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          }
        }
      }
    } catch (e) {
      // Silenciosamente ignorar errores en la configuración biométrica
      // para no interrumpir el flujo de login
      debugPrint('Error al configurar biometría: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          BrandingHelper.appName,
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
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
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_forward,
                        color: Theme.of(context).colorScheme.primary,
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
                    Text(
                      'Accede a tu cuenta de ${BrandingHelper.appName}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
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
                          onChanged: (value) async {
                            setState(() {
                              _rememberMe = value ?? false;
                            });
                            // Si se desmarca, limpiar email guardado
                            if (!_rememberMe) {
                              await _preferencesService.clearSavedEmail();
                            }
                          },
                        ),
                        const Text('Recordarme'),
                        const Spacer(),
                        Flexible(
                          child: TextButton(
                            onPressed: () {
                              // Navegar a la página de recuperación de contraseña
                              Navigator.pushNamed(context, '/forgot-password');
                            },
                            child: Text(
                              '¿Olvidaste tu contraseña?',
                              textAlign: TextAlign.end,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Botón de Iniciar Sesión
                    ElevatedButton(
                      onPressed: _onLoginPressed,
                      style: ElevatedButton.styleFrom(
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

                    if (_hasBiometricHardware && _isBiometricConfigured)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: OutlinedButton.icon(
                          onPressed: _onBiometricLoginPressed,
                          icon: const Icon(Icons.fingerprint, size: 28),
                          label: const Text('Entrar con Biometría'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            minimumSize: const Size(double.infinity, 50),
                          ),
                        ),
                      ),

                    // Enlace de Registro
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('¿No tienes una cuenta? '),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/register');
                          },
                          child: Text(
                            'Regístrate aquí',
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
    );
  }
}
