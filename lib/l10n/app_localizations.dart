import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
  ];

  /// El título de la aplicación
  ///
  /// In es, this message translates to:
  /// **'TechSC'**
  String get appTitle;

  /// No description provided for @loginTitle.
  ///
  /// In es, this message translates to:
  /// **'Iniciar Sesión'**
  String get loginTitle;

  /// No description provided for @welcomeBack.
  ///
  /// In es, this message translates to:
  /// **'Bienvenido de nuevo'**
  String get welcomeBack;

  /// No description provided for @emailLabel.
  ///
  /// In es, this message translates to:
  /// **'Correo Electrónico'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In es, this message translates to:
  /// **'Contraseña'**
  String get passwordLabel;

  /// No description provided for @rememberMe.
  ///
  /// In es, this message translates to:
  /// **'Recordarme'**
  String get rememberMe;

  /// No description provided for @forgotPassword.
  ///
  /// In es, this message translates to:
  /// **'¿Olvidaste contraseña?'**
  String get forgotPassword;

  /// No description provided for @loginButton.
  ///
  /// In es, this message translates to:
  /// **'INGRESAR'**
  String get loginButton;

  /// No description provided for @noAccount.
  ///
  /// In es, this message translates to:
  /// **'¿Aún no tienes cuenta? '**
  String get noAccount;

  /// No description provided for @createAccountHere.
  ///
  /// In es, this message translates to:
  /// **'Crea una aquí'**
  String get createAccountHere;

  /// No description provided for @registerTitle.
  ///
  /// In es, this message translates to:
  /// **'Crear Cuenta'**
  String get registerTitle;

  /// No description provided for @registerDescription.
  ///
  /// In es, this message translates to:
  /// **'Únete a TechService y accede a servicios exclusivos'**
  String get registerDescription;

  /// No description provided for @fullNameLabel.
  ///
  /// In es, this message translates to:
  /// **'Nombre Completo'**
  String get fullNameLabel;

  /// No description provided for @idLabel.
  ///
  /// In es, this message translates to:
  /// **'Cédula o RUC'**
  String get idLabel;

  /// No description provided for @phoneLabel.
  ///
  /// In es, this message translates to:
  /// **'Teléfono'**
  String get phoneLabel;

  /// No description provided for @addressLabel.
  ///
  /// In es, this message translates to:
  /// **'Dirección'**
  String get addressLabel;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In es, this message translates to:
  /// **'Confirmar Contraseña'**
  String get confirmPasswordLabel;

  /// No description provided for @acceptTermsPrefix.
  ///
  /// In es, this message translates to:
  /// **'Acepto los '**
  String get acceptTermsPrefix;

  /// No description provided for @termsAndConditions.
  ///
  /// In es, this message translates to:
  /// **'términos y condiciones'**
  String get termsAndConditions;

  /// No description provided for @acceptTermsAnd.
  ///
  /// In es, this message translates to:
  /// **' y la '**
  String get acceptTermsAnd;

  /// No description provided for @privacyPolicy.
  ///
  /// In es, this message translates to:
  /// **'política de privacidad'**
  String get privacyPolicy;

  /// No description provided for @registerButton.
  ///
  /// In es, this message translates to:
  /// **'Registrarse'**
  String get registerButton;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In es, this message translates to:
  /// **'¿Ya tienes una cuenta? '**
  String get alreadyHaveAccount;

  /// No description provided for @loginLink.
  ///
  /// In es, this message translates to:
  /// **'Inicia sesión'**
  String get loginLink;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In es, this message translates to:
  /// **'Recuperar Contraseña'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordDescription.
  ///
  /// In es, this message translates to:
  /// **'Ingresa tu correo electrónico y te enviaremos un enlace para restablecer tu contraseña'**
  String get forgotPasswordDescription;

  /// No description provided for @sendResetEmail.
  ///
  /// In es, this message translates to:
  /// **'Enviar Correo de Recuperación'**
  String get sendResetEmail;

  /// No description provided for @backToLogin.
  ///
  /// In es, this message translates to:
  /// **'Volver al Inicio de Sesión'**
  String get backToLogin;

  /// No description provided for @emailSentSuccess.
  ///
  /// In es, this message translates to:
  /// **'¡Correo enviado exitosamente!'**
  String get emailSentSuccess;

  /// No description provided for @checkInboxMessage.
  ///
  /// In es, this message translates to:
  /// **'Revisa tu bandeja de entrada y sigue las instrucciones del correo para restablecer tu contraseña.'**
  String get checkInboxMessage;

  /// No description provided for @contactTitle.
  ///
  /// In es, this message translates to:
  /// **'Contáctanos'**
  String get contactTitle;

  /// No description provided for @contactGreeting.
  ///
  /// In es, this message translates to:
  /// **'¡Hola! 👋'**
  String get contactGreeting;

  /// No description provided for @contactQuestion.
  ///
  /// In es, this message translates to:
  /// **'¿Cómo podemos ayudarte hoy?'**
  String get contactQuestion;

  /// No description provided for @immediateAssistance.
  ///
  /// In es, this message translates to:
  /// **'Asistencia Inmediata'**
  String get immediateAssistance;

  /// No description provided for @whatsappDescription.
  ///
  /// In es, this message translates to:
  /// **'Resolvemos tus dudas técnicas por WhatsApp en tiempo real.'**
  String get whatsappDescription;

  /// No description provided for @startChatButton.
  ///
  /// In es, this message translates to:
  /// **'Iniciar Chat Ahora'**
  String get startChatButton;

  /// No description provided for @otherChannels.
  ///
  /// In es, this message translates to:
  /// **'Otros canales de atención'**
  String get otherChannels;

  /// No description provided for @directLine.
  ///
  /// In es, this message translates to:
  /// **'Línea Directa'**
  String get directLine;

  /// No description provided for @emailContact.
  ///
  /// In es, this message translates to:
  /// **'Correo Electrónico'**
  String get emailContact;

  /// No description provided for @centralLocation.
  ///
  /// In es, this message translates to:
  /// **'Ubicación Central'**
  String get centralLocation;

  /// No description provided for @available247.
  ///
  /// In es, this message translates to:
  /// **'Estamos disponibles 24/7 para ti'**
  String get available247;

  /// No description provided for @homeTitle.
  ///
  /// In es, this message translates to:
  /// **'Inicio'**
  String get homeTitle;

  /// No description provided for @productsTitle.
  ///
  /// In es, this message translates to:
  /// **'Nuestros Productos'**
  String get productsTitle;

  /// No description provided for @servicesTitle.
  ///
  /// In es, this message translates to:
  /// **'Nuestros Servicios'**
  String get servicesTitle;

  /// No description provided for @categoriesTitle.
  ///
  /// In es, this message translates to:
  /// **'Categorías'**
  String get categoriesTitle;

  /// No description provided for @searchHint.
  ///
  /// In es, this message translates to:
  /// **'Buscar...'**
  String get searchHint;

  /// No description provided for @addToCart.
  ///
  /// In es, this message translates to:
  /// **'Comprar'**
  String get addToCart;

  /// No description provided for @cartTitle.
  ///
  /// In es, this message translates to:
  /// **'Mi Carrito'**
  String get cartTitle;

  /// No description provided for @ordersTitle.
  ///
  /// In es, this message translates to:
  /// **'Mis Pedidos'**
  String get ordersTitle;

  /// No description provided for @reservationsTitle.
  ///
  /// In es, this message translates to:
  /// **'Mis Reservas'**
  String get reservationsTitle;

  /// No description provided for @quotesTitle.
  ///
  /// In es, this message translates to:
  /// **'Cotizaciones'**
  String get quotesTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In es, this message translates to:
  /// **'Configuración'**
  String get settingsTitle;

  /// No description provided for @adminPanelTitle.
  ///
  /// In es, this message translates to:
  /// **'Panel de Gestión'**
  String get adminPanelTitle;

  /// No description provided for @reportsTitle.
  ///
  /// In es, this message translates to:
  /// **'Reportes'**
  String get reportsTitle;

  /// No description provided for @technicianPanelTitle.
  ///
  /// In es, this message translates to:
  /// **'Panel Técnico'**
  String get technicianPanelTitle;

  /// No description provided for @marketingTitle.
  ///
  /// In es, this message translates to:
  /// **'Marketing'**
  String get marketingTitle;

  /// No description provided for @emptyProducts.
  ///
  /// In es, this message translates to:
  /// **'No hay productos en esta categoría'**
  String get emptyProducts;

  /// No description provided for @emptyServices.
  ///
  /// In es, this message translates to:
  /// **'No hay servicios en esta categoría'**
  String get emptyServices;

  /// No description provided for @noCategoriesConfigured.
  ///
  /// In es, this message translates to:
  /// **'No hay categorías configuradas.\nAgregue categorías desde el panel de admin.'**
  String get noCategoriesConfigured;

  /// No description provided for @noMoreProducts.
  ///
  /// In es, this message translates to:
  /// **'Pronto tendremos más productos'**
  String get noMoreProducts;

  /// No description provided for @noSearchResults.
  ///
  /// In es, this message translates to:
  /// **'No encontramos resultados'**
  String get noSearchResults;

  /// No description provided for @expertSupport.
  ///
  /// In es, this message translates to:
  /// **'Soporte técnico experto'**
  String get expertSupport;

  /// No description provided for @allCategories.
  ///
  /// In es, this message translates to:
  /// **'Todos'**
  String get allCategories;

  /// No description provided for @errorLoading.
  ///
  /// In es, this message translates to:
  /// **'Error al cargar datos'**
  String get errorLoading;

  /// No description provided for @successAddedToCart.
  ///
  /// In es, this message translates to:
  /// **'{item} agregado al carrito'**
  String successAddedToCart(String item);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
