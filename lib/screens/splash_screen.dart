import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/prefs.dart';
import '../theme/app_theme.dart';
import '../services/config_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AppPreferences _prefs = AppPreferences();
  final ConfigService _configService = ConfigService();
  Map<String, dynamic>? _branding;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Carga paralela de configuración y delay mínimo de UX
    final results = await Future.wait([
      _configService.getBrandingConfig(),
      Future.delayed(const Duration(seconds: 3)),
    ]);

    _branding = results[0] as Map<String, dynamic>;

    if (mounted) {
      _checkOnboardingStatus();
    }
  }

  Future<void> _checkOnboardingStatus() async {
    final completed = await _prefs.getOnboardingCompleted();
    if (completed) {
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      Navigator.pushReplacementNamed(
        context,
        '/onboarding',
        arguments: _branding?['onboarding'],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    final splashData =
        _branding?['splash'] ??
        {
          'title': 'TechService Pro',
          'subtitle': 'Soluciones Tecnológicas de Calidad',
          'imageUrl': null,
        };

    final String? backgroundUrl = splashData['imageUrl'];

    return Scaffold(
      backgroundColor: AppColors.primaryBlue,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Imagen de fondo opcional
          if (backgroundUrl != null && backgroundUrl.isNotEmpty)
            Image.network(
              backgroundUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  Container(color: AppColors.primaryBlue),
            ),

          // Overlay para legibilidad si hay imagen
          if (backgroundUrl != null && backgroundUrl.isNotEmpty)
            Container(color: Colors.black.withOpacity(0.4)),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Solo mostrar logo si no hay imagen de fondo o si se desea mantener
                if (backgroundUrl == null || backgroundUrl.isEmpty)
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.computer,
                      color: Colors.white,
                      size: 60,
                    ),
                  ),
                const SizedBox(height: 32),
                Text(
                  splashData['title'] ?? 'TechService Pro',
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
                Text(
                  splashData['subtitle'] ??
                      'Soluciones Tecnológicas de Calidad',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
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
        ],
      ),
    );
  }
}
