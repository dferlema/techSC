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

  /// No description provided for @whatsappMessage.
  ///
  /// In es, this message translates to:
  /// **'Hola, estoy interesado en el servicio de {service}. ¿Podría darme más información?'**
  String whatsappMessage(String service);

  /// No description provided for @paymentMethodLabel.
  ///
  /// In es, this message translates to:
  /// **'Método de Pago'**
  String get paymentMethodLabel;

  /// No description provided for @paymentCash.
  ///
  /// In es, this message translates to:
  /// **'Efectivo'**
  String get paymentCash;

  /// No description provided for @paymentTransfer.
  ///
  /// In es, this message translates to:
  /// **'Transferencia'**
  String get paymentTransfer;

  /// No description provided for @paymentCard.
  ///
  /// In es, this message translates to:
  /// **'Tarjeta'**
  String get paymentCard;

  /// No description provided for @paymentLinkLabel.
  ///
  /// In es, this message translates to:
  /// **'Link de Pago'**
  String get paymentLinkLabel;

  /// No description provided for @paymentControlSection.
  ///
  /// In es, this message translates to:
  /// **'Control de Pagos'**
  String get paymentControlSection;

  /// No description provided for @paymentDetailsSaved.
  ///
  /// In es, this message translates to:
  /// **'Detalles de pago guardados'**
  String get paymentDetailsSaved;

  /// No description provided for @adminPanelTitle.
  ///
  /// In es, this message translates to:
  /// **'Panel de Gestión'**
  String get adminPanelTitle;

  /// No description provided for @adminPanelSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Gestiona clientes, productos, servicios y banners'**
  String get adminPanelSubtitle;

  /// No description provided for @adminPanel.
  ///
  /// In es, this message translates to:
  /// **'Panel de Administración'**
  String get adminPanel;

  /// No description provided for @clientsTab.
  ///
  /// In es, this message translates to:
  /// **'Clientes'**
  String get clientsTab;

  /// No description provided for @productsTab.
  ///
  /// In es, this message translates to:
  /// **'Productos'**
  String get productsTab;

  /// No description provided for @inventoryTab.
  ///
  /// In es, this message translates to:
  /// **'Inventario'**
  String get inventoryTab;

  /// No description provided for @servicesTab.
  ///
  /// In es, this message translates to:
  /// **'Servicios'**
  String get servicesTab;

  /// No description provided for @ordersTab.
  ///
  /// In es, this message translates to:
  /// **'Pedidos'**
  String get ordersTab;

  /// No description provided for @suppliersTab.
  ///
  /// In es, this message translates to:
  /// **'Proveedores'**
  String get suppliersTab;

  /// No description provided for @onlyAdminClients.
  ///
  /// In es, this message translates to:
  /// **'Solo administradores pueden gestionar clientes'**
  String get onlyAdminClients;

  /// No description provided for @onlyAdminSuppliers.
  ///
  /// In es, this message translates to:
  /// **'Solo administradores pueden gestionar proveedores'**
  String get onlyAdminSuppliers;

  /// No description provided for @manageCategories.
  ///
  /// In es, this message translates to:
  /// **'Gestionar Categorías'**
  String get manageCategories;

  /// No description provided for @addProduct.
  ///
  /// In es, this message translates to:
  /// **'Agregar Producto'**
  String get addProduct;

  /// No description provided for @addService.
  ///
  /// In es, this message translates to:
  /// **'Agregar Servicio'**
  String get addService;

  /// No description provided for @searchHint.
  ///
  /// In es, this message translates to:
  /// **'Buscar...'**
  String get searchHint;

  /// No description provided for @productSaveSuccess.
  ///
  /// In es, this message translates to:
  /// **'✅ Producto guardado'**
  String get productSaveSuccess;

  /// No description provided for @serviceSaveSuccess.
  ///
  /// In es, this message translates to:
  /// **'✅ Servicio guardado'**
  String get serviceSaveSuccess;

  /// No description provided for @noItemsFound.
  ///
  /// In es, this message translates to:
  /// **'No hay elementos'**
  String get noItemsFound;

  /// No description provided for @noMatchesFound.
  ///
  /// In es, this message translates to:
  /// **'No hay coincidencias'**
  String get noMatchesFound;

  /// No description provided for @productFormTitleNew.
  ///
  /// In es, this message translates to:
  /// **'Nuevo Producto'**
  String get productFormTitleNew;

  /// No description provided for @productFormTitleEdit.
  ///
  /// In es, this message translates to:
  /// **'Editar Producto'**
  String get productFormTitleEdit;

  /// No description provided for @serviceFormTitleNew.
  ///
  /// In es, this message translates to:
  /// **'Nuevo Servicio'**
  String get serviceFormTitleNew;

  /// No description provided for @serviceFormTitleEdit.
  ///
  /// In es, this message translates to:
  /// **'Editar Servicio'**
  String get serviceFormTitleEdit;

  /// No description provided for @productImages.
  ///
  /// In es, this message translates to:
  /// **'Imágenes del Producto *'**
  String get productImages;

  /// No description provided for @serviceImages.
  ///
  /// In es, this message translates to:
  /// **'Imágenes del Servicio *'**
  String get serviceImages;

  /// No description provided for @imageLinkHint.
  ///
  /// In es, this message translates to:
  /// **'https://ejemplo.com/imagen.jpg'**
  String get imageLinkHint;

  /// No description provided for @addImage.
  ///
  /// In es, this message translates to:
  /// **'Agregar Imagen'**
  String get addImage;

  /// No description provided for @mainImageLabel.
  ///
  /// In es, this message translates to:
  /// **'Principal'**
  String get mainImageLabel;

  /// No description provided for @noImagesAdded.
  ///
  /// In es, this message translates to:
  /// **'No hay imágenes agregadas'**
  String get noImagesAdded;

  /// No description provided for @productName.
  ///
  /// In es, this message translates to:
  /// **'Nombre *'**
  String get productName;

  /// No description provided for @productSpecs.
  ///
  /// In es, this message translates to:
  /// **'Especificaciones'**
  String get productSpecs;

  /// No description provided for @productDescription.
  ///
  /// In es, this message translates to:
  /// **'Descripción'**
  String get productDescription;

  /// No description provided for @productPrice.
  ///
  /// In es, this message translates to:
  /// **'Precio *'**
  String get productPrice;

  /// No description provided for @productCategory.
  ///
  /// In es, this message translates to:
  /// **'Categoría *'**
  String get productCategory;

  /// No description provided for @productLabel.
  ///
  /// In es, this message translates to:
  /// **'Etiqueta (Opcional)'**
  String get productLabel;

  /// No description provided for @taxStatus.
  ///
  /// In es, this message translates to:
  /// **'Estado de Impuestos'**
  String get taxStatus;

  /// No description provided for @ratingLabel.
  ///
  /// In es, this message translates to:
  /// **'Calificación'**
  String get ratingLabel;

  /// No description provided for @featuredProduct.
  ///
  /// In es, this message translates to:
  /// **'Producto Destacado'**
  String get featuredProduct;

  /// No description provided for @featuredProductSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Aparecerá en la sección de destacados del inicio'**
  String get featuredProductSubtitle;

  /// No description provided for @featuredService.
  ///
  /// In es, this message translates to:
  /// **'Servicio Destacado'**
  String get featuredService;

  /// No description provided for @featuredServiceSubtitle.
  ///
  /// In es, this message translates to:
  /// **'Aparecerá en la sección de destacados del inicio'**
  String get featuredServiceSubtitle;

  /// No description provided for @supplierInfo.
  ///
  /// In es, this message translates to:
  /// **'Información del Proveedor'**
  String get supplierInfo;

  /// No description provided for @supplierLink.
  ///
  /// In es, this message translates to:
  /// **'Link del Producto del Proveedor'**
  String get supplierLink;

  /// No description provided for @save.
  ///
  /// In es, this message translates to:
  /// **'Guardar'**
  String get save;

  /// No description provided for @atLeastOneImage.
  ///
  /// In es, this message translates to:
  /// **'⚠️ Agrega al menos una imagen'**
  String get atLeastOneImage;

  /// No description provided for @invalidPrice.
  ///
  /// In es, this message translates to:
  /// **'Válido > 0'**
  String get invalidPrice;

  /// No description provided for @enterLinkFirst.
  ///
  /// In es, this message translates to:
  /// **'Ingresa un link primero'**
  String get enterLinkFirst;

  /// No description provided for @preview.
  ///
  /// In es, this message translates to:
  /// **'Previa'**
  String get preview;

  /// No description provided for @cancel.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancel;

  /// No description provided for @saveSuccess.
  ///
  /// In es, this message translates to:
  /// **'✅ Guardado correctamente'**
  String get saveSuccess;

  /// No description provided for @deleteSuccess.
  ///
  /// In es, this message translates to:
  /// **'✅ Elemento eliminado'**
  String get deleteSuccess;

  /// No description provided for @errorPrefix.
  ///
  /// In es, this message translates to:
  /// **'Error'**
  String get errorPrefix;

  /// No description provided for @accessDenied.
  ///
  /// In es, this message translates to:
  /// **'Acceso Denegado'**
  String get accessDenied;

  /// No description provided for @authorizedPersonnelOnly.
  ///
  /// In es, this message translates to:
  /// **'Solo personal autorizado puede acceder.'**
  String get authorizedPersonnelOnly;

  /// No description provided for @backButton.
  ///
  /// In es, this message translates to:
  /// **'Volver'**
  String get backButton;

  /// No description provided for @advancedSearch.
  ///
  /// In es, this message translates to:
  /// **'Búsqueda Avanzada'**
  String get advancedSearch;

  /// No description provided for @startDate.
  ///
  /// In es, this message translates to:
  /// **'Fecha inicio'**
  String get startDate;

  /// No description provided for @endDate.
  ///
  /// In es, this message translates to:
  /// **'Fecha fin'**
  String get endDate;

  /// No description provided for @from.
  ///
  /// In es, this message translates to:
  /// **'Desde'**
  String get from;

  /// No description provided for @to.
  ///
  /// In es, this message translates to:
  /// **'Hasta'**
  String get to;

  /// No description provided for @clearFilters.
  ///
  /// In es, this message translates to:
  /// **'Limpiar'**
  String get clearFilters;

  /// No description provided for @exportCSV.
  ///
  /// In es, this message translates to:
  /// **'CSV'**
  String get exportCSV;

  /// No description provided for @exportPDF.
  ///
  /// In es, this message translates to:
  /// **'PDF'**
  String get exportPDF;

  /// No description provided for @csvSaved.
  ///
  /// In es, this message translates to:
  /// **'✅ CSV guardado en documentos'**
  String get csvSaved;

  /// No description provided for @pdfError.
  ///
  /// In es, this message translates to:
  /// **'❌ Error al generar PDF'**
  String get pdfError;

  /// No description provided for @showingCount.
  ///
  /// In es, this message translates to:
  /// **'Mostrando {count} de {total} clientes'**
  String showingCount(int count, int total);

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

  /// No description provided for @serviceDeleted.
  ///
  /// In es, this message translates to:
  /// **'Servicio eliminado'**
  String get serviceDeleted;

  /// No description provided for @addedToCart.
  ///
  /// In es, this message translates to:
  /// **'✅ {item} agregado al carrito'**
  String addedToCart(Object item);

  /// No description provided for @viewCart.
  ///
  /// In es, this message translates to:
  /// **'VER'**
  String get viewCart;

  /// No description provided for @buyButton.
  ///
  /// In es, this message translates to:
  /// **'Comprar'**
  String get buyButton;

  /// No description provided for @editUsingAdminPanel.
  ///
  /// In es, this message translates to:
  /// **'Usa el Panel Admin para editar'**
  String get editUsingAdminPanel;

  /// No description provided for @scheduleReservation.
  ///
  /// In es, this message translates to:
  /// **'Agendar Cita'**
  String get scheduleReservation;

  /// No description provided for @confirmReservation.
  ///
  /// In es, this message translates to:
  /// **'Confirmar Cita'**
  String get confirmReservation;

  /// No description provided for @selectDate.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar Fecha'**
  String get selectDate;

  /// No description provided for @selectTime.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar Hora'**
  String get selectTime;

  /// No description provided for @yourReservations.
  ///
  /// In es, this message translates to:
  /// **'Mis Citas'**
  String get yourReservations;

  /// No description provided for @noReservations.
  ///
  /// In es, this message translates to:
  /// **'No tienes citas agendadas'**
  String get noReservations;

  /// No description provided for @descriptionTitle.
  ///
  /// In es, this message translates to:
  /// **'Descripción'**
  String get descriptionTitle;

  /// No description provided for @rateService.
  ///
  /// In es, this message translates to:
  /// **'Calificar este servicio'**
  String get rateService;

  /// No description provided for @shareWhatsApp.
  ///
  /// In es, this message translates to:
  /// **'Compartir por WhatsApp'**
  String get shareWhatsApp;

  /// No description provided for @addedHighlight.
  ///
  /// In es, this message translates to:
  /// **'¡Agregado!'**
  String get addedHighlight;

  /// No description provided for @reserveButton.
  ///
  /// In es, this message translates to:
  /// **'Reservar'**
  String get reserveButton;

  /// No description provided for @technicalServiceTitle.
  ///
  /// In es, this message translates to:
  /// **'Servicio Técnico'**
  String get technicalServiceTitle;

  /// No description provided for @workshopRegistration.
  ///
  /// In es, this message translates to:
  /// **'Registro de Trabajo (Taller)'**
  String get workshopRegistration;

  /// No description provided for @completeRequestDetails.
  ///
  /// In es, this message translates to:
  /// **'Completa los detalles de tu requerimiento'**
  String get completeRequestDetails;

  /// No description provided for @scheduleWithPros.
  ///
  /// In es, this message translates to:
  /// **'Agenda tu cita con profesionales'**
  String get scheduleWithPros;

  /// No description provided for @cancelButton.
  ///
  /// In es, this message translates to:
  /// **'Cancelar'**
  String get cancelButton;

  /// No description provided for @needTechnicalHelp.
  ///
  /// In es, this message translates to:
  /// **'¿Necesitas ayuda técnica?'**
  String get needTechnicalHelp;

  /// No description provided for @workshopWelcomeDesc.
  ///
  /// In es, this message translates to:
  /// **'Registra un trabajo para un cliente que no está en la aplicación. Podrás dar seguimiento y generar comprobante.'**
  String get workshopWelcomeDesc;

  /// No description provided for @reservationWelcomeDesc.
  ///
  /// In es, this message translates to:
  /// **'Agenda una revisión para tus equipos hoy mismo. Cargaremos tus datos guardados automáticamente para tu comodidad.'**
  String get reservationWelcomeDesc;

  /// No description provided for @registerNewJob.
  ///
  /// In es, this message translates to:
  /// **'REGISTRAR NUEVO TRABAJO'**
  String get registerNewJob;

  /// No description provided for @startNewReservation.
  ///
  /// In es, this message translates to:
  /// **'COMENZAR NUEVA RESERVA'**
  String get startNewReservation;

  /// No description provided for @officialSupport.
  ///
  /// In es, this message translates to:
  /// **'Respaldo oficial {appName}'**
  String officialSupport(Object appName);

  /// No description provided for @certifiedTechs.
  ///
  /// In es, this message translates to:
  /// **'Técnicos certificados con amplia experiencia'**
  String get certifiedTechs;

  /// No description provided for @fullWarranty.
  ///
  /// In es, this message translates to:
  /// **'Garantía total en todos los repuestos'**
  String get fullWarranty;

  /// No description provided for @personalInfoSection.
  ///
  /// In es, this message translates to:
  /// **'Información Personal'**
  String get personalInfoSection;

  /// No description provided for @deviceDetailsSection.
  ///
  /// In es, this message translates to:
  /// **'Detalles del Equipo'**
  String get deviceDetailsSection;

  /// No description provided for @serviceProblemSection.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar Servicio'**
  String get serviceProblemSection;

  /// No description provided for @scheduleAppointmentSection.
  ///
  /// In es, this message translates to:
  /// **'Programar Cita'**
  String get scheduleAppointmentSection;

  /// No description provided for @importantInfoSection.
  ///
  /// In es, this message translates to:
  /// **'Información Importante'**
  String get importantInfoSection;

  /// No description provided for @fullNameLabelRequired.
  ///
  /// In es, this message translates to:
  /// **'Nombre Completo *'**
  String get fullNameLabelRequired;

  /// No description provided for @idLabelRequired.
  ///
  /// In es, this message translates to:
  /// **'Cédula *'**
  String get idLabelRequired;

  /// No description provided for @emailLabelRequired.
  ///
  /// In es, this message translates to:
  /// **'Correo Electrónico *'**
  String get emailLabelRequired;

  /// No description provided for @phoneLabelRequired.
  ///
  /// In es, this message translates to:
  /// **'Teléfono *'**
  String get phoneLabelRequired;

  /// No description provided for @deviceModelLabelRequired.
  ///
  /// In es, this message translates to:
  /// **'Dispositivo / Modelo *'**
  String get deviceModelLabelRequired;

  /// No description provided for @pickupAddressLabelRequired.
  ///
  /// In es, this message translates to:
  /// **'Dirección de Retiro *'**
  String get pickupAddressLabelRequired;

  /// No description provided for @serviceTypeLabelRequired.
  ///
  /// In es, this message translates to:
  /// **'Tipo de Servicio *'**
  String get serviceTypeLabelRequired;

  /// No description provided for @describeProblemLabelRequired.
  ///
  /// In es, this message translates to:
  /// **'Describe el Problema *'**
  String get describeProblemLabelRequired;

  /// No description provided for @dateLabelRequired.
  ///
  /// In es, this message translates to:
  /// **'Fecha *'**
  String get dateLabelRequired;

  /// No description provided for @timeLabelRequired.
  ///
  /// In es, this message translates to:
  /// **'Hora *'**
  String get timeLabelRequired;

  /// No description provided for @useCurrentLocation.
  ///
  /// In es, this message translates to:
  /// **'Usar mi ubicación actual'**
  String get useCurrentLocation;

  /// No description provided for @locationSelected.
  ///
  /// In es, this message translates to:
  /// **'Ubicación seleccionada'**
  String get locationSelected;

  /// No description provided for @contactConfirmationInfo.
  ///
  /// In es, this message translates to:
  /// **'Te contactaremos para confirmar tu cita en las próximas 2 horas'**
  String get contactConfirmationInfo;

  /// No description provided for @cancelNoticeInfo.
  ///
  /// In es, this message translates to:
  /// **'Si necesitas cancelar, hazlo con al menos 24 horas de anticipación'**
  String get cancelNoticeInfo;

  /// No description provided for @bringAccessoriesInfo.
  ///
  /// In es, this message translates to:
  /// **'Trae tu dispositivo con el cargador y accesorios necesarios'**
  String get bringAccessoriesInfo;

  /// No description provided for @freeDiagnosticInfo.
  ///
  /// In es, this message translates to:
  /// **'El diagnóstico inicial es gratuito'**
  String get freeDiagnosticInfo;

  /// No description provided for @confirmReservationButton.
  ///
  /// In es, this message translates to:
  /// **'CONFIRMAR RESERVA'**
  String get confirmReservationButton;

  /// No description provided for @reservationSuccess.
  ///
  /// In es, this message translates to:
  /// **'✅ Reserva creada con éxito'**
  String get reservationSuccess;

  /// No description provided for @doneButton.
  ///
  /// In es, this message translates to:
  /// **'Listo'**
  String get doneButton;

  /// No description provided for @errorSaving.
  ///
  /// In es, this message translates to:
  /// **'❌ Error al guardar: {error}'**
  String errorSaving(Object error);

  /// No description provided for @autocompleteSuccess.
  ///
  /// In es, this message translates to:
  /// **'✅ Se autocompletaron {count} campos de tu perfil'**
  String autocompleteSuccess(Object count);

  /// No description provided for @incompleteProfileWarning.
  ///
  /// In es, this message translates to:
  /// **'⚠️ Tu perfil está incompleto. Completa tus datos para autocompletar.'**
  String get incompleteProfileWarning;

  /// No description provided for @profileNotFoundWarning.
  ///
  /// In es, this message translates to:
  /// **'⚠️ Perfil no encontrado. Por favor completa tus datos.'**
  String get profileNotFoundWarning;

  /// No description provided for @errorLoadingProfile.
  ///
  /// In es, this message translates to:
  /// **'⚠️ Error cargando perfil: {error}'**
  String errorLoadingProfile(Object error);

  /// No description provided for @locationSuccess.
  ///
  /// In es, this message translates to:
  /// **'📍 Ubicación obtenida correctamente'**
  String get locationSuccess;

  /// No description provided for @selectDatePrompt.
  ///
  /// In es, this message translates to:
  /// **'Selecciona una fecha'**
  String get selectDatePrompt;

  /// No description provided for @selectTimePrompt.
  ///
  /// In es, this message translates to:
  /// **'Selecciona una hora'**
  String get selectTimePrompt;

  /// No description provided for @invalidEmail.
  ///
  /// In es, this message translates to:
  /// **'Correo inválido'**
  String get invalidEmail;

  /// No description provided for @requiredField.
  ///
  /// In es, this message translates to:
  /// **'Obligatorio'**
  String get requiredField;

  /// No description provided for @tenDigits.
  ///
  /// In es, this message translates to:
  /// **'10 dígitos'**
  String get tenDigits;

  /// No description provided for @phoneFormatError.
  ///
  /// In es, this message translates to:
  /// **'Debe iniciar con 09 y tener 10 dígitos'**
  String get phoneFormatError;

  /// No description provided for @date.
  ///
  /// In es, this message translates to:
  /// **'Fecha'**
  String get date;

  /// No description provided for @time.
  ///
  /// In es, this message translates to:
  /// **'Hora'**
  String get time;

  /// No description provided for @address.
  ///
  /// In es, this message translates to:
  /// **'Dirección'**
  String get address;

  /// No description provided for @location.
  ///
  /// In es, this message translates to:
  /// **'Ubicación'**
  String get location;

  /// No description provided for @problemDescription.
  ///
  /// In es, this message translates to:
  /// **'Descripción del Problema'**
  String get problemDescription;

  /// No description provided for @thanksForTrusting.
  ///
  /// In es, this message translates to:
  /// **'¡Gracias por confiar en {appName}!'**
  String thanksForTrusting(Object appName);

  /// No description provided for @mustLoginToViewReservations.
  ///
  /// In es, this message translates to:
  /// **'Debes iniciar sesión para ver tus reservas'**
  String get mustLoginToViewReservations;

  /// No description provided for @reservationEmptyDesc.
  ///
  /// In es, this message translates to:
  /// **'Tus solicitudes de servicio aparecerán aquí'**
  String get reservationEmptyDesc;

  /// No description provided for @statusPending.
  ///
  /// In es, this message translates to:
  /// **'Pendiente'**
  String get statusPending;

  /// No description provided for @statusConfirmed.
  ///
  /// In es, this message translates to:
  /// **'Confirmado'**
  String get statusConfirmed;

  /// No description provided for @statusInProcess.
  ///
  /// In es, this message translates to:
  /// **'En Proceso'**
  String get statusInProcess;

  /// No description provided for @statusApproved.
  ///
  /// In es, this message translates to:
  /// **'Aprobado'**
  String get statusApproved;

  /// No description provided for @statusCompleted.
  ///
  /// In es, this message translates to:
  /// **'Completado'**
  String get statusCompleted;

  /// No description provided for @statusRejected.
  ///
  /// In es, this message translates to:
  /// **'Rechazado'**
  String get statusRejected;

  /// No description provided for @statusCancelled.
  ///
  /// In es, this message translates to:
  /// **'Cancelado'**
  String get statusCancelled;

  /// No description provided for @statusPrefix.
  ///
  /// In es, this message translates to:
  /// **'Estado'**
  String get statusPrefix;

  /// No description provided for @fullNameLabelLabel.
  ///
  /// In es, this message translates to:
  /// **'Nombre'**
  String get fullNameLabelLabel;

  /// No description provided for @idLabelLabel.
  ///
  /// In es, this message translates to:
  /// **'Cédula'**
  String get idLabelLabel;

  /// No description provided for @emailLabelLabel.
  ///
  /// In es, this message translates to:
  /// **'Correo'**
  String get emailLabelLabel;

  /// No description provided for @phoneLabelLabel.
  ///
  /// In es, this message translates to:
  /// **'Teléfono'**
  String get phoneLabelLabel;

  /// No description provided for @addressLabelLabel.
  ///
  /// In es, this message translates to:
  /// **'Dirección'**
  String get addressLabelLabel;

  /// No description provided for @deviceModelLabelLabel.
  ///
  /// In es, this message translates to:
  /// **'Dispositivo'**
  String get deviceModelLabelLabel;

  /// No description provided for @serviceTypeLabelLabel.
  ///
  /// In es, this message translates to:
  /// **'Servicio'**
  String get serviceTypeLabelLabel;

  /// No description provided for @clientInfoSection.
  ///
  /// In es, this message translates to:
  /// **'Datos del Cliente'**
  String get clientInfoSection;

  /// No description provided for @serviceDetailsSection.
  ///
  /// In es, this message translates to:
  /// **'Detalles del Servicio'**
  String get serviceDetailsSection;

  /// No description provided for @reportedProblemLabel.
  ///
  /// In es, this message translates to:
  /// **'Problema Reportado'**
  String get reportedProblemLabel;

  /// No description provided for @managementSection.
  ///
  /// In es, this message translates to:
  /// **'Gestión y Seguimiento'**
  String get managementSection;

  /// No description provided for @techCommentsLabel.
  ///
  /// In es, this message translates to:
  /// **'Comentarios Técnicos'**
  String get techCommentsLabel;

  /// No description provided for @solutionLabel.
  ///
  /// In es, this message translates to:
  /// **'Solución Aplicada'**
  String get solutionLabel;

  /// No description provided for @repairCostLabel.
  ///
  /// In es, this message translates to:
  /// **'Costo de Reparación'**
  String get repairCostLabel;

  /// No description provided for @sparePartsLabel.
  ///
  /// In es, this message translates to:
  /// **'Repuestos'**
  String get sparePartsLabel;

  /// No description provided for @laborCostLabel.
  ///
  /// In es, this message translates to:
  /// **'Mano de Obra'**
  String get laborCostLabel;

  /// No description provided for @estimatedTotalLabel.
  ///
  /// In es, this message translates to:
  /// **'Total Estimado'**
  String get estimatedTotalLabel;

  /// No description provided for @reservationCompletedWarning.
  ///
  /// In es, this message translates to:
  /// **'Esta reserva está completada y no puede ser modificada'**
  String get reservationCompletedWarning;

  /// No description provided for @saveChanges.
  ///
  /// In es, this message translates to:
  /// **'Guardar cambios'**
  String get saveChanges;

  /// No description provided for @updatesAppliedSuccess.
  ///
  /// In es, this message translates to:
  /// **'Cambios guardados con éxito'**
  String get updatesAppliedSuccess;

  /// No description provided for @techDetailsSaved.
  ///
  /// In es, this message translates to:
  /// **'Detalles técnicos guardados'**
  String get techDetailsSaved;

  /// No description provided for @reservationDetailTitle.
  ///
  /// In es, this message translates to:
  /// **'Detalle de Reserva'**
  String get reservationDetailTitle;

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

  /// No description provided for @selectSpareParts.
  ///
  /// In es, this message translates to:
  /// **'Seleccionar Repuestos'**
  String get selectSpareParts;

  /// No description provided for @searchProduct.
  ///
  /// In es, this message translates to:
  /// **'Buscar Repuesto'**
  String get searchProduct;

  /// No description provided for @searchProductHint.
  ///
  /// In es, this message translates to:
  /// **'Buscar por nombre de producto...'**
  String get searchProductHint;

  /// No description provided for @errorLoadingProducts.
  ///
  /// In es, this message translates to:
  /// **'Error al cargar repuestos'**
  String get errorLoadingProducts;

  /// No description provided for @successAddedToCart.
  ///
  /// In es, this message translates to:
  /// **'{item} agregado al carrito'**
  String successAddedToCart(String item);

  /// No description provided for @whatsappMarketingTitle.
  ///
  /// In es, this message translates to:
  /// **'Campaña de Marketing WhatsApp'**
  String get whatsappMarketingTitle;

  /// No description provided for @marketingPrompt.
  ///
  /// In es, this message translates to:
  /// **'Selecciona un producto para comenzar la campaña'**
  String get marketingPrompt;

  /// No description provided for @step1SelectProduct.
  ///
  /// In es, this message translates to:
  /// **'1. Selecciona el Producto (Búsqueda Inteligente)'**
  String get step1SelectProduct;

  /// No description provided for @noProductsFound.
  ///
  /// In es, this message translates to:
  /// **'No se encontraron productos'**
  String get noProductsFound;

  /// No description provided for @promotingText.
  ///
  /// In es, this message translates to:
  /// **'Promocionando: {productName}'**
  String promotingText(Object productName);

  /// No description provided for @marketingDescription.
  ///
  /// In es, this message translates to:
  /// **'Envía mensajes individuales o descarga el CSV para envíos masivos.'**
  String get marketingDescription;

  /// No description provided for @exportCSVTooltip.
  ///
  /// In es, this message translates to:
  /// **'Exportar CSV para WaSender'**
  String get exportCSVTooltip;

  /// No description provided for @searchClientHint.
  ///
  /// In es, this message translates to:
  /// **'Buscar clientes...'**
  String get searchClientHint;

  /// No description provided for @noClientsFound.
  ///
  /// In es, this message translates to:
  /// **'No se encontraron clientes'**
  String get noClientsFound;

  /// No description provided for @noPhoneNumber.
  ///
  /// In es, this message translates to:
  /// **'Este cliente no tiene número de teléfono'**
  String get noPhoneNumber;

  /// No description provided for @addClient.
  ///
  /// In es, this message translates to:
  /// **'Agregar Cliente'**
  String get addClient;

  /// No description provided for @settingsPageTitle.
  ///
  /// In es, this message translates to:
  /// **'Configuraciones'**
  String get settingsPageTitle;

  /// No description provided for @companyInfoTab.
  ///
  /// In es, this message translates to:
  /// **'Información'**
  String get companyInfoTab;

  /// No description provided for @bannersTab.
  ///
  /// In es, this message translates to:
  /// **'Banners'**
  String get bannersTab;

  /// No description provided for @securityTab.
  ///
  /// In es, this message translates to:
  /// **'Seguridad'**
  String get securityTab;

  /// No description provided for @companyNameLabel.
  ///
  /// In es, this message translates to:
  /// **'Nombre de la Empresa'**
  String get companyNameLabel;

  /// No description provided for @companyEmailLabel.
  ///
  /// In es, this message translates to:
  /// **'Correo Electrónico'**
  String get companyEmailLabel;

  /// No description provided for @companyPhoneLabel.
  ///
  /// In es, this message translates to:
  /// **'Teléfono (WhatsApp, sin +)'**
  String get companyPhoneLabel;

  /// No description provided for @companyPhoneHelper.
  ///
  /// In es, this message translates to:
  /// **'Ej: 593991090805'**
  String get companyPhoneHelper;

  /// No description provided for @companyAddressLabel.
  ///
  /// In es, this message translates to:
  /// **'Dirección'**
  String get companyAddressLabel;

  /// No description provided for @saveSettingsButton.
  ///
  /// In es, this message translates to:
  /// **'Guardar Cambios'**
  String get saveSettingsButton;

  /// No description provided for @settingsUpdateSuccess.
  ///
  /// In es, this message translates to:
  /// **'Información actualizada correctamente'**
  String get settingsUpdateSuccess;

  /// No description provided for @addBannerButton.
  ///
  /// In es, this message translates to:
  /// **'Agregar Nuevo Banner'**
  String get addBannerButton;

  /// No description provided for @addBannerDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Agregar Banner por URL'**
  String get addBannerDialogTitle;

  /// No description provided for @bannerUrlLabel.
  ///
  /// In es, this message translates to:
  /// **'URL de la imagen'**
  String get bannerUrlLabel;

  /// No description provided for @addBannerDialogAction.
  ///
  /// In es, this message translates to:
  /// **'Agregar'**
  String get addBannerDialogAction;

  /// No description provided for @deleteBannerDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Eliminar Banner'**
  String get deleteBannerDialogTitle;

  /// No description provided for @deleteBannerDialogContent.
  ///
  /// In es, this message translates to:
  /// **'¿Estás seguro de que deseas eliminar este banner?'**
  String get deleteBannerDialogContent;

  /// No description provided for @deleteBannerDialogAction.
  ///
  /// In es, this message translates to:
  /// **'Eliminar'**
  String get deleteBannerDialogAction;

  /// No description provided for @biometricLoginLabel.
  ///
  /// In es, this message translates to:
  /// **'Inicio de Sesión Biométrico'**
  String get biometricLoginLabel;

  /// No description provided for @biometricEnabledStatus.
  ///
  /// In es, this message translates to:
  /// **'Habilitado - Puedes iniciar sesión con tu huella o rostro'**
  String get biometricEnabledStatus;

  /// No description provided for @biometricDisabledStatus.
  ///
  /// In es, this message translates to:
  /// **'Deshabilitado - Inicia sesión manualmente para habilitar'**
  String get biometricDisabledStatus;

  /// No description provided for @biometricDisableWarning.
  ///
  /// In es, this message translates to:
  /// **'Para deshabilitar, apaga el interruptor arriba.'**
  String get biometricDisableWarning;

  /// No description provided for @biometricEnableInstructions.
  ///
  /// In es, this message translates to:
  /// **'Para habilitar la biometría, cierra sesión e inicia sesión manualmente. Se te preguntará si deseas activarla.'**
  String get biometricEnableInstructions;

  /// No description provided for @biometricDisableDialogTitle.
  ///
  /// In es, this message translates to:
  /// **'Deshabilitar Biometría'**
  String get biometricDisableDialogTitle;

  /// No description provided for @biometricDisableDialogContent.
  ///
  /// In es, this message translates to:
  /// **'¿Estás seguro de que deseas deshabilitar el inicio de sesión biométrico?\\n\\nTendrás que iniciar sesión manualmente la próxima vez.'**
  String get biometricDisableDialogContent;

  /// No description provided for @biometricDisableDialogAction.
  ///
  /// In es, this message translates to:
  /// **'Deshabilitar'**
  String get biometricDisableDialogAction;

  /// No description provided for @biometricDisabledSuccess.
  ///
  /// In es, this message translates to:
  /// **'Inicio de sesión biométrico desactivado.'**
  String get biometricDisabledSuccess;

  /// No description provided for @noBannersConfigured.
  ///
  /// In es, this message translates to:
  /// **'No hay banners configurados'**
  String get noBannersConfigured;

  /// No description provided for @bannerAddedSuccess.
  ///
  /// In es, this message translates to:
  /// **'Banner agregado correctamente'**
  String get bannerAddedSuccess;

  /// No description provided for @bannerDeletedSuccess.
  ///
  /// In es, this message translates to:
  /// **'Banner eliminado correctamente'**
  String get bannerDeletedSuccess;

  /// No description provided for @payphoneTokenLabel.
  ///
  /// In es, this message translates to:
  /// **'Token de Pago (Payphone)'**
  String get payphoneTokenLabel;

  /// No description provided for @payphoneStoreIdLabel.
  ///
  /// In es, this message translates to:
  /// **'ID de Tienda (StoreID)'**
  String get payphoneStoreIdLabel;

  /// No description provided for @payphoneSandboxLabel.
  ///
  /// In es, this message translates to:
  /// **'Modo Sandbox (Pruebas)'**
  String get payphoneSandboxLabel;

  /// No description provided for @integrationsTab.
  ///
  /// In es, this message translates to:
  /// **'Integraciones'**
  String get integrationsTab;
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
