import 'package:flutter/material.dart';
import '../utils/prefs.dart'; // 👈 Importamos

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _dontShowAgain = false; // 👈 Estado del checkbox

  final AppPreferences _prefs = AppPreferences();

  final List<Map<String, dynamic>> _pages = [
    {
      'icon': Icons.computer,
      'title': 'Reparación Profesional',
      'description':
          'Servicios técnicos especializados para computadoras, laptops y servidores.',
    },
    {
      'icon': Icons.security,
      'title': 'Seguridad y Confianza',
      'description':
          'Tus datos están protegidos. Trabajamos con estándares de seguridad certificados.',
    },
    {
      'icon': Icons.support_agent,
      'title': 'Soporte 24/7',
      'description':
          'Nuestro equipo de expertos está disponible las 24 horas, los 7 días de la semana.',
    },
  ];

  void _navigateToLogin() async {
    // ✅ Guardamos la preferencia si el usuario lo eligió
    if (_dontShowAgain) {
      await _prefs.setOnboardingCompleted(true);
    }
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _navigateToLogin();
    }
  }

  void _skipOnboarding() async {
    // Si salta, no guardamos "completado", solo va al login
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // AppBar con "Saltar"
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _skipOnboarding,
                    child: Text(
                      'Saltar',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Contenido deslizable
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
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
                            page['icon'] as IconData,
                            color: Theme.of(context).colorScheme.primary,
                            size: 60,
                          ),
                        ),
                        const SizedBox(height: 40),
                        Text(
                          page['title'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          page['description'] as String,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // 👇 Nueva sección: Checkbox + Indicadores + Botón
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Checkbox "No mostrar de nuevo"
                  if (_currentPage ==
                      _pages.length - 1) // Solo en última página
                    Row(
                      children: [
                        Checkbox(
                          value: _dontShowAgain,
                          onChanged: (value) {
                            setState(() {
                              _dontShowAgain = value ?? false;
                            });
                          },
                        ),
                        const Expanded(
                          child: Text(
                            'No mostrar de nuevo',
                            style: TextStyle(fontSize: 14, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  SizedBox(height: _currentPage == 2 ? 12 : 24),

                  // Indicadores
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (index) {
                      return Container(
                        width: _currentPage == index ? 24 : 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: _currentPage == index
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey[300],
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),

                  // Botón
                  ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: Text(
                      _currentPage == _pages.length - 1
                          ? 'Comenzar'
                          : 'Siguiente',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
