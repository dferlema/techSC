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
import '../services/notification_service.dart';
import '../services/role_service.dart';
import '../widgets/notification_icon.dart';
// import '../widgets/app_drawer.dart';

/// Pantalla para reservar servicio técnico.
/// Permite al usuario llenar un formulario con sus datos y detalles del problema.
/// Genera un PDF de confirmación al guardar.
class ServiceReservationPage extends StatefulWidget {
  const ServiceReservationPage({super.key});

  @override
  State<ServiceReservationPage> createState() => _ServiceReservationPageState();
}

class _ServiceReservationPageState extends State<ServiceReservationPage> {
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
                    ? '✅ Se autocompletaron $filledFields campos de tu perfil'
                    : '⚠️ Tu perfil está incompleto. Completa tus datos para autocompletar.',
              ),
              duration: Duration(seconds: 3),
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
            const SnackBar(
              content: Text(
                '⚠️ Perfil no encontrado. Por favor completa tus datos.',
              ),
              duration: Duration(seconds: 3),
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
            content: Text('⚠️ Error cargando perfil: ${e.toString()}'),
            duration: Duration(seconds: 3),
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
    _loadUserData();
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
      setState(() => _selectedDate = picked);
    }
  }

  /// Muestra un selector de hora nativo y actualiza el estado.
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
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
      const SnackBar(content: Text('📍 Ubicación obtenida correctamente')),
    );
  }

  /// Genera un documento PDF con el resumen de la reserva.
  /// Retorna los bytes del PDF generado.
  Future<Uint8List> _generatePDF(Map<String, dynamic> data) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            children: [
              // Encabezado
              pw.Center(
                child: pw.Text(
                  'TechService Pro',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Center(
                child: pw.Text(
                  'Confirmación de Reserva',
                  style: pw.TextStyle(fontSize: 18),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 10),

              // Detalles de la reserva
              _buildPdfRow('Cliente', data['clientName']),
              _buildPdfRow('Cédula', data['clientId']),
              _buildPdfRow('Correo', data['clientEmail']),
              _buildPdfRow('Teléfono', data['clientPhone']),
              _buildPdfRow('Dispositivo', data['device']),
              _buildPdfRow('Servicio', data['serviceType']),
              _buildPdfRow(
                'Fecha',
                data['scheduledDate'] != null
                    ? DateFormat('dd/MM/yyyy').format(data['scheduledDate'])
                    : '—',
              ),
              _buildPdfRow('Hora', data['scheduledTime'] ?? '—'),
              _buildPdfRow('Dirección', data['address']),

              // Coordenadas si existen
              if (data['location'] != null)
                _buildPdfRow(
                  'Ubicación',
                  '${data['location']['lat'].toStringAsFixed(6)}, ${data['location']['lng'].toStringAsFixed(6)}',
                ),

              pw.SizedBox(height: 10),

              // Descripción del problema
              pw.Text(
                'Descripción del Problema:',
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
                  '¡Gracias por confiar en TechService Pro!',
                  style: pw.TextStyle(color: PdfColors.blue),
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Center(
                child: pw.Text(
                  'Presente este comprobante al momento de la cita.',
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

  /// Valida el formulario y guarda la reserva en Firebase Firestore.
  /// Luego genera y comparte un PDF de confirmación.
  Future<void> _saveReservation() async {
    // 1. Validar campos del formulario
    if (!_formKey.currentState!.validate()) return;

    // 2. Validar campos personalizados (Fecha/Hora)
    if (_selectedDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecciona una fecha')));
      return;
    }
    if (_selectedTime == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecciona una hora')));
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
        'userId': _currentUser?.uid, // Vincular al usuario actual
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

      // 4. Guardar en Firestore
      final docRef = await FirebaseFirestore.instance
          .collection('reservations')
          .add(reservationData);
      final reservationId = docRef.id;

      // Enviar notificación al usuario
      if (_currentUser != null) {
        await NotificationService().sendNotification(
          title: 'Reserva Creada',
          body: 'Tu reserva para ${_selectedService!} ha sido registrada.',
          type: 'reservation',
          relatedId: reservationId,
          receiverId: _currentUser!.uid,
        );
      }

      // Enviar notificación a administradores y técnicos
      await NotificationService().sendNotification(
        title: 'Nueva Reserva',
        body:
            'Nueva reserva de ${_nameController.text} para ${_selectedService!}',
        type: 'reservation',
        relatedId: reservationId,
        receiverRole: RoleService.ADMIN,
      );
      await NotificationService().sendNotification(
        title: 'Nueva Reserva',
        body:
            'Nueva reserva de ${_nameController.text} para ${_selectedService!}',
        type: 'reservation',
        relatedId: reservationId,
        receiverRole: RoleService.TECHNICIAN,
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
            content: const Text('✅ Reserva creada con éxito'),
            action: SnackBarAction(label: 'Listo', onPressed: () {}),
          ),
        );

        // 9. Redirigir a WhatsApp automáticamente
        await _redirectToWhatsApp(reservationData, reservationId);

        // Regresar a la pantalla anterior o resetear formulario
        _resetForm();
      }
    } catch (e) {
      // Manejo de errores en el proceso de guardado
      if (mounted) Navigator.pop(context); // Cerrar loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error al guardar: ${e.toString()}')),
      );
    }
  }

  /// Redirige al usuario a WhatsApp con un mensaje estructurado de la reserva.
  Future<void> _redirectToWhatsApp(Map<String, dynamic> data, String id) async {
    const String phoneNumber = '593991090805'; // Número destino solicitado
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
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Colors.white),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Servicio Técnico',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              _isReservationStarted
                  ? 'Completa los detalles de tu requerimiento'
                  : 'Agenda tu cita con profesionales',
              style: const TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          if (_isReservationStarted)
            TextButton(
              onPressed: _cancelReservation,
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          const NotificationIcon(),
          const SizedBox(width: 16),
        ],
      ),
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
            const Text(
              '¿Necesitas ayuda técnica?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Agenda una revisión para tus equipos hoy mismo. Cargaremos tus datos guardados automáticamente para tu comodidad.',
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
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_task_rounded),
                  SizedBox(width: 12),
                  Text(
                    'COMENZAR NUEVA RESERVA',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                    _buildInfoItem('Respaldo oficial TechService Pro'),
                    _buildInfoItem(
                      'Técnicos certificados con amplia experiencia',
                    ),
                    _buildInfoItem('Garantía total en todos los repuestos'),
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
            const Text(
              'Información Personal',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Campo Nombre
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.person),
                labelText: 'Nombre Completo *',
                hintText: 'Ej: Diego Lema',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (v) => v!.trim().isEmpty ? 'Obligatorio' : null,
            ),
            const SizedBox(height: 20),

            // Campo Cédula
            TextFormField(
              controller: _idController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.badge),
                labelText: 'Cédula *',
                hintText: '17XXXXXXXX',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: TextInputType.number,
              validator: (v) => v!.trim().length != 10 ? '10 dígitos' : null,
            ),
            const SizedBox(height: 20),

            // Campo Correo
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.email),
                labelText: 'Correo Electrónico *',
                hintText: 'tu@email.com',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (v) =>
                  !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v!)
                  ? 'Correo inválido'
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
                  ? 'Debe iniciar con 09 y tener 10 dígitos'
                  : null,
            ),
            const SizedBox(height: 20),

            const Divider(),
            const SizedBox(height: 16),

            // --- Sección 2: Detalles del Equipo ---
            const Text(
              'Detalles del Equipo',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Tipo de Dispositivo
            TextFormField(
              controller: _deviceController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.laptop),
                labelText: 'Dispositivo / Modelo *',
                hintText: 'Ej: Laptop HP Pavilion 15',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (v) => v!.trim().isEmpty ? 'Obligatorio' : null,
            ),
            const SizedBox(height: 20),

            // Dirección
            TextFormField(
              controller: _addressController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.location_on),
                labelText: 'Dirección de Retiro *',
                hintText: 'Calles principales y referencia',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 2,
              validator: (v) => v!.trim().isEmpty ? 'Obligatorio' : null,
            ),
            const SizedBox(height: 20),

            // --- Sección 3: Servicio y Problema ---
            const Text(
              'Seleccionar Servicio',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Dropdown Tipo de Servicio
            DropdownButtonFormField<String>(
              value: _selectedService,
              decoration: InputDecoration(
                labelText: 'Tipo de Servicio *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: _services
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedService = v),
              validator: (v) => v == null ? 'Selecciona un servicio' : null,
            ),
            const SizedBox(height: 20),

            // Descripción del Problema
            TextFormField(
              controller: _problemController,
              decoration: InputDecoration(
                labelText: 'Describe el Problema *',
                hintText: 'Ej: El equipo se calienta mucho y se apaga...',
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 4,
              validator: (v) =>
                  v!.trim().isEmpty ? 'Describe el problema' : null,
            ),
            const SizedBox(height: 20),

            const Divider(),
            const SizedBox(height: 16),

            // --- Sección 4: Cita ---
            const Text(
              'Programar Cita',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                // Selector de Fecha
                Expanded(
                  child: TextFormField(
                    readOnly: true,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.calendar_today),
                      labelText: 'Fecha *',
                      hintText: _selectedDate != null
                          ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                          : 'Seleccionar',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onTap: () => _selectDate(context),
                    validator: (v) =>
                        _selectedDate == null ? 'Requerido' : null,
                  ),
                ),
                const SizedBox(width: 12),
                // Selector de Hora
                Expanded(
                  child: TextFormField(
                    readOnly: true,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.access_time),
                      labelText: 'Hora *',
                      hintText: _selectedTime != null
                          ? _selectedTime!.format(context)
                          : 'Seleccionar',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onTap: () => _selectTime(context),
                    validator: (v) =>
                        _selectedTime == null ? 'Requerido' : null,
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
                    ? 'Ubicación seleccionada'
                    : 'Usar mi ubicación actual',
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
                          'Información Importante',
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
                      '• Te contactaremos para confirmar tu cita en las próximas 2 horas',
                    ),
                    const SizedBox(height: 8),
                    _buildInfoItem(
                      '• Si necesitas cancelar, hazlo con al menos 24 horas de anticipación',
                    ),
                    const SizedBox(height: 8),
                    _buildInfoItem(
                      '• Trae tu dispositivo con el cargador y accesorios necesarios',
                    ),
                    const SizedBox(height: 8),
                    _buildInfoItem('• El diagnóstico inicial es gratuito'),
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
              child: const Text(
                'CONFIRMAR RESERVA',
                style: TextStyle(
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
