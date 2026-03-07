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
  String whatsappMessage(String service) {
    return 'Hola, estoy interesado en el servicio de $service. ¿Podría darme más información?';
  }

  @override
  String get paymentMethodLabel => 'Método de Pago';

  @override
  String get paymentCash => 'Efectivo';

  @override
  String get paymentTransfer => 'Transferencia';

  @override
  String get paymentCard => 'Tarjeta';

  @override
  String get paymentLinkLabel => 'Link de Pago';

  @override
  String get paymentControlSection => 'Control de Pagos';

  @override
  String get paymentDetailsSaved => 'Detalles de pago guardados';

  @override
  String get adminPanelTitle => 'Panel de Gestión';

  @override
  String get adminPanelSubtitle =>
      'Gestiona clientes, productos, servicios y banners';

  @override
  String get adminPanel => 'Panel de Administración';

  @override
  String get clientsTab => 'Clientes';

  @override
  String get productsTab => 'Productos';

  @override
  String get inventoryTab => 'Inventario';

  @override
  String get servicesTab => 'Servicios';

  @override
  String get ordersTab => 'Pedidos';

  @override
  String get suppliersTab => 'Proveedores';

  @override
  String get onlyAdminClients =>
      'Solo administradores pueden gestionar clientes';

  @override
  String get onlyAdminSuppliers =>
      'Solo administradores pueden gestionar proveedores';

  @override
  String get manageCategories => 'Gestionar Categorías';

  @override
  String get addProduct => 'Agregar Producto';

  @override
  String get addService => 'Agregar Servicio';

  @override
  String get searchHint => 'Buscar...';

  @override
  String get productSaveSuccess => '✅ Producto guardado';

  @override
  String get serviceSaveSuccess => '✅ Servicio guardado';

  @override
  String get noItemsFound => 'No hay elementos';

  @override
  String get noMatchesFound => 'No hay coincidencias';

  @override
  String get productFormTitleNew => 'Nuevo Producto';

  @override
  String get productFormTitleEdit => 'Editar Producto';

  @override
  String get serviceFormTitleNew => 'Nuevo Servicio';

  @override
  String get serviceFormTitleEdit => 'Editar Servicio';

  @override
  String get productImages => 'Imágenes del Producto *';

  @override
  String get serviceImages => 'Imágenes del Servicio *';

  @override
  String get imageLinkHint => 'https://ejemplo.com/imagen.jpg';

  @override
  String get addImage => 'Agregar Imagen';

  @override
  String get mainImageLabel => 'Principal';

  @override
  String get noImagesAdded => 'No hay imágenes agregadas';

  @override
  String get productName => 'Nombre *';

  @override
  String get productSpecs => 'Especificaciones';

  @override
  String get productDescription => 'Descripción';

  @override
  String get productPrice => 'Precio *';

  @override
  String get productCategory => 'Categoría *';

  @override
  String get productLabel => 'Etiqueta (Opcional)';

  @override
  String get taxStatus => 'Estado de Impuestos';

  @override
  String get ratingLabel => 'Calificación';

  @override
  String get featuredProduct => 'Producto Destacado';

  @override
  String get featuredProductSubtitle =>
      'Aparecerá en la sección de destacados del inicio';

  @override
  String get featuredService => 'Servicio Destacado';

  @override
  String get featuredServiceSubtitle =>
      'Aparecerá en la sección de destacados del inicio';

  @override
  String get supplierInfo => 'Información del Proveedor';

  @override
  String get supplierLink => 'Link del Producto del Proveedor';

  @override
  String get save => 'Guardar';

  @override
  String get atLeastOneImage => '⚠️ Agrega al menos una imagen';

  @override
  String get invalidPrice => 'Válido > 0';

  @override
  String get enterLinkFirst => 'Ingresa un link primero';

  @override
  String get preview => 'Previa';

  @override
  String get cancel => 'Cancelar';

  @override
  String get saveSuccess => '✅ Guardado correctamente';

  @override
  String get deleteSuccess => '✅ Elemento eliminado';

  @override
  String get errorPrefix => 'Error';

  @override
  String get accessDenied => 'Acceso Denegado';

  @override
  String get authorizedPersonnelOnly =>
      'Solo personal autorizado puede acceder.';

  @override
  String get backButton => 'Volver';

  @override
  String get advancedSearch => 'Búsqueda Avanzada';

  @override
  String get startDate => 'Fecha inicio';

  @override
  String get endDate => 'Fecha fin';

  @override
  String get from => 'Desde';

  @override
  String get to => 'Hasta';

  @override
  String get clearFilters => 'Limpiar';

  @override
  String get exportCSV => 'CSV';

  @override
  String get exportPDF => 'PDF';

  @override
  String get csvSaved => '✅ CSV guardado en documentos';

  @override
  String get pdfError => '❌ Error al generar PDF';

  @override
  String showingCount(int count, int total) {
    return 'Mostrando $count de $total clientes';
  }

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
  String get serviceDeleted => 'Servicio eliminado';

  @override
  String addedToCart(Object item) {
    return '✅ $item agregado al carrito';
  }

  @override
  String get viewCart => 'VER';

  @override
  String get buyButton => 'Comprar';

  @override
  String get editUsingAdminPanel => 'Usa el Panel Admin para editar';

  @override
  String get scheduleReservation => 'Agendar Cita';

  @override
  String get confirmReservation => 'Confirmar Cita';

  @override
  String get selectDate => 'Seleccionar Fecha';

  @override
  String get selectTime => 'Seleccionar Hora';

  @override
  String get yourReservations => 'Mis Citas';

  @override
  String get noReservations => 'No tienes citas agendadas';

  @override
  String get descriptionTitle => 'Descripción';

  @override
  String get rateService => 'Calificar este servicio';

  @override
  String get shareWhatsApp => 'Compartir por WhatsApp';

  @override
  String get addedHighlight => '¡Agregado!';

  @override
  String get reserveButton => 'Reservar';

  @override
  String get technicalServiceTitle => 'Servicio Técnico';

  @override
  String get workshopRegistration => 'Registro de Trabajo (Taller)';

  @override
  String get completeRequestDetails =>
      'Completa los detalles de tu requerimiento';

  @override
  String get scheduleWithPros => 'Agenda tu cita con profesionales';

  @override
  String get cancelButton => 'Cancelar';

  @override
  String get needTechnicalHelp => '¿Necesitas ayuda técnica?';

  @override
  String get workshopWelcomeDesc =>
      'Registra un trabajo para un cliente que no está en la aplicación. Podrás dar seguimiento y generar comprobante.';

  @override
  String get reservationWelcomeDesc =>
      'Agenda una revisión para tus equipos hoy mismo. Cargaremos tus datos guardados automáticamente para tu comodidad.';

  @override
  String get registerNewJob => 'REGISTRAR NUEVO TRABAJO';

  @override
  String get startNewReservation => 'COMENZAR NUEVA RESERVA';

  @override
  String officialSupport(Object appName) {
    return 'Respaldo oficial $appName';
  }

  @override
  String get certifiedTechs => 'Técnicos certificados con amplia experiencia';

  @override
  String get fullWarranty => 'Garantía total en todos los repuestos';

  @override
  String get personalInfoSection => 'Información Personal';

  @override
  String get deviceDetailsSection => 'Detalles del Equipo';

  @override
  String get serviceProblemSection => 'Seleccionar Servicio';

  @override
  String get scheduleAppointmentSection => 'Programar Cita';

  @override
  String get importantInfoSection => 'Información Importante';

  @override
  String get fullNameLabelRequired => 'Nombre Completo *';

  @override
  String get idLabelRequired => 'Cédula *';

  @override
  String get emailLabelRequired => 'Correo Electrónico *';

  @override
  String get phoneLabelRequired => 'Teléfono *';

  @override
  String get deviceModelLabelRequired => 'Dispositivo / Modelo *';

  @override
  String get pickupAddressLabelRequired => 'Dirección de Retiro *';

  @override
  String get serviceTypeLabelRequired => 'Tipo de Servicio *';

  @override
  String get describeProblemLabelRequired => 'Describe el Problema *';

  @override
  String get dateLabelRequired => 'Fecha *';

  @override
  String get timeLabelRequired => 'Hora *';

  @override
  String get useCurrentLocation => 'Usar mi ubicación actual';

  @override
  String get locationSelected => 'Ubicación seleccionada';

  @override
  String get contactConfirmationInfo =>
      'Te contactaremos para confirmar tu cita en las próximas 2 horas';

  @override
  String get cancelNoticeInfo =>
      'Si necesitas cancelar, hazlo con al menos 24 horas de anticipación';

  @override
  String get bringAccessoriesInfo =>
      'Trae tu dispositivo con el cargador y accesorios necesarios';

  @override
  String get freeDiagnosticInfo => 'El diagnóstico inicial es gratuito';

  @override
  String get confirmReservationButton => 'CONFIRMAR RESERVA';

  @override
  String get reservationSuccess => '✅ Reserva creada con éxito';

  @override
  String get doneButton => 'Listo';

  @override
  String errorSaving(Object error) {
    return '❌ Error al guardar: $error';
  }

  @override
  String autocompleteSuccess(Object count) {
    return '✅ Se autocompletaron $count campos de tu perfil';
  }

  @override
  String get incompleteProfileWarning =>
      '⚠️ Tu perfil está incompleto. Completa tus datos para autocompletar.';

  @override
  String get profileNotFoundWarning =>
      '⚠️ Perfil no encontrado. Por favor completa tus datos.';

  @override
  String errorLoadingProfile(Object error) {
    return '⚠️ Error cargando perfil: $error';
  }

  @override
  String get locationSuccess => '📍 Ubicación obtenida correctamente';

  @override
  String get selectDatePrompt => 'Selecciona una fecha';

  @override
  String get selectTimePrompt => 'Selecciona una hora';

  @override
  String get invalidEmail => 'Correo inválido';

  @override
  String get requiredField => 'Obligatorio';

  @override
  String get tenDigits => '10 dígitos';

  @override
  String get phoneFormatError => 'Debe iniciar con 09 y tener 10 dígitos';

  @override
  String get date => 'Fecha';

  @override
  String get time => 'Hora';

  @override
  String get address => 'Dirección';

  @override
  String get location => 'Ubicación';

  @override
  String get problemDescription => 'Descripción del Problema';

  @override
  String thanksForTrusting(Object appName) {
    return '¡Gracias por confiar en $appName!';
  }

  @override
  String get mustLoginToViewReservations =>
      'Debes iniciar sesión para ver tus reservas';

  @override
  String get reservationEmptyDesc =>
      'Tus solicitudes de servicio aparecerán aquí';

  @override
  String get statusPending => 'Pendiente';

  @override
  String get statusConfirmed => 'Confirmado';

  @override
  String get statusInProcess => 'En Proceso';

  @override
  String get statusApproved => 'Aprobado';

  @override
  String get statusCompleted => 'Completado';

  @override
  String get statusRejected => 'Rechazado';

  @override
  String get statusCancelled => 'Cancelado';

  @override
  String get statusPrefix => 'Estado';

  @override
  String get fullNameLabelLabel => 'Nombre';

  @override
  String get idLabelLabel => 'Cédula';

  @override
  String get emailLabelLabel => 'Correo';

  @override
  String get phoneLabelLabel => 'Teléfono';

  @override
  String get addressLabelLabel => 'Dirección';

  @override
  String get deviceModelLabelLabel => 'Dispositivo';

  @override
  String get serviceTypeLabelLabel => 'Servicio';

  @override
  String get clientInfoSection => 'Datos del Cliente';

  @override
  String get serviceDetailsSection => 'Detalles del Servicio';

  @override
  String get reportedProblemLabel => 'Problema Reportado';

  @override
  String get managementSection => 'Gestión y Seguimiento';

  @override
  String get techCommentsLabel => 'Comentarios Técnicos';

  @override
  String get solutionLabel => 'Solución Aplicada';

  @override
  String get repairCostLabel => 'Costo de Reparación';

  @override
  String get sparePartsLabel => 'Repuestos';

  @override
  String get laborCostLabel => 'Mano de Obra';

  @override
  String get estimatedTotalLabel => 'Total Estimado';

  @override
  String get reservationCompletedWarning =>
      'Esta reserva está completada y no puede ser modificada';

  @override
  String get saveChanges => 'Guardar cambios';

  @override
  String get updatesAppliedSuccess => 'Cambios guardados con éxito';

  @override
  String get techDetailsSaved => 'Detalles técnicos guardados';

  @override
  String get reservationDetailTitle => 'Detalle de Reserva';

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
  String get selectSpareParts => 'Seleccionar Repuestos';

  @override
  String get searchProduct => 'Buscar Repuesto';

  @override
  String get searchProductHint => 'Buscar por nombre de producto...';

  @override
  String get errorLoadingProducts => 'Error al cargar repuestos';

  @override
  String successAddedToCart(String item) {
    return '$item agregado al carrito';
  }

  @override
  String get whatsappMarketingTitle => 'Campaña de Marketing WhatsApp';

  @override
  String get marketingPrompt =>
      'Selecciona un producto para comenzar la campaña';

  @override
  String get step1SelectProduct =>
      '1. Selecciona el Producto (Búsqueda Inteligente)';

  @override
  String get noProductsFound => 'No se encontraron productos';

  @override
  String promotingText(Object productName) {
    return 'Promocionando: $productName';
  }

  @override
  String get marketingDescription =>
      'Envía mensajes individuales o descarga el CSV para envíos masivos.';

  @override
  String get exportCSVTooltip => 'Exportar CSV para WaSender';

  @override
  String get searchClientHint => 'Buscar clientes...';

  @override
  String get noClientsFound => 'No se encontraron clientes';

  @override
  String get noPhoneNumber => 'Este cliente no tiene número de teléfono';

  @override
  String get addClient => 'Agregar Cliente';

  @override
  String get settingsPageTitle => 'Configuraciones';

  @override
  String get companyInfoTab => 'Información';

  @override
  String get bannersTab => 'Banners';

  @override
  String get securityTab => 'Seguridad';

  @override
  String get companyNameLabel => 'Nombre de la Empresa';

  @override
  String get companyEmailLabel => 'Correo Electrónico';

  @override
  String get companyPhoneLabel => 'Teléfono (WhatsApp, sin +)';

  @override
  String get companyPhoneHelper => 'Ej: 593991090805';

  @override
  String get companyAddressLabel => 'Dirección';

  @override
  String get saveSettingsButton => 'Guardar Cambios';

  @override
  String get settingsUpdateSuccess => 'Información actualizada correctamente';

  @override
  String get addBannerButton => 'Agregar Nuevo Banner';

  @override
  String get addBannerDialogTitle => 'Agregar Banner por URL';

  @override
  String get bannerUrlLabel => 'URL de la imagen';

  @override
  String get addBannerDialogAction => 'Agregar';

  @override
  String get deleteBannerDialogTitle => 'Eliminar Banner';

  @override
  String get deleteBannerDialogContent =>
      '¿Estás seguro de que deseas eliminar este banner?';

  @override
  String get deleteBannerDialogAction => 'Eliminar';

  @override
  String get biometricLoginLabel => 'Inicio de Sesión Biométrico';

  @override
  String get biometricEnabledStatus =>
      'Habilitado - Puedes iniciar sesión con tu huella o rostro';

  @override
  String get biometricDisabledStatus =>
      'Deshabilitado - Inicia sesión manualmente para habilitar';

  @override
  String get biometricDisableWarning =>
      'Para deshabilitar, apaga el interruptor arriba.';

  @override
  String get biometricEnableInstructions =>
      'Para habilitar la biometría, cierra sesión e inicia sesión manualmente. Se te preguntará si deseas activarla.';

  @override
  String get biometricDisableDialogTitle => 'Deshabilitar Biometría';

  @override
  String get biometricDisableDialogContent =>
      '¿Estás seguro de que deseas deshabilitar el inicio de sesión biométrico?\\n\\nTendrás que iniciar sesión manualmente la próxima vez.';

  @override
  String get biometricDisableDialogAction => 'Deshabilitar';

  @override
  String get biometricDisabledSuccess =>
      'Inicio de sesión biométrico desactivado.';

  @override
  String get noBannersConfigured => 'No hay banners configurados';

  @override
  String get bannerAddedSuccess => 'Banner agregado correctamente';

  @override
  String get bannerDeletedSuccess => 'Banner eliminado correctamente';

  @override
  String get payphoneTokenLabel => 'Token de Pago (Payphone)';

  @override
  String get payphoneStoreIdLabel => 'ID de Tienda (StoreID)';

  @override
  String get payphoneSandboxLabel => 'Modo Sandbox (Pruebas)';

  @override
  String get integrationsTab => 'Integraciones';

  @override
  String get editButton => 'Editar';

  @override
  String get deleteButton => 'Eliminar';
}
