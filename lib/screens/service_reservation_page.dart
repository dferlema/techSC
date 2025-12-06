// lib/screens/service_reservation_page.dart

import 'package:flutter/material.dart';

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
  final _deviceController = TextEditingController();
  final _addressController = TextEditingController(); // 👈 Nuevo
  final _problemController = TextEditingController();

  String? _selectedService;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  final List<String> _services = [
    'Reparación de Hardware',
    'Instalación de Software',
    'Formateo y Limpieza',
    'Actualización de Componentes',
    'Diagnóstico Técnico',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _deviceController.dispose();
    _addressController.dispose(); // 👈
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
      helpText: 'Selecciona la fecha',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // ⏰ Seleccionar hora
  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      helpText: 'Selecciona la hora',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      if (_selectedDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor selecciona una fecha')),
        );
        return;
      }
      if (_selectedTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor selecciona una hora')),
        );
        return;
      }

      final formattedDate =
          '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}';
      final formattedTime = _selectedTime!.format(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '✅ Reserva agendada para $formattedDate a las $formattedTime',
          ),
          backgroundColor: Colors.green,
        ),
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
            Text(
              'Reservar Servicio Técnico',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Agenda tu cita y nosotros nos encargamos del resto',
              style: TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.menu, color: Colors.white),
            onPressed: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Menú presionado')));
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
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

              // Nombre Completo
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.person),
                  labelText: 'Nombre Completo *',
                  hintText: 'Juan Pérez',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El nombre es obligatorio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Correo Electrónico
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
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El correo es obligatorio';
                  }
                  if (!RegExp(
                    r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                  ).hasMatch(value)) {
                    return 'Formato de correo inválido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Teléfono
              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.phone),
                  labelText: 'Teléfono *',
                  hintText: '+1 234 567 8900',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El teléfono es obligatorio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Tipo de Dispositivo
              TextFormField(
                controller: _deviceController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.laptop),
                  labelText: 'Tipo de Dispositivo *',
                  hintText: 'Ej: Laptop HP, PC de Escritorio',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'El tipo de dispositivo es obligatorio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // 📍 Dirección (Nuevo)
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.location_on),
                  labelText: 'Dirección *',
                  hintText: 'Ej: Av. Amazonas y Naciones Unidas, Quito',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 2,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'La dirección es obligatoria';
                  }
                  return null;
                },
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
                initialValue: _selectedService,
                onChanged: (value) {
                  setState(() {
                    _selectedService = value;
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Tipo de Servicio *',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: _services.map((service) {
                  return DropdownMenuItem<String>(
                    value: service,
                    child: Text(service),
                  );
                }).toList(),
                validator: (value) {
                  if (value == null) {
                    return 'Por favor selecciona un servicio';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // 📅 Fecha
              TextFormField(
                readOnly: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.calendar_today),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.edit_calendar),
                    onPressed: () => _selectDate(context),
                  ),
                  labelText: 'Fecha de la Cita *',
                  hintText: _selectedDate != null
                      ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                      : 'Selecciona una fecha',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onTap: () => _selectDate(context),
                validator: (value) {
                  if (_selectedDate == null) {
                    return 'Por favor selecciona una fecha';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // ⏰ Hora
              TextFormField(
                readOnly: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.access_time),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.access_time_filled),
                    onPressed: () => _selectTime(context),
                  ),
                  labelText: 'Hora de la Cita *',
                  hintText: _selectedTime != null
                      ? _selectedTime!.format(context)
                      : 'Selecciona una hora',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onTap: () => _selectTime(context),
                validator: (value) {
                  if (_selectedTime == null) {
                    return 'Por favor selecciona una hora';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Describir el Problema
              TextFormField(
                controller: _problemController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Describe el Problema *',
                  hintText:
                      'Describe con detalle el problema que presenta tu dispositivo...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor describe el problema';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Botón de Envío
              ElevatedButton(
                onPressed: _submitForm,
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
                  'Enviar Reserva',
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
