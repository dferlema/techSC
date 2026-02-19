// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'TechSC';

  @override
  String get loginTitle => 'Iniciar Sesión';

  @override
  String get welcomeBack => 'Bienvenido de nuevo';

  @override
  String get emailLabel => 'Correo Electrónico';

  @override
  String get passwordLabel => 'Contraseña';

  @override
  String get rememberMe => 'Recordarme';

  @override
  String get forgotPassword => '¿Olvidaste contraseña?';

  @override
  String get loginButton => 'INGRESAR';

  @override
  String get noAccount => '¿Aún no tienes cuenta? ';

  @override
  String get createAccountHere => 'Crea una aquí';

  @override
  String get registerTitle => 'Crear Cuenta';

  @override
  String get registerDescription =>
      'Únete a TechService y accede a servicios exclusivos';

  @override
  String get fullNameLabel => 'Nombre Completo';

  @override
  String get idLabel => 'Cédula o RUC';

  @override
  String get phoneLabel => 'Teléfono';

  @override
  String get addressLabel => 'Dirección';

  @override
  String get confirmPasswordLabel => 'Confirmar Contraseña';

  @override
  String get acceptTermsPrefix => 'Acepto los ';

  @override
  String get termsAndConditions => 'términos y condiciones';

  @override
  String get acceptTermsAnd => ' y la ';

  @override
  String get privacyPolicy => 'política de privacidad';

  @override
  String get registerButton => 'Registrarse';

  @override
  String get alreadyHaveAccount => '¿Ya tienes una cuenta? ';

  @override
  String get loginLink => 'Inicia sesión';

  @override
  String get forgotPasswordTitle => 'Recuperar Contraseña';

  @override
  String get forgotPasswordDescription =>
      'Ingresa tu correo electrónico y te enviaremos un enlace para restablecer tu contraseña';

  @override
  String get sendResetEmail => 'Enviar Correo de Recuperación';

  @override
  String get backToLogin => 'Volver al Inicio de Sesión';

  @override
  String get emailSentSuccess => '¡Correo enviado exitosamente!';

  @override
  String get checkInboxMessage =>
      'Revisa tu bandeja de entrada y sigue las instrucciones del correo para restablecer tu contraseña.';

  @override
  String get contactTitle => 'Contáctanos';

  @override
  String get contactGreeting => '¡Hola! 👋';

  @override
  String get contactQuestion => '¿Cómo podemos ayudarte hoy?';

  @override
  String get immediateAssistance => 'Asistencia Inmediata';

  @override
  String get whatsappDescription =>
      'Resolvemos tus dudas técnicas por WhatsApp en tiempo real.';

  @override
  String get startChatButton => 'Iniciar Chat Ahora';

  @override
  String get otherChannels => 'Otros canales de atención';

  @override
  String get directLine => 'Línea Directa';

  @override
  String get emailContact => 'Correo Electrónico';

  @override
  String get centralLocation => 'Ubicación Central';

  @override
  String get available247 => 'Estamos disponibles 24/7 para ti';

  @override
  String get homeTitle => 'Inicio';

  @override
  String get productsTitle => 'Nuestros Productos';

  @override
  String get servicesTitle => 'Nuestros Servicios';

  @override
  String get categoriesTitle => 'Categorías';

  @override
  String get searchHint => 'Buscar...';

  @override
  String get addToCart => 'Comprar';

  @override
  String get cartTitle => 'Mi Carrito';

  @override
  String get ordersTitle => 'Mis Pedidos';

  @override
  String get reservationsTitle => 'Mis Reservas';

  @override
  String get quotesTitle => 'Cotizaciones';

  @override
  String get settingsTitle => 'Configuración';

  @override
  String get adminPanelTitle => 'Panel de Gestión';

  @override
  String get reportsTitle => 'Reportes';

  @override
  String get technicianPanelTitle => 'Panel Técnico';

  @override
  String get marketingTitle => 'Marketing';

  @override
  String get emptyProducts => 'No hay productos en esta categoría';

  @override
  String get emptyServices => 'No hay servicios en esta categoría';

  @override
  String get noCategoriesConfigured =>
      'No hay categorías configuradas.\nAgregue categorías desde el panel de admin.';

  @override
  String get noMoreProducts => 'Pronto tendremos más productos';

  @override
  String get noSearchResults => 'No encontramos resultados';

  @override
  String get expertSupport => 'Soporte técnico experto';

  @override
  String get allCategories => 'Todos';

  @override
  String get errorLoading => 'Error al cargar datos';

  @override
  String successAddedToCart(String item) {
    return '$item agregado al carrito';
  }
}
