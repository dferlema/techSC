import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tscomputer/core/theme/app_colors.dart';
import 'package:tscomputer/features/accounting/models/chart_of_account_model.dart';
import 'package:tscomputer/features/accounting/providers/accounting_providers.dart';

class AccountFormDialog extends ConsumerStatefulWidget {
  final ChartOfAccountModel? account;
  const AccountFormDialog({super.key, this.account});

  @override
  ConsumerState<AccountFormDialog> createState() => _AccountFormDialogState();
}

class _AccountFormDialogState extends ConsumerState<AccountFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codeController;
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late AccountType _selectedType;
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    final a = widget.account;
    _codeController = TextEditingController(text: a?.code ?? '');
    _nameController = TextEditingController(text: a?.name ?? '');
    _descController = TextEditingController(text: a?.description ?? '');
    _selectedType = a?.type ?? AccountType.activo;
    _isActive = a?.isActive ?? true;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.account != null ? 'Editar Cuenta' : 'Nueva Cuenta'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(labelText: 'Código', hintText: '1.1.01', border: OutlineInputBorder()),
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nombre de la Cuenta', border: OutlineInputBorder()),
                validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AccountType>(
                value: _selectedType,
                decoration: const InputDecoration(labelText: 'Tipo', border: OutlineInputBorder()),
                items: AccountType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name.toUpperCase()))).toList(),
                onChanged: (v) => setState(() => _selectedType = v ?? AccountType.activo),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: 'Descripción', border: OutlineInputBorder()),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('Activa'),
                value: _isActive,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setState(() => _isActive = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white),
          child: const Text('Guardar'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final account = ChartOfAccountModel(
      id: widget.account?.id ?? '',
      code: _codeController.text.trim(),
      name: _nameController.text.trim(),
      type: _selectedType,
      nature: _selectedType == AccountType.activo || _selectedType == AccountType.gasto || _selectedType == AccountType.costo
          ? AccountNature.deudora
          : AccountNature.acreedora,
      isLeaf: true,
      isActive: _isActive,
      description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
    );
    try {
      await ref.read(chartOfAccountsServiceProvider).saveAccount(account);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}
