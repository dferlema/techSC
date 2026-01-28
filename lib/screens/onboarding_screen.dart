import 'package:flutter/material.dart';
import '../services/preferences_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  final PageController _backgroundController = PageController();
  int _currentPage = 0;
  bool _dontShowAgain = false;
  final PreferencesService _prefs = PreferencesService();

  final List<Map<String, dynamic>> _pages = [
    {
      'icon': Icons.computer,
      'title': 'Reparación Profesional',
      'description':
          'Servicios técnicos especializados para computadoras, laptops y servidores.',
      'imageUrl': null,
    },
    {
      'icon': Icons.security,
      'title': 'Seguridad y Confianza',
      'description':
          'Tus datos están protegidos. Trabajamos con estándares de seguridad certificados.',
      'imageUrl': null,
    },
    {
      'icon': Icons.support_agent,
      'title': 'Soporte 24/7',
      'description':
          'Nuestro equipo de expertos está disponible las 24 horas, los 7 días de la semana.',
      'imageUrl': null,
    },
  ];

  IconData _getIconData(dynamic icon) {
    if (icon is IconData) return icon;
    switch (icon.toString()) {
      case 'computer':
        return Icons.computer;
      case 'security':
        return Icons.security;
      case 'support_agent':
        return Icons.support_agent;
      default:
        return Icons.info_outline;
    }
  }

  void _navigateToLogin() async {
    if (_dontShowAgain) {
      await _prefs.setOnboardingCompleted(true);
    }
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _navigateToLogin();
    }
  }

  void _skipOnboarding() {
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  void dispose() {
    _pageController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Fondo de pantalla dinámico
          PageView.builder(
            controller: _backgroundController,
            itemCount: _pages.length,
            physics:
                const NeverScrollableScrollPhysics(), // Controlado por el main PV
            itemBuilder: (context, index) {
              final String? imageUrl = _pages[index]['imageUrl'];
              if (imageUrl != null && imageUrl.isNotEmpty) {
                return Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: Colors.white),
                );
              }
              return Container(color: Colors.white);
            },
          ),

          // Overlay si hay una imagen de fondo para que el texto sea legible
          if (_pages[_currentPage]['imageUrl'] != null)
            Container(color: Colors.black.withOpacity(0.3)),

          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _skipOnboarding,
                        child: Text(
                          'Saltar',
                          style: TextStyle(
                            color: _pages[_currentPage]['imageUrl'] != null
                                ? Colors.white
                                : Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _pages.length,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                      _backgroundController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    itemBuilder: (context, index) {
                      final page = _pages[index];
                      final bool hasBg = page['imageUrl'] != null;

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (!hasBg)
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _getIconData(page['icon']),
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 60,
                                ),
                              ),
                            const SizedBox(height: 40),
                            Text(
                              page['title'] as String,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: hasBg ? Colors.white : Colors.black87,
                                shadows: hasBg
                                    ? [
                                        const Shadow(
                                          blurRadius: 10,
                                          color: Colors.black45,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              page['description'] as String,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                color: hasBg
                                    ? Colors.white70
                                    : Colors.grey[700],
                                height: 1.5,
                                shadows: hasBg
                                    ? [
                                        const Shadow(
                                          blurRadius: 5,
                                          color: Colors.black45,
                                        ),
                                      ]
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      if (_currentPage == _pages.length - 1)
                        Row(
                          children: [
                            Checkbox(
                              value: _dontShowAgain,
                              side: _pages[_currentPage]['imageUrl'] != null
                                  ? const BorderSide(color: Colors.white)
                                  : null,
                              onChanged: (value) => setState(
                                () => _dontShowAgain = value ?? false,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'No mostrar de nuevo',
                                style: TextStyle(
                                  fontSize: 14,
                                  color:
                                      _pages[_currentPage]['imageUrl'] != null
                                      ? Colors.white70
                                      : Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_pages.length, (index) {
                          return Container(
                            width: _currentPage == index ? 24 : 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? (_pages[_currentPage]['imageUrl'] != null
                                        ? Colors.white
                                        : Theme.of(context).colorScheme.primary)
                                  : Colors.grey[400],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _pages[_currentPage]['imageUrl'] != null
                              ? Colors.white
                              : null,
                          foregroundColor:
                              _pages[_currentPage]['imageUrl'] != null
                              ? Theme.of(context).colorScheme.primary
                              : null,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          minimumSize: const Size(double.infinity, 56),
                        ),
                        child: Text(
                          _currentPage == _pages.length - 1
                              ? 'COMENZAR'
                              : 'SIGUIENTE',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
