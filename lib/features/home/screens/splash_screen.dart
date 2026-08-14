import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tscomputer/core/services/preferences_service.dart';
import 'package:tscomputer/core/theme/app_colors.dart';
import 'package:tscomputer/core/services/config_service.dart';
import 'package:tscomputer/core/utils/branding_helper.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  final PreferencesService _prefs = PreferencesService();
  late AnimationController _controller;
  late Animation<double> _fadeIn;
  late Animation<double> _scaleUp;
  late Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeIn = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scaleUp = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();

    final delay = kIsWeb ? const Duration(milliseconds: 1800) : const Duration(seconds: 3);
    Future.delayed(delay, () {
      if (mounted) _initializeApp();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    try {
      final config = await ConfigService().getConfig();
      BrandingHelper.setConfig(config);
    } catch (e) {
      debugPrint('Error loading branding: $e');
    }

    if (mounted) _checkOnboardingStatus();
  }

  Future<void> _checkOnboardingStatus() async {
    final completed = await _prefs.getOnboardingCompleted();

    if (!completed) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/onboarding');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final expired = await _prefs.isSessionExpired();
      if (!expired) {
        await _prefs.updateLastActivity();
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/main');
        return;
      } else {
        await FirebaseAuth.instance.signOut();
        await _prefs.clearSession();
      }
    }

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      try {
        // ignore: invalid_use_of_visible_for_testing_member
        // SystemChrome not needed on web
      } catch (_) {}
    }

    final size = MediaQuery.of(context).size;
    final isWide = size.width > 800;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.5,
            colors: [
              AppColors.primaryBlue.withValues(alpha: 0.15),
              const Color(0xFF0D1B2A),
            ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeIn,
            child: ScaleTransition(
              scale: _scaleUp,
              child: isWide ? _buildWideLayout() : _buildNarrowLayout(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLogoSection(),
        Container(
          width: 1,
          height: 200,
          margin: const EdgeInsets.symmetric(horizontal: 60),
          color: Colors.white.withValues(alpha: 0.1),
        ),
        _buildInfoSection(),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLogo(80),
        const SizedBox(height: 32),
        Text(
          BrandingHelper.appName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 36,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Soluciones Tecnológicas de Calidad',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 60),
        SizedBox(
          width: 200,
          child: LinearProgressIndicator(
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildLogo(90),
        const SizedBox(height: 28),
        Text(
          BrandingHelper.appName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 42,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Soluciones Tecnológicas de Calidad',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 18,
            fontWeight: FontWeight.w300,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection() {
    return SlideTransition(
      position: _slideUp,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _featureRow(Icons.speed_rounded, 'Gestión Rápida'),
          const SizedBox(height: 16),
          _featureRow(Icons.security_rounded, 'Seguro y Confiable'),
          const SizedBox(height: 16),
          _featureRow(Icons.devices_rounded, 'Multi-Plataforma'),
          const SizedBox(height: 40),
          SizedBox(
            width: 220,
            child: LinearProgressIndicator(
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryBlue),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryBlue, AppColors.primaryBlue.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.25),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.4),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Icon(Icons.computer_rounded, color: Colors.white, size: size * 0.5),
    );
  }

  Widget _featureRow(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppColors.primaryBlue, size: 20),
        const SizedBox(width: 12),
        Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 15,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
