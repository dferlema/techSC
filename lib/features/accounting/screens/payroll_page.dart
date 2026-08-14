import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tscomputer/core/theme/app_colors.dart';
import 'package:tscomputer/core/services/role_service.dart';
import 'package:tscomputer/features/accounting/models/payroll_model.dart';
import 'package:tscomputer/features/accounting/providers/accounting_providers.dart';

/// Pantalla de Nómina: genera roles de pago mensuales con cálculo de IESS,
/// décimos y fondos de reserva, y registra el asiento contable automático.
class PayrollPage extends ConsumerStatefulWidget {
  const PayrollPage({super.key});

  @override
  ConsumerState<PayrollPage> createState() => _PayrollPageState();
}

class _PayrollPageState extends ConsumerState<PayrollPage> {
  static const List<String> _empleadoRoles = [
    RoleService.TECHNICIAN,
    RoleService.SELLER,
    RoleService.ADMIN,
    RoleService.ACCOUNTING,
  ];

  String _selectedPeriod = _currentPeriod();
  final _periodController = TextEditingController();
  List<Map<String, dynamic>> _employees = [];

  @override
  void initState() {
    super.initState();
    _periodController.text = _selectedPeriod;
    _loadEmployees();
  }

  @override
  void dispose() {
    _periodController.dispose();
    super.dispose();
  }

