// lib/main.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tscomputer/l10n/app_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'firebase_options.dart';

import 'package:tscomputer/core/services/preferences_service.dart';
import 'package:tscomputer/core/utils/branding_helper.dart';
import 'package:tscomputer/core/theme/app_theme.dart';
import 'package:tscomputer/core/theme/app_colors.dart';
import 'package:tscomputer/core/services/config_service.dart';
import 'package:tscomputer/core/services/deep_link_service.dart';
import 'package:tscomputer/core/services/notification_service.dart';

import 'package:tscomputer/features/home/screens/splash_screen.dart';
import 'package:tscomputer/features/home/screens/onboarding_screen.dart';
import 'package:tscomputer/features/auth/screens/login_page.dart';
import 'package:tscomputer/features/auth/screens/register_page.dart';
import 'package:tscomputer/features/auth/screens/forgot_password_page.dart';
import 'package:tscomputer/features/home/screens/main_tabs_screen.dart';
import 'package:tscomputer/features/admin/screens/admin_panel_page.dart';
import 'package:tscomputer/features/reservations/screens/technician_dashboard.dart';
import 'package:tscomputer/features/home/screens/contact_page.dart';
import 'package:tscomputer/features/catalog/screens/products_page.dart';
import 'package:tscomputer/features/reservations/screens/my_reservations_page.dart';
import 'package:tscomputer/features/reservations/screens/services_page.dart';
import 'package:tscomputer/features/profile/screens/profile_edit_page.dart';
import 'package:tscomputer/features/admin/screens/reports_page.dart';
import 'package:tscomputer/features/orders/screens/quote_list_page.dart';
import 'package:tscomputer/features/orders/screens/create_quote_page.dart';
import 'package:tscomputer/features/admin/screens/settings_page.dart';
import 'package:tscomputer/features/catalog/screens/category_management_page.dart';
import 'package:tscomputer/features/admin/screens/marketing_campaign_page.dart';
import 'package:tscomputer/features/admin/screens/app_colors_config_page.dart';
import 'package:tscomputer/features/accounting/screens/accounting_home_page.dart';
import 'package:tscomputer/features/home/screens/legal_info_page.dart';
import 'package:tscomputer/core/services/cache_service.dart';
import 'package:tscomputer/core/services/connectivity_service.dart';
import 'package:tscomputer/features/cart/screens/cart_page.dart';
import 'package:tscomputer/features/orders/screens/my_orders_page.dart';
import 'package:tscomputer/features/inventory/screens/inventory_reports_page.dart';
import 'package:tscomputer/features/catalog/screens/supplier_management_page.dart';
import 'package:tscomputer/features/home/screens/notifications_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_EC', null);
  Intl.defaultLocale = 'es_EC';

  // Initialize Hive
  try {
    final cacheService = CacheService();
    await cacheService.init();
    debugPrint("Hive initialized successfully.");
  } catch (e) {
    debugPrint("Failed to initialize Hive: $e");
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Habilitar persistencia offline de Firestore (no soportado en web)
    if (!kIsWeb) {
      try {
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
        debugPrint("Firestore offline persistence enabled.");
      } catch (e) {
        debugPrint("Failed to enable Firestore persistence: $e");
      }
    }

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
    if (e.toString().contains('UnsupportedError')) {
      debugPrint("Warning: This platform is not yet configured for Firebase.");
    }
  }

  // Initialize Deep Link Service (native only)
  if (!kIsWeb) {
    DeepLinkService().init();
  }

  // Initialize Connectivity Service
  ConnectivityService().initialize();

  // Initialize Notification Service (native only)
  if (!kIsWeb) {
    await NotificationService().initialize();
  }

  runApp(const ProviderScope(child: MyApp()));
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
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          initialRoute: '/',
          builder: (context, child) {
            return Listener(
              onPointerDown: (_) {
                PreferencesService().updateLastActivity();
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
            '/legal': (context) {
              final args =
                  ModalRoute.of(context)?.settings.arguments as int? ?? 0;
              return LegalInfoPage(initialTabIndex: args);
            },
            '/main': (context) => const MainTabsScreen(),
            '/cart': (context) => const CartPage(),
            '/my-orders': (context) => const MyOrdersPage(),
            '/inventory-reports': (context) => const InventoryReportsPage(),
            '/supplier-management': (context) => const SupplierManagementPage(),
            '/accounting': (context) => const AccountingHomePage(),
            '/notifications': (context) => const NotificationsPage(),
          },
        );
      },
    );
  }
}
