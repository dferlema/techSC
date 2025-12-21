// lib/main.dart

import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_page.dart';
import 'screens/register_page.dart';
import 'screens/forgot_password_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/main_tabs_screen.dart';
import 'screens/admin_panel_page.dart';
import 'screens/technician_dashboard.dart';
import 'theme/app_theme.dart';
import 'screens/contact_page.dart';

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
      title: 'TechService Pro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/onboarding': (context) => const OnboardingScreen(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/forgot-password': (context) => const ForgotPasswordPage(),
        '/home': (context) => const MainTabsScreen(),
        '/products': (context) => const MainTabsScreen(),
        '/reserve-service': (context) => const MainTabsScreen(),
        '/admin': (context) => const AdminPanelPage(),
        '/technician': (context) => const TechnicianDashboard(),
        '/contact': (context) => const ContactPage(), // New Route
        '/main': (context) {
          final args = ModalRoute.of(context)?.settings.arguments;
          return MainTabsScreen();
        },
      },
    );
  }
}
