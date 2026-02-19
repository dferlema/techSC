// lib/screens/service_reservation_page.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:techsc/core/services/notification_service.dart';
import 'package:techsc/core/widgets/notification_icon.dart';
import 'package:techsc/core/widgets/cart_badge.dart';
import 'package:techsc/core/utils/branding_helper.dart';

import 'package:techsc/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pantalla para reservar servicio técnico.
/// Permite al usuario llenar un formulario con sus datos y detalles del problema.
/// Genera un PDF de confirmación al guardar.
class ServiceReservationPage extends ConsumerStatefulWidget {
  final bool isManualRegistration;
  const ServiceReservationPage({super.key, this.isManualRegistration = false});

  @override
  ConsumerState<ServiceReservationPage> createState() =>
      _ServiceReservationPageState();
}

class _ServiceReservationPageState
    extends ConsumerState<ServiceReservationPage> {
  // Clave global para validar el formulario
  final _formKey = GlobalKey<FormState>();

  // Controladores para capturar la entrada de texto del usuario
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _idController = TextEditingController(); // Cédula
  final _deviceController = TextEditingController();
  final _addressController = TextEditingController();
  final _problemController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();

  // Variables de estado para selectores
  String? _selectedService;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  LatLng? _selectedLocation; // Clase personalizada simple para coordenadas

  // Usuario actual logueado (si existe)
  User? _currentUser;

  // Estado para controlar si el formulario de reserva ha comenzado
  bool _isReservationStarted = false;

  // Lista de servicios disponibles para el dropdown
  final List<String> _services = [
    'Reparación de Hardware',
    'Instalación de Software',
    'Formateo y Limpieza',
    'Actualización de Componentes',
    'Diagnóstico Técnico',
  ];

  // Ubicación predeterminada (Quito) para fallbacks si fuera necesario
  static const LatLng _defaultLocation = LatLng(-0.1807, -78.4678);

  @override
  void initState() {
    super.initState();
    // Obtener la instancia del usuario actual de Firebase Auth
    _currentUser = FirebaseAuth.instance.currentUser;
  }

  /// Carga la información del usuario desde Firestore si está autenticado.
  /// Esto mejora la UX al no tener que escribir datos repetitivos.
  Future<void> _loadUserData() async {
    if (_currentUser == null) {
      debugPrint('⚠️ No hay usuario logueado');
      return;
    }

    debugPrint('🔍 Cargando datos del usuario: ${_currentUser!.uid}');
    debugPrint('📧 Email de Firebase Auth: ${_currentUser!.email}');

    try {
      // Consultar la colección 'users' usando el UID para obtener perfil completo
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.uid)
          .get();

      debugPrint('📄 Documento existe: ${doc.exists}');

      if (doc.exists && mounted) {
        // Extraer datos del documento
        final data = doc.data() as Map<String, dynamic>;

        debugPrint('📦 Datos en Firestore: $data');
        debugPrint('  ├─ name: ${data['name']}');
        debugPrint('  ├─ email: ${data['email']}');
        debugPrint('  ├─ phone: ${data['phone']}');
        debugPrint('  ├─ id: ${data['id']}');
        debugPrint('  └─ address: ${data['address']}');

        setState(() {
          // Asignar valores a los controladores si existen en la base de datos
          _nameController.text = data['name'] ?? '';
          _emailController.text = data['email'] ?? _currentUser!.email ?? '';
          _phoneController.text = data['phone'] ?? '';
          _idController.text = data['id'] ?? ''; // Cédula
          _addressController.text = data['address'] ?? '';
        });

        // Contar campos llenados
        int filledFields = 0;
        if (data['name'] != null && data['name'].toString().isNotEmpty) {
          filledFields++;
        }
        if (data['phone'] != null && data['phone'].toString().isNotEmpty) {
          filledFields++;
        }
        if (data['id'] != null && data['id'].toString().isNotEmpty) {
          filledFields++;
        }
        if (data['address'] != null && data['address'].toString().isNotEmpty) {
          filledFields++;
        }

        // Notificar al usuario que sus datos se cargaron
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                filledFields > 0
                    ? AppLocalizations.of(
                        context,
                      )!.autocompleteSuccess(filledFields)
                    : AppLocalizations.of(context)!.incompleteProfileWarning,
              ),
              duration: const Duration(seconds: 3),
              backgroundColor: filledFields > 0 ? Colors.green : Colors.orange,
            ),
          );
        }
      } else {
        debugPrint('⚠️ No existe documento en Firestore para este usuario');
        // Si no existe el documento en Firestore, usar datos de Firebase Auth
        setState(() {
          _nameController.text = _currentUser!.displayName ?? '';
          _emailController.text = _currentUser!.email ?? '';
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.profileNotFoundWarning,
              ),
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      // Manejo silencioso de errores para no interrumpir el flujo
      debugPrint('❌ Error cargando datos de usuario: $e');
      debugPrint('Stack trace: ${StackTrace.current}');

      // Como respaldo, usar datos de Firebase Auth
      if (mounted) {
        setState(() {
          _nameController.text = _currentUser!.displayName ?? '';
          _emailController.text = _currentUser!.email ?? '';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.errorLoadingProfile(e.toString()),
            ),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Inicia el flujo de reserva (muestra el formulario y carga datos)
  void _startReservation() {
    setState(() {
      _isReservationStarted = true;
    });
    if (!widget.isManualRegistration) {
      _loadUserData();
    }
  }

  /// Libera los recursos de los controladores cuando se cierra la pantalla.
  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _idController.dispose();
    _deviceController.dispose();
    _addressController.dispose();
    _problemController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  /// Muestra un selector de fecha nativo y actualiza el estado.
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(), // No permitir fechas pasadas
      lastDate: DateTime(DateTime.now().year + 1), // Máximo 1 año a futuro
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  /// Muestra un selector de hora nativo y actualiza el estado.
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _timeController.text = picked.format(context);
      });
    }
  }

  /// Simula la selección de una ubicación GPS.
  /// En una app real, aquí se usaría geolocator o google_maps_flutter.
  void _simulateLocationSelection() {
    setState(() {
      // Genera una pequeña variación para simular "obtener ubicación actual"
      _selectedLocation = LatLng(
        -0.1807 + (DateTime.now().microsecondsSinceEpoch % 1000) / 100000,
        -78.4678 + (DateTime.now().microsecondsSinceEpoch % 1000) / 100000,
      );
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.locationSuccess)),
    );
  }

  /// Genera un documento PDF con el resumen de la reserva.
  /// Retorna los bytes del PDF generado.
  Future<Uint8List> _generatePDF(Map<String, dynamic> data) async {
    final pdf = pw.Document();
    final l10n = AppLocalizations.of(context)!;

    pdf.addPage(
      pw.Page(
        build: (pw.Context pdfContext) {
          return pw.Column(
            children: [
              // Encabezado
              pw.Center(
                child: pw.Text(
                  BrandingHelper.appName,
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  'Confirmación de Reserva', // TODO: Localize this if needed
                  style: pw.TextStyle(fontSize: 18),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 10),

              // Detalles de la reserva
              _buildPdfRow(
                l10n.fullNameLabelRequired.replaceAll(' *', ''),
                data['clientName'],
              ),
              _buildPdfRow(
                l10n.idLabelRequired.replaceAll(' *', ''),
                data['clientId'],
              ),
              _buildPdfRow(
                l10n.emailLabelRequired.replaceAll(' *', ''),
                data['clientEmail'],
              ),
              _buildPdfRow(
                l10n.phoneLabelRequired.replaceAll(' *', ''),
                data['clientPhone'],
              ),
              _buildPdfRow(
                l10n.deviceModelLabelRequired.replaceAll(' *', ''),
                data['device'],
              ),
              _buildPdfRow(
                l10n.serviceTypeLabelRequired.replaceAll(' *', ''),
                data['serviceType'],
              ),
              _buildPdfRow(
                l10n.date,
                data['scheduledDate'] != null
                    ? DateFormat('dd/MM/yyyy').format(data['scheduledDate'])
                    : '—',
              ),
              _buildPdfRow(l10n.time, data['scheduledTime'] ?? '—'),
              _buildPdfRow(l10n.address, data['address']),

              // Coordenadas si existen
              if (data['location'] != null)
                _buildPdfRow(
                  l10n.location,
                  '${data['location']['lat'].toStringAsFixed(6)}, ${data['location']['lng'].toStringAsFixed(6)}',
                ),

              pw.SizedBox(height: 10),

              // Descripción del problema
              pw.Text(
                '${l10n.problemDescription}:',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 4),
                child: pw.Text(data['description'], maxLines: 20),
              ),

              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 10),

              // Pie de página
              pw.Center(
                child: pw.Text(
                  l10n.thanksForTrusting(BrandingHelper.appName),
                  style: pw.TextStyle(color: PdfColors.blue),
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Center(
                child: pw.Text(
                  l10n.bringAccessoriesInfo,
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    return await pdf.save(); // Retorna el binario del PDF
  }

  /// Widget auxiliar para filas de texto en el PDF.
  pw.Widget _buildPdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.Container(
            width: 120, // Ancho fijo para la etiqueta
            child: pw.Text(
              '$label:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(child: pw.Text(value.isEmpty ? '—' : value)),
        ],
      ),
    );
  }

  /// Genera un ID único para la reserva (RyyyyMMdd-HHmmss-XXXX)
  String _generateReservationId() {
    final now = DateTime.now();
    final datePrefix = DateFormat('yyyyMMdd-HHmmss').format(now);
    final randomSuffix = DateTime.now().microsecondsSinceEpoch
        .toString()
        .substring(10); // Útimos 6 dígitos de microsegundos
    return 'R$datePrefix-$randomSuffix';
  }

  /// Valida el formulario y guarda la reserva en Firebase Firestore.
  /// Luego genera y comparte un PDF de confirmación.
  Future<void> _saveReservation() async {
    // 1. Validar campos del formulario
    if (!_formKey.currentState!.validate()) return;

    // 2. Validar campos personalizados (Fecha/Hora)
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.selectDatePrompt)),
      );
      return;
    }
    if (_selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.selectTimePrompt)),
      );
      return;
    }

    // 3. Mostrar indicador de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Recopilar datos del formulario
      final reservationData = {
        'userId': widget.isManualRegistration
            ? 'manual_by_tech'
            : _currentUser
                  ?.uid, // Vincular al usuario actual o marcar como manual
        'clientName': _nameController.text.trim(),
        'clientEmail': _emailController.text.trim(),
        'clientPhone': _phoneController.text.trim(),
        'clientId': _idController.text.trim(),
        'device': _deviceController.text.trim(),
        'serviceType': _selectedService!,
        'description': _problemController.text.trim(),
        'address': _addressController.text.trim(),
        'location': _selectedLocation != null
            ? {
                'lat': _selectedLocation!.latitude,
                'lng': _selectedLocation!.longitude,
              }
            : null,
        'scheduledDate': _selectedDate,
        'scheduledTime': _selectedTime!.format(context),
        'status': 'pendiente', // Estado inicial
        'createdAt': FieldValue.serverTimestamp(),
      };

      // 4. Generar ID único para la reserva
      final reservationId = _generateReservationId();

      await FirebaseFirestore.instance
          .collection('reservations')
          .doc(reservationId)
          .set(reservationData);

      // Enviar notificaciones usando el servicio centralizado
      await NotificationService().notifyReservationCreated(
        reservationId: reservationId,
        clientName: _nameController.text.trim(),
        serviceType: _selectedService!,
        customerUid: _currentUser?.uid,
      );

      // 5. Generar PDF usando los datos locales + el ID generado
      final pdfBytes = await _generatePDF({
        ...reservationData,
        'id': reservationId,
      });

      // 6. Cerrar diálogo de carga
      if (mounted) Navigator.pop(context);

      // 7. Mostrar selector para compartir/imprimir PDF
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'reserva_techservice_$reservationId.pdf',
      );

      // 8. Mensaje de éxito
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.reservationSuccess),
            action: SnackBarAction(
              label: AppLocalizations.of(context)!.doneButton,
              onPressed: () {},
            ),
          ),
        );

        // 9. Redirigir a WhatsApp automáticamente
        await _redirectToWhatsApp(reservationData, reservationId);

        // Regresar a la pantalla anterior o resetear formulario
        _resetForm();
      }
    } catch (e) {
      // Manejo de errores en el proceso de guardado
      if (mounted) {
        Navigator.pop(context); // Cerrar loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.errorSaving(e.toString()),
            ),
          ),
        );
      }
    }
  }

  /// Redirige al usuario a WhatsApp con un mensaje estructurado de la reserva.
  Future<void> _redirectToWhatsApp(Map<String, dynamic> data, String id) async {
    String phoneNumber = BrandingHelper.companyPhone;
    if (phoneNumber.startsWith('0')) {
      phoneNumber = '593${phoneNumber.substring(1)}';
    }
    final String dateStr = data['scheduledDate'] != null
        ? DateFormat('dd/MM/yyyy').format(data['scheduledDate'])
        : 'Pendiente';

    final String message = Uri.encodeComponent(
      '🌟 *NUEVA RESERVA TÉCNICA*\n\n'
      '🆔 *ID:* $id\n'
      '👤 *Cliente:* ${data['clientName']}\n'
      '📱 *Equipo:* ${data['device']}\n'
      '🔧 *Servicio:* ${data['serviceType']}\n'
      '📅 *Fecha:* $dateStr\n'
      '⏰ *Hora:* ${data['scheduledTime']}\n'
      '📍 *Dirección:* ${data['address']}\n\n'
      '💬 *Problema:* ${data['description']}\n\n'
      'He realizado una reserva desde la App. ¡Quedo atento a su confirmación!',
    );

    final Uri whatsappUri = Uri.parse(
      'https://wa.me/$phoneNumber?text=$message',
    );

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('No se pudo abrir WhatsApp');
      }
    } catch (e) {
      debugPrint('Error lanzando WhatsApp: $e');
    }
  }

  /// Limpia el formulario para una nueva entrada.
  void _resetForm() {
    _formKey.currentState?.reset();

    // Solo limpiar campos específicos de la reserva, no los datos personales
    _deviceController.clear();
    _problemController.clear();

    setState(() {
      _selectedService = null;
      _selectedDate = null;
      _selectedTime = null;
      _selectedLocation = null;
      _dateController.clear();
      _timeController.clear();
    });

    // Los datos personales (nombre, email, teléfono, cédula, dirección)
    // se mantienen para facilitar la siguiente reserva
    setState(() {
      _isReservationStarted = false;
    });
  }

  /// Helper widget to build info items in the information card.
  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[800],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // Removido leading personalizado para dejar que Flutter decida (Atrás o Menú)
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.technicalServiceTitle,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              widget.isManualRegistration
                  ? AppLocalizations.of(context)!.workshopRegistration
                  : (_isReservationStarted
                        ? AppLocalizations.of(context)!.completeRequestDetails
                        : AppLocalizations.of(context)!.scheduleWithPros),
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          if (_isReservationStarted)
            TextButton(
              onPressed: _cancelReservation,
              child: Text(
                AppLocalizations.of(context)!.cancelButton,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          const NotificationIcon(),
          const CartBadge(),
          const SizedBox(width: 8),
        ],
      ),
      // drawer: widget.isManualRegistration
      //     ? null
      //     : const AppDrawer(currentRoute: '/reserve-service'),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: _isReservationStarted
            ? _buildReservationForm()
            : _buildWelcomeScreen(),
      ),
    );
  }

  Widget _buildWelcomeScreen() {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.build_circle_rounded,
                size: 80,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              AppLocalizations.of(context)!.needTechnicalHelp,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.isManualRegistration
                  ? AppLocalizations.of(context)!.workshopWelcomeDesc
                  : AppLocalizations.of(context)!.reservationWelcomeDesc,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
            const SizedBox(height: 48),
            ElevatedButton(
              onPressed: _startReservation,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 20,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 4,
                shadowColor: theme.colorScheme.primary.withOpacity(0.3),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_task_rounded),
                  const SizedBox(width: 12),
                  Text(
                    widget.isManualRegistration
                        ? AppLocalizations.of(context)!.registerNewJob
                        : AppLocalizations.of(context)!.startNewReservation,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            // Información Informativa
            Card(
              elevation: 0,
              color: Colors.grey[50],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.grey[200]!),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    _buildInfoItem(
                      AppLocalizations.of(
                        context,
                      )!.officialSupport(BrandingHelper.appName),
                    ),
                    _buildInfoItem(
                      AppLocalizations.of(context)!.certifiedTechs,
                    ),
                    _buildInfoItem(AppLocalizations.of(context)!.fullWarranty),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReservationForm() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      key: const ValueKey('form'),
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Sección 1: Información Personal ---
            Text(
              AppLocalizations.of(context)!.personalInfoSection,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Campo Nombre
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.person),
                labelText: AppLocalizations.of(context)!.fullNameLabelRequired,
                hintText: 'Ej: Diego Lema',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (v) => v!.trim().isEmpty
                  ? AppLocalizations.of(context)!.requiredField
                  : null,
            ),
            const SizedBox(height: 20),

            // Campo Cédula
            TextFormField(
              controller: _idController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.badge),
                labelText: AppLocalizations.of(context)!.idLabelRequired,
                hintText: '17XXXXXXXX',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: TextInputType.number,
              validator: (v) => v!.trim().length != 10
                  ? AppLocalizations.of(context)!.tenDigits
                  : null,
            ),
            const SizedBox(height: 20),

            // Campo Correo
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.email),
                labelText: AppLocalizations.of(context)!.emailLabelRequired,
                hintText: 'tu@email.com',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (v) =>
                  !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v!)
                  ? AppLocalizations.of(context)!.invalidEmail
                  : null,
            ),
            const SizedBox(height: 20),

            // Campo Teléfono
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.phone),
                labelText: 'Teléfono *',
                hintText: '09XXXXXXXX',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: TextInputType.phone,
              validator: (v) => v!.trim().length != 10 || !v.startsWith('09')
                  ? AppLocalizations.of(context)!.phoneFormatError
                  : null,
            ),
            const SizedBox(height: 20),

            const Divider(),
            const SizedBox(height: 16),

            // --- Sección 2: Detalles del Equipo ---
            Text(
              AppLocalizations.of(context)!.deviceDetailsSection,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Tipo de Dispositivo
            TextFormField(
              controller: _deviceController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.laptop),
                labelText: AppLocalizations.of(
                  context,
                )!.deviceModelLabelRequired,
                hintText: 'Ej: Laptop HP Pavilion 15',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (v) => v!.trim().isEmpty
                  ? AppLocalizations.of(context)!.requiredField
                  : null,
            ),
            const SizedBox(height: 20),

            // Dirección
            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.location_on),
                labelText: AppLocalizations.of(
                  context,
                )!.pickupAddressLabelRequired,
                hintText: 'Calles principales y referencia',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 2,
              validator: (v) => v!.trim().isEmpty
                  ? AppLocalizations.of(context)!.requiredField
                  : null,
            ),
            const SizedBox(height: 20),

            // --- Sección 3: Servicio y Problema ---
            Text(
              AppLocalizations.of(context)!.serviceProblemSection,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Dropdown Tipo de Servicio
            DropdownButtonFormField<String>(
              initialValue: _selectedService,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(
                  context,
                )!.serviceTypeLabelRequired,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: _services
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedService = v),
              validator: (v) => v == null
                  ? AppLocalizations.of(context)!.selectDatePrompt
                  : null, // Fix: use appropriate key
            ),
            const SizedBox(height: 20),

            // Descripción del Problema
            TextFormField(
              controller: _problemController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(
                  context,
                )!.describeProblemLabelRequired,
                hintText: 'Ej: El equipo se calienta mucho y se apaga...',
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 4,
              validator: (v) => v!.trim().isEmpty
                  ? AppLocalizations.of(context)!.describeProblemLabelRequired
                  : null,
            ),
            const SizedBox(height: 20),

            const Divider(),
            const SizedBox(height: 16),

            // --- Sección 4: Cita ---
            Text(
              AppLocalizations.of(context)!.scheduleAppointmentSection,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                // Selector de Fecha
                Expanded(
                  child: TextFormField(
                    controller: _dateController,
                    readOnly: true,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.calendar_today),
                      labelText: AppLocalizations.of(
                        context,
                      )!.dateLabelRequired,
                      hintText: AppLocalizations.of(context)!.selectDatePrompt,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onTap: () => _selectDate(context),
                    validator: (v) => _selectedDate == null
                        ? AppLocalizations.of(context)!.requiredField
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                // Selector de Hora
                Expanded(
                  child: TextFormField(
                    controller: _timeController,
                    readOnly: true,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.access_time),
                      labelText: AppLocalizations.of(
                        context,
                      )!.timeLabelRequired,
                      hintText: AppLocalizations.of(context)!.selectTimePrompt,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onTap: () => _selectTime(context),
                    validator: (v) => _selectedTime == null
                        ? AppLocalizations.of(context)!.requiredField
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Botón Ubicación GPS
            ElevatedButton.icon(
              onPressed: _simulateLocationSelection,
              icon: const Icon(Icons.gps_fixed),
              label: Text(
                _selectedLocation != null
                    ? AppLocalizations.of(context)!.locationSelected
                    : AppLocalizations.of(context)!.useCurrentLocation,
                style: TextStyle(
                  color: _selectedLocation != null ? Colors.green[800] : null,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedLocation != null
                    ? Colors.green[50]
                    : Colors.grey[100],
                elevation: 0,
                minimumSize: const Size(double.infinity, 45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 32),

            // --- Información Importante ---
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue[700],
                          size: 28,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          AppLocalizations.of(context)!.importantInfoSection,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildInfoItem(
                      AppLocalizations.of(context)!.contactConfirmationInfo,
                    ),
                    const SizedBox(height: 8),
                    _buildInfoItem(
                      AppLocalizations.of(context)!.cancelNoticeInfo,
                    ),
                    const SizedBox(height: 8),
                    _buildInfoItem(
                      AppLocalizations.of(context)!.bringAccessoriesInfo,
                    ),
                    const SizedBox(height: 8),
                    _buildInfoItem(
                      AppLocalizations.of(context)!.freeDiagnosticInfo,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // --- Botón Principal de Guardado ---
            ElevatedButton(
              onPressed: _saveReservation,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.secondary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                shadowColor: Colors.blueAccent.withOpacity(0.4),
                minimumSize: const Size(double.infinity, 55),
              ),
              child: Text(
                AppLocalizations.of(context)!.confirmReservationButton,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  /// Cancela la reserva actual y regresa a la pantalla de inicio
  void _cancelReservation() {
    setState(() {
      _isReservationStarted = false;
    });
    _resetForm();
  }
}

/// Clase simple para representar coordenadas geográficas.
/// Se usa para evitar la dependencia pesada de Google Maps si solo necesitamos guardar lat/lng.
class LatLng {
  final double latitude;
  final double longitude;
  const LatLng(this.latitude, this.longitude);
}
