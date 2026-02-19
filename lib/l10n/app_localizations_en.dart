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
  String whatsappMessage(String service) {
    return 'Hello, I am interested in the $service service. Could you give me more information?';
  }

  @override
  String get paymentMethodLabel => 'Payment Method';

  @override
  String get paymentCash => 'Cash';

  @override
  String get paymentTransfer => 'Transfer';

  @override
  String get paymentCard => 'Card';

  @override
  String get paymentLinkLabel => 'Payment Link';

  @override
  String get paymentControlSection => 'Payment Control';

  @override
  String get paymentDetailsSaved => 'Payment details saved';

  @override
  String get adminPanelTitle => 'Admin Panel';

  @override
  String get adminPanelSubtitle =>
      'Manage clients, products, services, and banners';

  @override
  String get adminPanel => 'Panel de Administración';

  @override
  String get clientsTab => 'Clients';

  @override
  String get productsTab => 'Products';

  @override
  String get servicesTab => 'Services';

  @override
  String get ordersTab => 'Orders';

  @override
  String get suppliersTab => 'Suppliers';

  @override
  String get onlyAdminClients => 'Only administrators can manage clients';

  @override
  String get onlyAdminSuppliers => 'Only administrators can manage suppliers';

  @override
  String get manageCategories => 'Manage Categories';

  @override
  String get addProduct => 'Add Product';

  @override
  String get addService => 'Add Service';

  @override
  String get searchHint => 'Search...';

  @override
  String get productSaveSuccess => '✅ Product saved';

  @override
  String get serviceSaveSuccess => '✅ Service saved';

  @override
  String get noItemsFound => 'No items found';

  @override
  String get noMatchesFound => 'No matches found';

  @override
  String get productFormTitleNew => 'New Product';

  @override
  String get productFormTitleEdit => 'Edit Product';

  @override
  String get serviceFormTitleNew => 'New Service';

  @override
  String get serviceFormTitleEdit => 'Edit Service';

  @override
  String get productImages => 'Product Images *';

  @override
  String get serviceImages => 'Service Images *';

  @override
  String get imageLinkHint => 'https://example.com/image.jpg';

  @override
  String get addImage => 'Add Image';

  @override
  String get mainImageLabel => 'Main';

  @override
  String get noImagesAdded => 'No images added';

  @override
  String get productName => 'Name *';

  @override
  String get productSpecs => 'Specifications';

  @override
  String get productDescription => 'Description';

  @override
  String get productPrice => 'Price *';

  @override
  String get productCategory => 'Category *';

  @override
  String get productLabel => 'Label (Optional)';

  @override
  String get taxStatus => 'Tax Status';

  @override
  String get ratingLabel => 'Rating';

  @override
  String get featuredProduct => 'Featured Product';

  @override
  String get featuredProductSubtitle =>
      'Will appear in the home featured section';

  @override
  String get featuredService => 'Featured Service';

  @override
  String get featuredServiceSubtitle =>
      'Will appear in the home featured section';

  @override
  String get supplierInfo => 'Supplier Information';

  @override
  String get supplierLink => 'Supplier Product Link';

  @override
  String get save => 'Save';

  @override
  String get atLeastOneImage => '⚠️ Add at least one image';

  @override
  String get invalidPrice => 'Valid > 0';

  @override
  String get enterLinkFirst => 'Enter a link first';

  @override
  String get preview => 'Preview';

  @override
  String get cancel => 'Cancel';

  @override
  String get saveSuccess => '✅ Saved successfully';

  @override
  String get deleteSuccess => '✅ Item deleted';

  @override
  String get errorPrefix => 'Error';

  @override
  String get accessDenied => 'Access Denied';

  @override
  String get authorizedPersonnelOnly => 'Only authorized personnel can access.';

  @override
  String get backButton => 'Back';

  @override
  String get advancedSearch => 'Advanced Search';

  @override
  String get startDate => 'Start date';

  @override
  String get endDate => 'End date';

  @override
  String get from => 'From';

  @override
  String get to => 'To';

  @override
  String get clearFilters => 'Clear';

  @override
  String get exportCSV => 'CSV';

  @override
  String get exportPDF => 'PDF';

  @override
  String get csvSaved => '✅ CSV saved to documents';

  @override
  String get pdfError => '❌ Error generating PDF';

  @override
  String showingCount(int count, int total) {
    return 'Showing $count of $total clients';
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
  String get serviceDeleted => 'Service deleted';

  @override
  String addedToCart(Object item) {
    return '✅ $item added to cart';
  }

  @override
  String get viewCart => 'VIEW';

  @override
  String get buyButton => 'Buy Now';

  @override
  String get editUsingAdminPanel => 'Use Admin Panel to edit';

  @override
  String get scheduleReservation => 'Schedule Appointment';

  @override
  String get confirmReservation => 'Confirm Appointment';

  @override
  String get selectDate => 'Select Date';

  @override
  String get selectTime => 'Select Time';

  @override
  String get yourReservations => 'My Appointments';

  @override
  String get noReservations => 'No appointments found';

  @override
  String get descriptionTitle => 'Description';

  @override
  String get rateService => 'Rate this service';

  @override
  String get shareWhatsApp => 'Share via WhatsApp';

  @override
  String get addedHighlight => 'Added!';

  @override
  String get reserveButton => 'Reserve';

  @override
  String get technicalServiceTitle => 'Technical Service';

  @override
  String get workshopRegistration => 'Workshop Job Registration';

  @override
  String get completeRequestDetails => 'Complete your request details';

  @override
  String get scheduleWithPros => 'Schedule your appointment with professionals';

  @override
  String get cancelButton => 'Cancel';

  @override
  String get needTechnicalHelp => 'Do you need technical help?';

  @override
  String get workshopWelcomeDesc =>
      'Register a job for a client not in the app. You can track and generate a receipt.';

  @override
  String get reservationWelcomeDesc =>
      'Schedule an equipment review today. We will load your saved data automatically for your convenience.';

  @override
  String get registerNewJob => 'REGISTER NEW JOB';

  @override
  String get startNewReservation => 'START NEW RESERVATION';

  @override
  String officialSupport(Object appName) {
    return 'Official $appName support';
  }

  @override
  String get certifiedTechs =>
      'Certified technicians with extensive experience';

  @override
  String get fullWarranty => 'Full warranty on all spare parts';

  @override
  String get personalInfoSection => 'Personal Information';

  @override
  String get deviceDetailsSection => 'Equipment Details';

  @override
  String get serviceProblemSection => 'Select Service';

  @override
  String get scheduleAppointmentSection => 'Schedule Appointment';

  @override
  String get importantInfoSection => 'Important Information';

  @override
  String get fullNameLabelRequired => 'Full Name *';

  @override
  String get idLabelRequired => 'ID *';

  @override
  String get emailLabelRequired => 'Email Email *';

  @override
  String get phoneLabelRequired => 'Phone *';

  @override
  String get deviceModelLabelRequired => 'Device / Model *';

  @override
  String get pickupAddressLabelRequired => 'Pickup Address *';

  @override
  String get serviceTypeLabelRequired => 'Service Type *';

  @override
  String get describeProblemLabelRequired => 'Describe the Problem *';

  @override
  String get dateLabelRequired => 'Date *';

  @override
  String get timeLabelRequired => 'Time *';

  @override
  String get useCurrentLocation => 'Use my current location';

  @override
  String get locationSelected => 'Location selected';

  @override
  String get contactConfirmationInfo =>
      'We will contact you to confirm your appointment within the next 2 hours';

  @override
  String get cancelNoticeInfo =>
      'If you need to cancel, please do so at least 24 hours in advance';

  @override
  String get bringAccessoriesInfo =>
      'Bring your device with the charger and necessary accessories';

  @override
  String get freeDiagnosticInfo => 'Initial diagnostic is free';

  @override
  String get confirmReservationButton => 'CONFIRM RESERVATION';

  @override
  String get reservationSuccess => '✅ Reservation created successfully';

  @override
  String get doneButton => 'Done';

  @override
  String errorSaving(Object error) {
    return '❌ Error saving: $error';
  }

  @override
  String autocompleteSuccess(Object count) {
    return '✅ $count profile fields were autocompleted';
  }

  @override
  String get incompleteProfileWarning =>
      '⚠️ Your profile is incomplete. Complete your data to autocomplete.';

  @override
  String get profileNotFoundWarning =>
      '⚠️ Profile not found. Please complete your data.';

  @override
  String errorLoadingProfile(Object error) {
    return '⚠️ Error loading profile: $error';
  }

  @override
  String get locationSuccess => '📍 Location obtained correctly';

  @override
  String get selectDatePrompt => 'Select a date';

  @override
  String get selectTimePrompt => 'Select a time';

  @override
  String get invalidEmail => 'Invalid email';

  @override
  String get requiredField => 'Required';

  @override
  String get tenDigits => '10 digits';

  @override
  String get phoneFormatError => 'Must start with 09 and have 10 digits';

  @override
  String get date => 'Date';

  @override
  String get time => 'Time';

  @override
  String get address => 'Address';

  @override
  String get location => 'Location';

  @override
  String get problemDescription => 'Problem Description';

  @override
  String thanksForTrusting(Object appName) {
    return 'Thanks for trusting $appName!';
  }

  @override
  String get mustLoginToViewReservations =>
      'You must login to view your reservations';

  @override
  String get reservationEmptyDesc => 'Your service requests will appear here';

  @override
  String get statusPending => 'Pending';

  @override
  String get statusConfirmed => 'Confirmed';

  @override
  String get statusInProcess => 'In Process';

  @override
  String get statusApproved => 'Approved';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusRejected => 'Rejected';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get statusPrefix => 'Status';

  @override
  String get fullNameLabelLabel => 'Name';

  @override
  String get idLabelLabel => 'ID/Passport';

  @override
  String get emailLabelLabel => 'Email';

  @override
  String get phoneLabelLabel => 'Phone';

  @override
  String get addressLabelLabel => 'Address';

  @override
  String get deviceModelLabelLabel => 'Device';

  @override
  String get serviceTypeLabelLabel => 'Service';

  @override
  String get clientInfoSection => 'Client Information';

  @override
  String get serviceDetailsSection => 'Service Details';

  @override
  String get reportedProblemLabel => 'Reported Problem';

  @override
  String get managementSection => 'Management & Tracking';

  @override
  String get techCommentsLabel => 'Technical Comments';

  @override
  String get solutionLabel => 'Applied Solution';

  @override
  String get repairCostLabel => 'Repair Cost';

  @override
  String get sparePartsLabel => 'Spare Parts';

  @override
  String get laborCostLabel => 'Labor Cost';

  @override
  String get estimatedTotalLabel => 'Estimated Total';

  @override
  String get reservationCompletedWarning =>
      'This reservation is completed and cannot be modified';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get updatesAppliedSuccess => 'Changes saved successfully';

  @override
  String get techDetailsSaved => 'Technical details saved';

  @override
  String get reservationDetailTitle => 'Reservation Detail';

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
  String get selectSpareParts => 'Select Spare Parts';

  @override
  String get searchProduct => 'Search Part';

  @override
  String get searchProductHint => 'Part name...';

  @override
  String get errorLoadingProducts => 'Error loading parts';

  @override
  String successAddedToCart(String item) {
    return '$item added to cart';
  }

  @override
  String get whatsappMarketingTitle => 'WhatsApp Marketing Campaign';

  @override
  String get marketingPrompt => 'Select a product to start the campaign';

  @override
  String get step1SelectProduct => '1. Select Product (Smart Search)';

  @override
  String get noProductsFound => 'No products found';

  @override
  String promotingText(Object productName) {
    return 'Promoting: $productName';
  }

  @override
  String get marketingDescription =>
      'Send individual messages or download CSV for bulk sending.';

  @override
  String get exportCSVTooltip => 'Export CSV for WaSender';

  @override
  String get searchClientHint => 'Search clients...';

  @override
  String get noClientsFound => 'No clients found';

  @override
  String get noPhoneNumber => 'This client does not have a phone number';

  @override
  String get addClient => 'Add Client';

  @override
  String get settingsPageTitle => 'Settings';

  @override
  String get companyInfoTab => 'Info';

  @override
  String get bannersTab => 'Banners';

  @override
  String get securityTab => 'Security';

  @override
  String get companyNameLabel => 'Company Name';

  @override
  String get companyEmailLabel => 'Email Address';

  @override
  String get companyPhoneLabel => 'Phone (WhatsApp, no +)';

  @override
  String get companyPhoneHelper => 'Ex: 593991090805';

  @override
  String get companyAddressLabel => 'Address';

  @override
  String get saveSettingsButton => 'Save Changes';

  @override
  String get settingsUpdateSuccess => 'Information updated successfully';

  @override
  String get addBannerButton => 'Add New Banner';

  @override
  String get addBannerDialogTitle => 'Add Banner by URL';

  @override
  String get bannerUrlLabel => 'Image URL';

  @override
  String get addBannerDialogAction => 'Add';

  @override
  String get deleteBannerDialogTitle => 'Delete Banner';

  @override
  String get deleteBannerDialogContent =>
      'Are you sure you want to delete this banner?';

  @override
  String get deleteBannerDialogAction => 'Delete';

  @override
  String get biometricLoginLabel => 'Biometric Login';

  @override
  String get biometricEnabledStatus =>
      'Enabled - You can log in with your fingerprint or face';

  @override
  String get biometricDisabledStatus => 'Disabled - Log in manually to enable';

  @override
  String get biometricDisableWarning =>
      'To disable, turn off the switch above.';

  @override
  String get biometricEnableInstructions =>
      'To enable biometrics, log out and log in manually. You will be asked if you want to activate it.';

  @override
  String get biometricDisableDialogTitle => 'Disable Biometrics';

  @override
  String get biometricDisableDialogContent =>
      'Are you sure you want to disable biometric login?\\n\\nYou will have to log in manually next time.';

  @override
  String get biometricDisableDialogAction => 'Disable';

  @override
  String get biometricDisabledSuccess => 'Biometric login disabled.';

  @override
  String get noBannersConfigured => 'No banners configured';

  @override
  String get bannerAddedSuccess => 'Banner added successfully';

  @override
  String get bannerDeletedSuccess => 'Banner deleted successfully';
}
