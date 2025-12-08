// lib/main.dart

import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_page.dart';
import 'screens/register_page.dart';
import 'screens/home_page.dart';
import 'screens/products_page.dart';
import 'screens/service_reservation_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/main_tabs_screen.dart';
import 'screens/admin_panel_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tech Service Computer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1976D2)),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1976D2),
          foregroundColor: Colors.white,
        ),
      ),
      // 🚀 Flujo inicial: Splash → Onboarding → Login
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => const HomePage(routeName: '/home'),
        '/products': (context) => const ProductsPage(routeName: '/products'),
        '/reserve-service': (context) => const ServiceReservationPage(),
        '/admin': (context) => const AdminPanelPage(),
        '/main': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          return MainTabsScreen();
        },
      },
    );
  }
}
