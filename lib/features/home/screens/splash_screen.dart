import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:techsc/core/services/preferences_service.dart';
import 'package:techsc/core/theme/app_colors.dart';
import 'package:techsc/core/services/config_service.dart';
import 'package:techsc/core/utils/branding_helper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final PreferencesService _prefs = PreferencesService();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Cargar nombres y configuraciones
    try {
      final config = await ConfigService().getConfig();
      BrandingHelper.setConfig(config);
    } catch (e) {
      debugPrint('Error loading branding: $e');
    }

    // Delay mínimo de UX
    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      _checkOnboardingStatus();
    }
  }

  Future<void> _checkOnboardingStatus() async {
    final completed = await _prefs.getOnboardingCompleted();

    if (!completed) {
      Navigator.pushReplacementNamed(context, '/onboarding');
      return;
    }

    // Verificar si hay una sesión activa de Firebase
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Verificar si la sesión ha expirado por inactividad
      final expired = await _prefs.isSessionExpired();
      if (!expired) {
        // Sesión válida, actualizar actividad al entrar e ir al home
        await _prefs.updateLastActivity();
        Navigator.pushReplacementNamed(context, '/main');
        return;
      } else {
        // Sesión expirada, cerrar sesión de Firebase
        await FirebaseAuth.instance.signOut();
        await _prefs.clearSession();
      }
    }

    // Si no hay usuario o la sesión expiró, ir a login
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.computer, color: Colors.white, size: 60),
            ),
            const SizedBox(height: 32),
            Text(
              BrandingHelper.appName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                shadows: [
                  Shadow(
                    blurRadius: 10,
                    color: Colors.black45,
                    offset: Offset(2, 2),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Soluciones Tecnológicas de Calidad',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
                shadows: [
                  Shadow(
                    blurRadius: 5,
                    color: Colors.black45,
                    offset: Offset(1, 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 80),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}
