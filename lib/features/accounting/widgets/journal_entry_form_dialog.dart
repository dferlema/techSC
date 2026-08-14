import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tscomputer/core/theme/app_colors.dart';
import 'package:tscomputer/features/accounting/models/accounting_entry_model.dart';
import 'package:tscomputer/features/accounting/models/chart_of_account_model.dart';
import 'package:tscomputer/features/accounting/providers/accounting_providers.dart';

class JournalEntryFormDialog extends ConsumerStatefulWidget {
  final AccountingEntryModel? entry;
  const JournalEntryFormDialog({super.key, this.entry});

  @override
  ConsumerState<JournalEntryFormDialog> createState() => _JournalEntryFormDialogState();
}

class _JournalEntryFormDialogState extends ConsumerState<JournalEntryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descController = TextEditingController();
  late DateTime _selectedDate;
  List<_LineData> _lines = [];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.entry?.date ?? DateTime.now();
    _descController.text = widget.entry?.description ?? '';
    if (widget.entry != null) {
      _lines = widget.entry!.lines.map((l) => _LineData(
        accountId: l.accountId,
        accountCode: l.accountCode,
        accountName: l.accountName,
        debit: l.debit,
        credit: l.credit,
      )).toList();
    }
    if (_lines.isEmpty) _lines.add(_LineData());
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsStreamProvider);
    final accounts = accountsAsync.asData?.value ?? [];
    final totalDebit = _lines.fold(0.0, (sum, l) => sum + (double.tryParse(l.debitCtrl.text) ?? 0));
    final totalCredit = _lines.fold(0.0, (sum, l) => sum + (double.tryParse(l.creditCtrl.text) ?? 0));
    final balanced = (totalDebit - totalCredit).abs() < 0.01;

    return AlertDialog(
      title: Text(widget.entry != null ? 'Editar Asiento' : 'Nuevo Asiento Contable'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _descController,
                  decoration: const InputDecoration(labelText: 'Descripción', border: OutlineInputBorder()),
                  validator: (v) => v == null || v.isEmpty ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text('Fecha: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                        if (picked != null) setState(() => _selectedDate = picked);
                      },
                      child: const Text('Cambiar'),
                    ),
                  ],
                ),
                const Divider(),
                Row(
                  children: [
                    const Expanded(flex: 4, child: Text('Cuenta', style: TextStyle(fontWeight: FontWeight.bold))),
                    const Expanded(flex: 2, child: Text('Débito', style: TextStyle(fontWeight: FontWeight.bold))),
                    const Expanded(flex: 2, child: Text('Crédito', style: TextStyle(fontWeight: FontWeight.bold))),
                    const SizedBox(width: 40),
                  ],
                ),
                ..._lines.asMap().entries.map((entry) => _buildLineRow(entry.key, accounts)),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () => setState(() => _lines.add(_LineData())),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar Línea'),
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Totales: Débito \$${totalDebit.toStringAsFixed(2)} / Crédito \$${totalCredit.toStringAsFixed(2)}',
                        style: TextStyle(fontWeight: FontWeight.bold, color: balanced ? Colors.green : Colors.red)),
                    if (!balanced)
                      const Text('No balanceado', style: TextStyle(color: Colors.red, fontSize: 12)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: balanced ? () => _submit(asBorrador: true) : null,
          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[600], foregroundColor: Colors.white),
          child: const Text('Borrador'),
        ),
        FilledButton(
          onPressed: balanced ? () => _submit(asBorrador: false) : null,
          style: FilledButton.styleFrom(backgroundColor: AppColors.primaryBlue),
          child: const Text('Contabilizar'),
        ),
      ],
    );
  }

  Widget _buildLineRow(int index, List<ChartOfAccountModel> accounts) {
    final line = _lines[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: DropdownButtonFormField<String>(
              value: line.accountId.isNotEmpty ? line.accountId : null,
              isExpanded: true,
              hint: const Text('Seleccionar cuenta'),
              items: accounts.where((a) => a.isLeaf).map((a) => DropdownMenuItem(
                value: a.id,
                child: Text('${a.code} ${a.name}', style: const TextStyle(fontSize: 11)),
              )).toList(),
              onChanged: (v) {
                setState(() {
                  line.accountId = v ?? '';
                  final acct = accounts.firstWhere((a) => a.id == v, orElse: () => accounts.first);
                  line.accountCode = acct.code;
                  line.accountName = acct.name;
                  line.accountNature = acct.nature.name;
                });
              },
            ),
          ),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: line.debitCtrl,
              decoration: const InputDecoration(isDense: true, hintText: '0.00'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: line.creditCtrl,
              decoration: const InputDecoration(isDense: true, hintText: '0.00'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
            onPressed: _lines.length > 1 ? () => setState(() => _lines.removeAt(index)) : null,
          ),
        ],
      ),
    );
  }

  Future<void> _submit({required bool asBorrador}) async {
    final lines = _lines.map((l) => AccountingEntryLine(
      accountId: l.accountId,
      accountCode: l.accountCode,
      accountName: l.accountName,
      debit: double.tryParse(l.debitCtrl.text) ?? 0,
      credit: double.tryParse(l.creditCtrl.text) ?? 0,
      accountNature: l.accountNature,
    )).toList();

    final status = asBorrador ? EntryStatus.borrador : EntryStatus.contabilizado;

    final entry = AccountingEntryModel(
      id: widget.entry?.id ?? '',
      number: widget.entry?.number ?? '',
      date: _selectedDate,
      description: _descController.text.trim(),
      lines: lines,
      status: status,
    );

    try {
      final jes = ref.read(journalEntryServiceProvider);
      final entryId = await jes.saveEntry(entry);

      // Si se guardó directamente como contabilizado, aplicar saldos
      if (!asBorrador) {
        await jes.postEntry(entryId);
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }
}

class _LineData {
  String accountId;
  String accountCode;
  String accountName;
  String accountNature;
  TextEditingController debitCtrl;
  TextEditingController creditCtrl;

  _LineData({
    this.accountId = '',
    this.accountCode = '',
    this.accountName = '',
    double debit = 0.0,
    double credit = 0.0,
  })  : accountNature = '',
        debitCtrl = TextEditingController(text: debit > 0 ? debit.toStringAsFixed(2) : ''),
        creditCtrl = TextEditingController(text: credit > 0 ? credit.toStringAsFixed(2) : '');
}
