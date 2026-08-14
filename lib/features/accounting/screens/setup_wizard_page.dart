import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tscomputer/core/theme/app_colors.dart';
import 'package:tscomputer/features/accounting/models/business_config_model.dart';
import 'package:tscomputer/features/accounting/services/business_config_service.dart';

/// Wizard de configuración inicial (BLOQUE 10):
/// 1. Datos del negocio (razón social, RUC, fecha inicio)
/// 2. Saldos iniciales (capital, caja, bancos, inventario)
/// 3. Empleado inicial (opcional)
/// Al finalizar genera el asiento de apertura automáticamente.
class SetupWizardPage extends ConsumerStatefulWidget {
  const SetupWizardPage({super.key});

  @override
  ConsumerState<SetupWizardPage> createState() => _SetupWizardPageState();
}

class _SetupWizardPageState extends ConsumerState<SetupWizardPage> {
  int _step = 0;
  bool _saving = false;

  // Paso 1: negocio
  final _razonSocialController = TextEditingController();
  final _rucController = TextEditingController();
  DateTime _fechaInicio = DateTime(2024, 1, 1);

  // Paso 2: saldos
  final _capitalController = TextEditingController();
  final _cajaController = TextEditingController();
  final _bancosController = TextEditingController();
  final _inventarioController = TextEditingController();
  String _inventoryAccountCode = '1.1.03.02';

  // Paso 3: empleado
  final _cedulaController = TextEditingController();
  final _nombreController = TextEditingController();
  final _sueldoController = TextEditingController();
  DateTime _fechaIngreso = DateTime(2024, 1, 1);

  static const List<Map<String, String>> _inventoryAccounts = [
    {'code': '1.1.03.01', 'name': 'Inventario de Equipos'},
    {'code': '1.1.03.02', 'name': 'Inventario de Partes y Piezas'},
    {'code': '1.1.03.03', 'name': 'Inventario de Accesorios'},
    {'code': '1.1.03.04', 'name': 'Inventario de Software y Licencias'},
    {'code': '1.1.03.05', 'name': 'Inventario de Insumos Técnicos'},
  ];

  @override
  void dispose() {
    _razonSocialController.dispose();
    _rucController.dispose();
    _capitalController.dispose();
    _cajaController.dispose();
    _bancosController.dispose();
    _inventarioController.dispose();
    _cedulaController.dispose();
    _nombreController.dispose();
    _sueldoController.dispose();
    super.dispose();
  }

  double _num(TextEditingController c) => double.tryParse(c.text) ?? 0.0;

  bool _validateStep(int step) {
    if (step == 0) {
      if (_razonSocialController.text.trim().isEmpty || _rucController.text.trim().isEmpty) {
        _snack('Razón Social y RUC son requeridos');
        return false;
      }
      return true;
    }
    if (step == 1) {
      final capital = _num(_capitalController);
      final caja = _num(_cajaController);
      final bancos = _num(_bancosController);
      final inv = _num(_inventarioController);
      if (capital <= 0) {
        _snack('Ingrese un capital inicial válido');
        return false;
      }
      if (capital < caja + bancos + inv) {
        _snack('El capital inicial debe ser mayor o igual a la suma de activos iniciales');
        return false;
      }
      return true;
    }
    return true;
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _pickDate(bool isInicio) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isInicio ? _fechaInicio : _fechaIngreso,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isInicio) {
          _fechaInicio = picked;
        } else {
          _fechaIngreso = picked;
        }
      });
    }
  }

  Future<void> _finish() async {
    if (!_validateStep(0) || !_validateStep(1)) return;
    setState(() => _saving = true);
    try {
      final service = BusinessConfigService();

      // Guardar configuración
      await service.saveConfig(BusinessConfigModel(
        razonSocial: _razonSocialController.text.trim(),
        ruc: _rucController.text.trim(),
        fechaInicioOperaciones: _fechaInicio,
      ));

      // Asiento de apertura
      await service.generateOpeningEntry(
        capitalInicial: _num(_capitalController),
        saldoCaja: _num(_cajaController),
        saldoBancos: _num(_bancosController),
        inventarioInicial: _num(_inventarioController),
        inventoryAccountCode: _inventoryAccountCode,
        date: _fechaInicio,
      );

      // Empleado inicial (opcional)
      final nombre = _nombreController.text.trim();
      if (nombre.isNotEmpty && _num(_sueldoController) > 0) {
        await service.saveInitialEmployee(
          cedula: _cedulaController.text.trim(),
          nombre: nombre,
          sueldo: _num(_sueldoController),
          fechaIngreso: _fechaIngreso,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuración inicial completada')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _snack('Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: const Text('Configuración Inicial'),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildStepper(),
          Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: _buildStepContent())),
          _buildNavigation(),
        ],
      ),
    );
  }

  Widget _buildStepper() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          for (int i = 0; i < 3; i++) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: i < _step ? AppColors.success : (i == _step ? AppColors.primaryBlue : Colors.grey[300]),
              child: Text('${i + 1}', style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
            if (i < 2)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  color: i < _step ? AppColors.success : Colors.grey[300],
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return _buildBusinessStep();
      case 1:
        return _buildSaldosStep();
      default:
        return _buildEmployeeStep();
    }
  }

  Widget _buildBusinessStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Datos del negocio', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        TextField(
          controller: _razonSocialController,
          decoration: const InputDecoration(labelText: 'Razón Social', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _rucController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'RUC', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => _pickDate(true),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Fecha inicio operaciones',
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.date_range),
            ),
            child: Text(
              '${_fechaInicio.year}-${_fechaInicio.month.toString().padLeft(2, '0')}-${_fechaInicio.day.toString().padLeft(2, '0')}',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaldosStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Saldos iniciales', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        TextField(
          controller: _capitalController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Capital inicial (\$)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _cajaController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Saldo inicial de Caja (\$)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _bancosController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Saldo inicial de Bancos (\$)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _inventarioController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Inventario inicial (\$)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _inventoryAccountCode,
          decoration: const InputDecoration(labelText: 'Cuenta de Inventario', border: OutlineInputBorder()),
          items: _inventoryAccounts.map((a) => DropdownMenuItem(
            value: a['code'],
            child: Text('${a['code']} - ${a['name']}', style: const TextStyle(fontSize: 13)),
          )).toList(),
          onChanged: (v) => setState(() => _inventoryAccountCode = v ?? '1.1.03.02'),
        ),
      ],
    );
  }

  Widget _buildEmployeeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Empleado inicial (opcional)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        TextField(
          controller: _nombreController,
          decoration: const InputDecoration(labelText: 'Nombre del empleado', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _cedulaController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Cédula', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _sueldoController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Sueldo mensual (\$)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => _pickDate(false),
          child: InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Fecha de ingreso',
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.date_range),
            ),
            child: Text(
              '${_fechaIngreso.year}-${_fechaIngreso.month.toString().padLeft(2, '0')}-${_fechaIngreso.day.toString().padLeft(2, '0')}',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigation() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (_step > 0)
              TextButton(
                onPressed: _saving ? null : () => setState(() => _step--),
                child: const Text('Atrás'),
              ),
            const Spacer(),
            if (_step < 2)
              ElevatedButton(
                onPressed: () {
                  if (_validateStep(_step)) setState(() => _step++);
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white),
                child: const Text('Siguiente'),
              )
            else
              ElevatedButton(
                onPressed: _saving ? null : _finish,
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Finalizar y generar apertura'),
              ),
          ],
        ),
      ),
    );
  }
}
