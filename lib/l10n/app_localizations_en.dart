// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'TechSC';

  @override
  String get loginTitle => 'Login';

  @override
  String get welcomeBack => 'Welcome back';

  @override
  String get emailLabel => 'Email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get rememberMe => 'Remember me';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get loginButton => 'LOGIN';

  @override
  String get noAccount => 'Don\'t have an account? ';

  @override
  String get createAccountHere => 'Create one here';

  @override
  String get registerTitle => 'Create Account';

  @override
  String get registerDescription =>
      'Join TechService and access exclusive services';

  @override
  String get fullNameLabel => 'Full Name';

  @override
  String get idLabel => 'ID or RUC';

  @override
  String get phoneLabel => 'Phone';

  @override
  String get addressLabel => 'Address';

  @override
  String get confirmPasswordLabel => 'Confirm Password';

  @override
  String get acceptTermsPrefix => 'I accept the ';

  @override
  String get termsAndConditions => 'terms and conditions';

  @override
  String get acceptTermsAnd => ' and the ';

  @override
  String get privacyPolicy => 'privacy policy';

  @override
  String get registerButton => 'Register';

  @override
  String get alreadyHaveAccount => 'Already have an account? ';

  @override
  String get loginLink => 'Login here';

  @override
  String get forgotPasswordTitle => 'Recover Password';

  @override
  String get forgotPasswordDescription =>
      'Enter your email and we will send you a link to reset your password';

  @override
  String get sendResetEmail => 'Send Recovery Email';

  @override
  String get backToLogin => 'Back to Login';

  @override
  String get emailSentSuccess => 'Email sent successfully!';

  @override
  String get checkInboxMessage =>
      'Check your inbox and follow the instructions in the email to reset your password.';

  @override
  String get contactTitle => 'Contact Us';

  @override
  String get contactGreeting => 'Hello! 👋';

  @override
  String get contactQuestion => 'How can we help you today?';

  @override
  String get immediateAssistance => 'Immediate Assistance';

  @override
  String get whatsappDescription =>
      'We resolve your technical questions via WhatsApp in real time.';

  @override
  String get startChatButton => 'Start Chat Now';

  @override
  String get otherChannels => 'Other channels';

  @override
  String get directLine => 'Direct Line';

  @override
  String get emailContact => 'Email';

  @override
  String get centralLocation => 'Central Location';

  @override
  String get available247 => 'We are available 24/7 for you';

  @override
  String get homeTitle => 'Home';

  @override
  String get productsTitle => 'Our Products';

  @override
  String get servicesTitle => 'Our Services';

  @override
  String get categoriesTitle => 'Categories';

  @override
  String get searchHint => 'Search...';

  @override
  String get addToCart => 'Add to Cart';

  @override
  String get cartTitle => 'My Cart';

  @override
  String get ordersTitle => 'My Orders';

  @override
  String get reservationsTitle => 'My Reservations';

  @override
  String get quotesTitle => 'Quotes';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get adminPanelTitle => 'Admin Panel';

  @override
  String get reportsTitle => 'Reports';

  @override
  String get technicianPanelTitle => 'Technician Panel';

  @override
  String get marketingTitle => 'Marketing';

  @override
  String get emptyProducts => 'No products in this category';

  @override
  String get emptyServices => 'No services in this category';

  @override
  String get noCategoriesConfigured =>
      'No categories configured.\nAdd categories from admin panel.';

  @override
  String get noMoreProducts => 'More products coming soon';

  @override
  String get noSearchResults => 'No results found';

  @override
  String get expertSupport => 'Expert technical support';

  @override
  String get allCategories => 'All';

  @override
  String get errorLoading => 'Error loading data';

  @override
  String successAddedToCart(String item) {
    return '$item added to cart';
  }
}
