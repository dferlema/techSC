// lib/main.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'utils/prefs.dart';
import 'utils/branding_helper.dart';

import 'theme/app_theme.dart';
import 'theme/app_colors.dart';
import 'services/config_service.dart';
import 'services/deep_link_service.dart';
import 'services/notification_service.dart';

import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_page.dart';
import 'screens/register_page.dart';
import 'screens/forgot_password_page.dart';
import 'screens/main_tabs_screen.dart';
import 'screens/admin_panel_page.dart';
import 'screens/technician_dashboard.dart';
import 'screens/contact_page.dart';
import 'screens/products_page.dart';
import 'screens/my_reservations_page.dart';
import 'screens/services_page.dart';
import 'screens/profile_edit_page.dart';
import 'screens/reports_page.dart';
import 'screens/quote_list_page.dart';
import 'screens/create_quote_page.dart';
import 'screens/settings_page.dart';
import 'screens/category_management_page.dart';
import 'screens/marketing_campaign_page.dart';
import 'screens/admin/app_colors_config_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_EC', null);
  Intl.defaultLocale = 'es_EC';
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Initialize Dynamic Colors
    try {
      final configService = ConfigService();
      final colors = await configService.getColorConfig();
      if (colors != null) {
        AppColors.updateColors(colors);
        debugPrint("Dynamic colors loaded successfully.");
      }
    } catch (e) {
      debugPrint("Failed to load dynamic colors: $e");
    }
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
    // Depending on the platform, this might be due to missing configuration
    if (e.toString().contains('UnsupportedError')) {
      debugPrint("Warning: This platform is not yet configured for Firebase.");
    }
  }

  // Initialize Deep Link Service
  DeepLinkService().init();

  // Initialize Notification Service
  await NotificationService().initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: AppColors.notifier,
      builder: (context, _, child) {
        return MaterialApp(
          title: BrandingHelper.appName,
          debugShowCheckedModeBanner: false,
          navigatorKey: DeepLinkService().navigatorKey,
          theme: AppTheme.lightTheme,
          initialRoute: '/',
          builder: (context, child) {
            return Listener(
              onPointerDown: (_) {
                AppPreferences().updateLastActivity();
              },
              child: child!,
            );
          },
          routes: {
            '/': (context) => const SplashScreen(),
            '/onboarding': (context) => const OnboardingScreen(),
            '/login': (context) => const LoginPage(),
            '/register': (context) => const RegisterPage(),
            '/forgot-password': (context) => const ForgotPasswordPage(),
            '/home': (context) => const MainTabsScreen(),
            '/products': (context) => const ProductsPage(),
            '/services': (context) => const ServicesPage(),
            '/reserve-service': (context) => const MainTabsScreen(),
            '/admin': (context) => const AdminPanelPage(),
            '/technician': (context) => const TechnicianDashboard(),
            '/contact': (context) => const ContactPage(),
            '/my-reservations': (context) => const MyReservationsPage(),
            '/profile-edit': (context) => const ProfileEditPage(),
            '/reports': (context) => const ReportsPage(),
            '/quotes': (context) => const QuoteListPage(),
            '/create-quote': (context) => const CreateQuotePage(),
            '/settings': (context) => const SettingsPage(),
            '/category-management': (context) => const CategoryManagementPage(),
            '/marketing': (context) => const MarketingCampaignPage(),
            '/app-colors-config': (context) => const AppColorsConfigPage(),
            '/main': (context) => const MainTabsScreen(),
          },
        );
      },
    );
  }
}
