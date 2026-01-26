import 'package:flutter/material.dart';
import 'dart:ui'; // Necesario para ImageFilter
import '../services/auth_service.dart';
import '../services/preferences_service.dart';
import '../utils/prefs.dart';
import '../utils/branding_helper.dart';
import '../theme/app_colors.dart';

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
                backgroundColor: AppColors.warning,
                action: SnackBarAction(
                  label: 'Reenviar',
                  textColor: AppColors.white,
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
                            backgroundColor: AppColors.error,
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
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
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
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
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
              SnackBar(
                content: Text(
                  '✓ Biometría habilitada. Podrás usarla en tu próximo inicio de sesión.',
                ),
                backgroundColor: AppColors.success,
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
    // Colores base
    final primaryColor = AppColors.primaryBlue;
    final accentColor = AppColors.accentOrange;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Transparente total
        elevation: 0,
        automaticallyImplyLeading: false, // Sin botón de atrás
      ),
      body: Stack(
        children: [
          // 1. Fondo con Gradiente y Formas (Blobs)
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [primaryColor, AppColors.primaryDark, Colors.black87],
              ),
            ),
          ),
          // Decoración: Círculo brillante arriba izquierda
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withOpacity(0.4),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.4),
                    blurRadius: 100,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          // Decoración: Círculo brillante abajo derecha
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blueAccent.withOpacity(0.3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blueAccent.withOpacity(0.3),
                    blurRadius: 100,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),
          ),

          // 2. Contenido con Efecto Glass
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Header: Logo y Texto (Fuera del glass para limpieza)
                  Icon(
                    Icons.admin_panel_settings_outlined, // Icono Premium
                    size: 60,
                    color: AppColors.white,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    BrandingHelper.appName,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.white,
                      letterSpacing: 1.5,
                      shadows: [
                        Shadow(
                          offset: Offset(0, 2),
                          blurRadius: 4.0,
                          color: Colors.black26,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bienvenido de nuevo',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.white.withOpacity(0.8),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // TARJETA DE CRISTAL (Glassmorphism)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: AppColors.white.withOpacity(
                            0.1,
                          ), // Translucidez
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.white.withOpacity(0.2),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Campo Email
                            TextFormField(
                              controller: _emailController,
                              style: TextStyle(color: AppColors.white),
                              decoration: InputDecoration(
                                labelText: 'Correo Electrónico',
                                labelStyle: TextStyle(
                                  color: AppColors.white.withOpacity(0.8),
                                ),
                                prefixIcon: Icon(
                                  Icons.email_outlined,
                                  color: AppColors.white.withOpacity(0.9),
                                ),
                                filled: true,
                                fillColor: AppColors.white.withOpacity(0.1),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 20,
                                ),
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 20),

                            // Campo Password
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              style: TextStyle(color: AppColors.white),
                              decoration: InputDecoration(
                                labelText: 'Contraseña',
                                labelStyle: TextStyle(
                                  color: AppColors.white.withOpacity(0.8),
                                ),
                                prefixIcon: Icon(
                                  Icons.lock_outline,
                                  color: AppColors.white.withOpacity(0.9),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility,
                                    color: AppColors.white.withOpacity(0.7),
                                  ),
                                  onPressed: _togglePasswordVisibility,
                                ),
                                filled: true,
                                fillColor: AppColors.white.withOpacity(0.1),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 20,
                                ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Opciones: Recordarme / Olvidaste
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Theme(
                                      data: ThemeData(
                                        unselectedWidgetColor: Colors.white70,
                                      ),
                                      child: Checkbox(
                                        value: _rememberMe,
                                        checkColor: primaryColor,
                                        activeColor: AppColors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        onChanged: (value) async {
                                          setState(
                                            () => _rememberMe = value ?? false,
                                          );
                                          if (!_rememberMe) {
                                            await _preferencesService
                                                .clearSavedEmail();
                                          }
                                        },
                                      ),
                                    ),
                                    Text(
                                      'Recordarme',
                                      style: TextStyle(
                                        color: AppColors.white.withOpacity(0.9),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pushNamed(
                                      context,
                                      '/forgot-password',
                                    );
                                  },
                                  child: Text(
                                    '¿Olvidaste contraseña?',
                                    style: TextStyle(
                                      color: AppColors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      decoration: TextDecoration.underline,
                                      decorationColor: AppColors.white
                                          .withOpacity(0.5),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 30),

                            // Botón LOGIN
                            Container(
                              width: double.infinity,
                              height: 55,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(30),
                                color: accentColor, // Color sólido
                                boxShadow: [
                                  BoxShadow(
                                    color: accentColor.withOpacity(0.4),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: _onLoginPressed,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                                child: _isLoading
                                    ? CircularProgressIndicator(
                                        color: AppColors.white,
                                      )
                                    : Text(
                                        'INGRESAR',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.white,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Botón Biometría (Fuera de la tarjeta para menos ruido visual)
                  if (_hasBiometricHardware && _isBiometricConfigured) ...[
                    const SizedBox(height: 24),
                    TextButton.icon(
                      onPressed: _onBiometricLoginPressed,
                      icon: Icon(
                        Icons.fingerprint,
                        color: AppColors.white,
                        size: 28,
                      ),
                      label: Text(
                        'Usar Huella Digital',
                        style: TextStyle(color: AppColors.white, fontSize: 16),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        backgroundColor: AppColors.white.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                          side: BorderSide(
                            color: AppColors.white.withOpacity(0.3),
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 30),

                  // Registrar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '¿Aún no tienes cuenta? ',
                        style: TextStyle(color: Colors.white70),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, '/register'),
                        child: Text(
                          'Crea una aquí',
                          style: TextStyle(
                            color: AppColors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
