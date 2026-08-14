import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tscomputer/core/theme/app_colors.dart';
import 'package:tscomputer/features/accounting/models/budget_model.dart';
import 'package:tscomputer/features/accounting/models/transaction_model.dart';

class BudgetPage extends StatefulWidget {
  const BudgetPage({super.key});

  @override
  State<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends State<BudgetPage> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final firestore = FirebaseFirestore.instance;

      // Get budgets for the period
      final budgetSnap = await firestore
          .collection('budgets')
          .where('year', isEqualTo: _year)
          .where('month', isEqualTo: _month)
          .get();
      final budgets = budgetSnap.docs.map((d) => BudgetModel.fromMap(d.data(), d.id)).toList();

      // Get actual transactions for the period
      final start = DateTime(_year, _month, 1);
      final end = DateTime(_year, _month + 1, 0, 23, 59, 59);
      final txSnap = await firestore
          .collection('accounting_transactions')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();
      final txs = txSnap.docs.map((d) => TransactionModel.fromMap(d.data(), d.id)).toList();

      // Group actuals by category and type
      final Map<String, double> actualIngresos = {};
      final Map<String, double> actualEgresos = {};
      for (final t in txs) {
        if (t.type == TransactionType.ingreso) {
          actualIngresos[t.category] = (actualIngresos[t.category] ?? 0) + t.total;
        } else {
          actualEgresos[t.category] = (actualEgresos[t.category] ?? 0) + t.total;
        }
      }

      final results = <Map<String, dynamic>>[];

      for (final b in budgets) {
        final actuals = b.type == 'ingreso' ? actualIngresos : actualEgresos;
        final actual = actuals[b.category] ?? 0.0;
        final diff = actual - b.budgetedAmount;
        final pct = b.budgetedAmount > 0 ? (actual / b.budgetedAmount) * 100 : 0.0;
        results.add({
          'category': b.category,
          'type': b.type,
          'budget': b.budgetedAmount,
          'actual': actual,
          'diff': diff,
          'pct': pct,
        });
      }

      results.sort((a, b) => (b['diff'] as double).compareTo(a['diff'] as double));

      if (mounted) setState(() { _rows = results; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceLight,
      appBar: AppBar(
        title: Text('Presupuesto vs Real $_month/$_year'),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.arrow_left),
            onPressed: () { setState(() { if (_month > 1) { _month--; } else { _month = 12; _year--; } }); _load(); },
          ),
          IconButton(
            icon: const Icon(Icons.arrow_right),
            onPressed: () { setState(() { if (_month < 12) { _month++; } else { _month = 1; _year++; } }); _load(); },
          ),
          IconButton(icon: const Icon(Icons.add), onPressed: () => _showAddDialog()),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      const Text('Sin presupuestos para este período'),
                      const SizedBox(height: 16),
                      FilledButton.tonal(onPressed: _showAddDialog, child: const Text('Agregar presupuesto')),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _rows.length,
                    itemBuilder: (context, index) {
                      final r = _rows[index];
                      final isIngreso = r['type'] == 'ingreso';
                      final pct = r['pct'] as double;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 1,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(r['category'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (isIngreso ? Colors.green : Colors.red).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(isIngreso ? 'INGRESO' : 'EGRESO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold,
                                        color: isIngreso ? Colors.green[700] : Colors.red[700])),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _bar('Presupuesto', r['budget'] as double, Colors.blue),
                                  const SizedBox(width: 8),
                                  _bar('Real', r['actual'] as double, isIngreso ? Colors.green : Colors.red),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Diferencia: \$${(r['diff'] as double).toStringAsFixed(2)}',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                                          color: (r['diff'] as double) >= 0 ? Colors.green[700] : Colors.red[700])),
                                  Text('${pct.toStringAsFixed(0)}%', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddDialog,
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _bar(String label, double amount, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
            Text('\$${amount.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
          ],
        ),
      ),
    );
  }

  void _showAddDialog() {
    final catCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    String type = 'egreso';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Nuevo presupuesto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: catCtrl, decoration: const InputDecoration(labelText: 'Categoría', hintText: 'Ej: Arriendo')),
              const SizedBox(height: 12),
              TextField(controller: amtCtrl, decoration: const InputDecoration(labelText: 'Monto presupuestado'), keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: type,
                items: const [
                  DropdownMenuItem(value: 'egreso', child: Text('Gasto')),
                  DropdownMenuItem(value: 'ingreso', child: Text('Ingreso')),
                ],
                onChanged: (v) => setDialogState(() => type = v ?? 'egreso'),
                decoration: const InputDecoration(labelText: 'Tipo'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            FilledButton(onPressed: () async {
              final cat = catCtrl.text.trim();
              final amt = double.tryParse(amtCtrl.text.trim()) ?? 0;
              if (cat.isEmpty || amt <= 0) return;
              await FirebaseFirestore.instance.collection('budgets').add({
                'year': _year,
                'month': _month,
                'category': cat,
                'budgetedAmount': amt,
                'type': type,
              });
              if (ctx.mounted) Navigator.pop(ctx);
              _load();
            }, child: const Text('Guardar')),
          ],
        ),
      ),
    );
  }
}
