// lib/screens/service_reservation_page.dart

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../widgets/app_drawer.dart';

class ServiceReservationPage extends StatefulWidget {
  const ServiceReservationPage({super.key});

  @override
  State<ServiceReservationPage> createState() => _ServiceReservationPageState();
}

class _ServiceReservationPageState extends State<ServiceReservationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _idController = TextEditingController();
  final _deviceController = TextEditingController();
  final _addressController = TextEditingController();
  final _problemController = TextEditingController();

  String? _selectedService;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  LatLng? _selectedLocation;

  // Para usuarios logueados
  User? _currentUser;

  final List<String> _services = [
    'Reparación de Hardware',
    'Instalación de Software',
    'Formateo y Limpieza',
    'Actualización de Componentes',
    'Diagnóstico Técnico',
  ];

  // Ubicación predeterminada (Quito)
  static const LatLng _defaultLocation = LatLng(-0.1807, -78.4678);

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _loadUserData();
  }

  void _loadUserData() {
    if (_currentUser != null) {
      // Si está logueado, cargar datos básicos (opcional: desde Firestore)
      _nameController.text = _currentUser!.displayName ?? '';
      _emailController.text = _currentUser!.email ?? '';
    }
  }

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

  // 📅 Seleccionar fecha
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 1),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  // ⏰ Seleccionar hora
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  // 📍 Simular selección de ubicación (sin Google Maps)
  void _simulateLocationSelection() {
    setState(() {
      _selectedLocation = LatLng(
        -0.1807 + (DateTime.now().microsecondsSinceEpoch % 1000) / 100000,
        -78.4678 + (DateTime.now().microsecondsSinceEpoch % 1000) / 100000,
      );
    });
  }

  // 📧 Generar PDF de confirmación
  Future<Uint8List> _generatePDF(Map<String, dynamic> data) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            children: [
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
              if (data['location'] != null)
                _buildPdfRow(
                  'Ubicación',
                  '${data['location']['lat'].toStringAsFixed(6)}, ${data['location']['lng'].toStringAsFixed(6)}',
                ),
              pw.SizedBox(height: 10),
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
              pw.Center(
                child: pw.Text(
                  '¡Gracias por confiar en TechService Pro!',
                  style: pw.TextStyle(color: PdfColors.blue),
                ),
              ),
            ],
          );
        },
      ),
    );

    return await pdf.save();
  }

  pw.Widget _buildPdfRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        children: [
          pw.Container(
            width: 120,
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

  // 💾 Guardar reserva en Firebase
  Future<void> _saveReservation() async {
    if (!_formKey.currentState!.validate()) return;

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

    // 🌀 Mostrar loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Datos de la reserva
      final reservationData = {
        'userId': _currentUser?.uid,
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
        'status': 'pendiente',
        'createdAt': FieldValue.serverTimestamp(),
      };

      // 1️⃣ Guardar en Firestore
      final docRef = await FirebaseFirestore.instance
          .collection('reservations')
          .add(reservationData);
      final reservationId = docRef.id;

      // 2️⃣ Generar PDF
      final pdfBytes = await _generatePDF({
        ...reservationData,
        'id': reservationId,
      });

      // 3️⃣ Guardar PDF en Firebase Storage (opcional)
      // final url = await _uploadPDFToStorage(pdfBytes, reservationId);

      // 4️⃣ Mostrar PDF
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'reserva_techservice_$reservationId.pdf',
      );

      Navigator.pop(context); // Cierra el loading

      // ✅ Éxito
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✅ Reserva creada con éxito'),
          action: SnackBarAction(
            label: 'Ver',
            onPressed: () {
              // Opcional: navegar a detalle de reserva
            },
          ),
        ),
      );

      // Limpiar formulario (opcional)
      _formKey.currentState?.reset();
      setState(() {
        _selectedService = null;
        _selectedDate = null;
        _selectedTime = null;
        _selectedLocation = null;
      });
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error al guardar: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1976D2),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reservar Servicio Técnico',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            const Text(
              'Agenda tu cita y nosotros nos encargamos del resto',
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ],
        ),
      ),
      drawer: AppDrawer(
        currentRoute: '/reserve-service',
        userName: _currentUser?.displayName ?? 'Usuario',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sección 1: Información Personal
              const Text(
                'Información Personal',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Nombre
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.person),
                  labelText: 'Nombre Completo *',
                  hintText: _currentUser?.displayName ?? 'Diego Lema',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) => v!.trim().isEmpty ? 'Obligatorio' : null,
              ),
              const SizedBox(height: 20),

              // Cédula
              TextFormField(
                controller: _idController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.badge),
                  labelText: 'Cédula *',
                  hintText: '1716472038',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v!.trim().length != 10 ? '10 dígitos' : null,
              ),
              const SizedBox(height: 20),

              // Correo
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.email),
                  labelText: 'Correo Electrónico *',
                  hintText: _currentUser?.email ?? 'tu@email.com',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v!)
                    ? 'Inválido'
                    : null,
              ),
              const SizedBox(height: 20),

              // Teléfono
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.phone),
                  labelText: 'Teléfono *',
                  hintText: '0991234567',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.phone,
                validator: (v) => v!.trim().length != 10 || !v!.startsWith('09')
                    ? '09XXXXXXXX'
                    : null,
              ),
              const SizedBox(height: 20),

              // Tipo de Dispositivo
              TextFormField(
                controller: _deviceController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.laptop),
                  labelText: 'Tipo de Dispositivo *',
                  hintText: 'Ej: Laptop MSI GF63',
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
                  labelText: 'Dirección *',
                  hintText: 'Av. Amazonas y Naciones Unidas',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 2,
                validator: (v) => v!.trim().isEmpty ? 'Obligatorio' : null,
              ),
              const SizedBox(height: 20),

              // Sección 2: Seleccionar Servicio
              const Text(
                'Seleccionar Servicio',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // Tipo de Servicio
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

              // Describir el Problema
              TextFormField(
                controller: _problemController,
                decoration: InputDecoration(
                  labelText: 'Describe el Problema *',
                  hintText: 'Ej: No enciende, pantalla negra...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 4,
                validator: (v) => v!.trim().isEmpty ? 'Obligatorio' : null,
              ),
              const SizedBox(height: 20),

              // 🗓️ Fecha y Hora
              const Text(
                'Programar Cita',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      readOnly: true,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.calendar_today),
                        labelText: 'Fecha *',
                        hintText: _selectedDate != null
                            ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                            : 'Selecciona fecha',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onTap: () => _selectDate(context),
                      validator: (v) =>
                          _selectedDate == null ? 'Selecciona fecha' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      readOnly: true,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.access_time),
                        labelText: 'Hora *',
                        hintText: _selectedTime != null
                            ? _selectedTime!.format(context)
                            : 'Selecciona hora',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onTap: () => _selectTime(context),
                      validator: (v) =>
                          _selectedTime == null ? 'Selecciona hora' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // 📍 Ubicación (simulada)
              ElevatedButton.icon(
                onPressed: _simulateLocationSelection,
                icon: const Icon(Icons.gps_fixed),
                label: Text(
                  _selectedLocation != null
                      ? 'Ubicación seleccionada'
                      : 'Seleccionar ubicación',
                  style: TextStyle(
                    color: _selectedLocation != null ? Colors.green : null,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedLocation != null
                      ? Colors.green[100]
                      : null,
                ),
              ),
              const SizedBox(height: 20),

              // 📤 Botón de guardar
              ElevatedButton(
                onPressed: _saveReservation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text(
                  'Guardar Reserva',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Clase simple para coordenadas (sin Google Maps)
class LatLng {
  final double latitude;
  final double longitude;
  const LatLng(this.latitude, this.longitude);
}