  static String _currentPeriod() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  Future<void> _loadEmployees() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('users').get();
      final employees = snapshot.docs
          .where((doc) {
            final role = (doc.data()['role'] as String? ?? '').toLowerCase();
            return _empleadoRoles.contains(role) || role == 'admin';
          })
          .map((doc) {
        final data = doc.data();
        return {
          'uid': doc.id,
          'name': data['name'] ?? 'Sin nombre',
          'id': data['id'] ?? '',
        };
      }).toList();
      employees.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
      if (mounted) setState(() { _employees = employees; });
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  Future<void> _pickPeriod() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(int.parse(_selectedPeriod.split('-')[0]), int.parse(_selectedPeriod.split('-')[1])),
      firstDate: DateTime(2023),
      lastDate: now,
      helpText: 'Seleccione el mes del rol',
    );
    if (picked != null) {
      setState(() {
        _selectedPeriod = '${picked.year}-${picked.month.toString().padLeft(2, '0')}';
        _periodController.text = _selectedPeriod;
      });
    }
  }

  Future<void> _showGenerateDialog() async {
    if (_employees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('No hay empleados registrados. Asigne rol de técnico/vendedor a un usuario primero.'),
      ));
      return;
    }

    Map<String, dynamic>? selectedEmployee = _employees.first;
    final salaryController = TextEditingController(text: '470');
    final overtimeController = TextEditingController(text: '0');
    final bonusesController = TextEditingController(text: '0');
    final anticipoController = TextEditingController(text: '0');
    bool fondosReserva = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return AlertDialog(
            title: const Text('Generar Rol de Pago'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Map<String, dynamic>>(
                    initialValue: selectedEmployee,
                    decoration: const InputDecoration(
                      labelText: 'Empleado',
                      border: OutlineInputBorder(),
                    ),
                    items: _employees.map((e) => DropdownMenuItem(
                      value: e,
                      child: Text('${e['name']} (${e['id'] ?? 'sin cédula'})', overflow: TextOverflow.ellipsis),
                    )).toList(),
                    onChanged: (v) => setDialogState(() => selectedEmployee = v),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _periodController,
                    readOnly: true,
                    onTap: _pickPeriod,
                    decoration: const InputDecoration(
                      labelText: 'Período (año-mes)',
                      prefixIcon: Icon(Icons.date_range),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: salaryController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Sueldo Base',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: overtimeController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Horas Extras',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: bonusesController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Comisiones / Bonos',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: anticipoController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Anticipo (descuento)',
                      prefixText: '\$ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: fondosReserva,
                    onChanged: (v) => setDialogState(() => fondosReserva = v ?? false),
                    title: const Text('Aplicar Fondos de Reserva', style: TextStyle(fontSize: 13)),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white),
                child: const Text('Generar'),
              ),
            ],
          );
        },
      ),
    );

    if (result != true || selectedEmployee == null) return;
    final employee = selectedEmployee!;

    final base = double.tryParse(salaryController.text) ?? 0.0;
    if (base <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El sueldo base debe ser mayor a 0')));
      return;
    }

    try {
      final payrollService = ref.read(payrollServiceProvider);
      final id = await payrollService.generatePayroll(
        employeeId: employee['uid'] as String? ?? '',
        employeeName: employee['name'] as String? ?? 'Empleado',
        employeeIdentification: employee['id'] as String? ?? '',
        period: _selectedPeriod,
        baseSalary: base,
        overtime: double.tryParse(overtimeController.text) ?? 0.0,
        bonuses: double.tryParse(bonusesController.text) ?? 0.0,
        anticipo: double.tryParse(anticipoController.text) ?? 0.0,
        applyFondosReserva: fondosReserva,
      );
      if (mounted && id.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rol de pago generado correctamente')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _markPaid(PayrollModel payroll) async {
    try {
      await ref.read(payrollServiceProvider).markPaid(payroll.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rol marcado como pagado')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _payIess(String period) async {
    if (period.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona un período')));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pagar aportes IESS'),
        content: const Text('Se registrará el pago de los aportes personal y patronal del período. ¿Continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white),
            child: const Text('Pagar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(payrollServiceProvider).payIess(period);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pago IESS registrado')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final payrollsAsync = ref.watch(payrollStreamProvider);
    final currency = NumberFormat.currency(locale: 'es_EC', symbol: '\$');

    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: const Text('Nómina'),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            tooltip: 'Pagar IESS del período',
            onPressed: () => _payIess(_selectedPeriod),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Generar rol',
            onPressed: _showGenerateDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _periodController,
                    readOnly: true,
                    onTap: _pickPeriod,
                    decoration: const InputDecoration(
                      labelText: 'Período',
                      prefixIcon: Icon(Icons.date_range),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => setState(() {}),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Filtrar'),
                ),
              ],
            ),
          ),
          Expanded(
            child: payrollsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (all) {
                final payrolls = _selectedPeriod.isEmpty
                    ? all
                    : all.where((p) => p.period == _selectedPeriod).toList();
                if (payrolls.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.payments_outlined, size: 56, color: Colors.grey),
                        const SizedBox(height: 12),
                        const Text('Sin roles de pago para el período'),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: _showGenerateDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Generar rol'),
                        ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => setState(() {}),
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 80),
                    itemCount: payrolls.length,
                    itemBuilder: (context, index) {
                      final p = payrolls[index];
                      return Card(
                        elevation: 1,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(p.employeeName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  ),
                                  _statusBadge(p.status),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text('${p.period}  ·  Cédula: ${p.employeeIdentification.isEmpty ? '—' : p.employeeIdentification}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                              const Divider(height: 16),
                              _row('Sueldo base', currency.format(p.baseSalary)),
                              if (p.overtime > 0) _row('Horas extras', currency.format(p.overtime)),
                              if (p.bonuses > 0) _row('Comisiones/Bonos', currency.format(p.bonuses)),
                              _row('Aporte personal IESS (9.45%)', '-${currency.format(p.aportePersonal)}', negative: true),
                              _row('Aporte patronal IESS (11.15%)', currency.format(p.aportePatronal)),
                              _row('Décimo tercero', currency.format(p.decimoTercero)),
                              _row('Décimo cuarto', currency.format(p.decimoCuarto)),
                              if (p.fondosReserva > 0) _row('Fondos de reserva', currency.format(p.fondosReserva)),
                              if (p.anticipo > 0) _row('Anticipo', '-${currency.format(p.anticipo)}', negative: true),
                              const Divider(height: 16),
                              _row('NETO A PAGAR', currency.format(p.netoPagar), bold: true),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextButton.icon(
                                      onPressed: p.status == PayrollStatus.pagado ? null : () => _markPaid(p),
                                      icon: const Icon(Icons.check_circle, size: 18),
                                      label: const Text('Marcar pagado'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(PayrollStatus status) {
    final (label, color) = switch (status) {
      PayrollStatus.generado => ('Generado', Colors.orange[800]),
      PayrollStatus.pagado => ('Pagado', Colors.green[700]),
      PayrollStatus.anulado => ('Anulado', Colors.red[700]),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color!.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _row(String label, String value, {bool negative = false, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: TextStyle(
            fontSize: 12,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: negative ? Colors.red[700] : Colors.black87,
          )),
        ],
      ),
    );
  }
}
