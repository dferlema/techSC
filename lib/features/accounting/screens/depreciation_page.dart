import 'package:flutter/material.dart';
import 'package:tscomputer/features/accounting/services/depreciation_service.dart';

class DepreciationPage extends StatefulWidget {
  const DepreciationPage({super.key});

  @override
  State<DepreciationPage> createState() => _DepreciationPageState();
}

class _DepreciationPageState extends State<DepreciationPage> {
  final _service = DepreciationService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Depreciación de Activos'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.calculate),
            tooltip: 'Calcular depreciación mensual',
            onPressed: _postDepreciation,
          ),
        ],
      ),
      body: StreamBuilder<List<FixedAsset>>(
        stream: _service.getAssetsStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: Colors.orange, size: 32),
                    const SizedBox(height: 8),
                    Text('Error al cargar datos', style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('${snapshot.error}', style: TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final assets = snapshot.data ?? [];
          if (assets.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No hay activos fijos registrados',
                      style: TextStyle(color: Colors.grey, fontSize: 16)),
                  SizedBox(height: 8),
                  Text('Registre activos para calcular depreciación',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: assets.length,
            itemBuilder: (context, index) {
              final asset = assets[index];
              final progress = asset.usefulLifeMonths > 0
                  ? (asset.accumulatedDepreciation / asset.originalCost)
                      .clamp(0.0, 1.0)
                  : 0.0;
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.purple[100],
                            child: const Icon(Icons.inventory_2,
                                color: Colors.purple),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  asset.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                                Text(
                                  asset.assetAccountCode,
                                  style: TextStyle(
                                      color: Colors.grey[600], fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          if (asset.isFullyDepreciated)
                            const Chip(
                              label: Text('Depreciado',
                                  style: TextStyle(fontSize: 11)),
                              backgroundColor: Colors.green,
                              labelStyle: TextStyle(color: Colors.white),
                              visualDensity: VisualDensity.compact,
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _infoColumn('Costo', '\$${asset.originalCost.toStringAsFixed(2)}'),
                          _infoColumn('Dep. Acum.', '\$${asset.accumulatedDepreciation.toStringAsFixed(2)}'),
                          _infoColumn('Valor Neto', '\$${asset.netBookValue.toStringAsFixed(2)}'),
                          _infoColumn('Dep./Mes', '\$${asset.monthlyDepreciation.toStringAsFixed(2)}'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey[300],
                        color: asset.isFullyDepreciated ? Colors.green : Colors.purple,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}% depreciado • ${asset.monthsElapsed}/${asset.usefulLifeMonths} meses',
                        style:
                            TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddAssetDialog,
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Agregar Activo'),
      ),
    );
  }

  Widget _infoColumn(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
      ],
    );
  }

  Future<void> _postDepreciation() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Depreciación Mensual'),
        content: const Text(
          'Se calculará y registrará la depreciación mensual de todos los activos. ¿Continuar?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Calcular')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final count = await _service.postMonthlyDepreciation();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$count activo(s) depreciado(s)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAddAssetDialog() {
    final nameCtrl = TextEditingController();
    final costCtrl = TextEditingController();
    final lifeCtrl = TextEditingController(text: '60');
    String assetType = '1.2.01.01';
    String depType = '1.2.02.01';
    String expType = '5.7.01';

    final assetTypes = <Map<String, String>>[
      {'asset': '1.2.01.01', 'dep': '1.2.02.01', 'exp': '5.7.01', 'label': 'Mobiliario y Equipo'},
      {'asset': '1.2.01.02', 'dep': '1.2.02.02', 'exp': '5.7.02', 'label': 'Equipo de Cómputo'},
      {'asset': '1.2.01.03', 'dep': '1.2.02.03', 'exp': '5.7.03', 'label': 'Herramientas Técnicas'},
      {'asset': '1.2.01.04', 'dep': '1.2.02.04', 'exp': '5.7.04', 'label': 'Equipo de Diagnóstico'},
      {'asset': '1.2.01.05', 'dep': '1.2.02.05', 'exp': '5.7.05', 'label': 'Vehículo'},
      {'asset': '1.2.01.06', 'dep': '1.2.02.06', 'exp': '5.7.06', 'label': 'Software y Licencias'},
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Nuevo Activo Fijo'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del Activo',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: assetType,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de Activo',
                    border: OutlineInputBorder(),
                  ),
                  items: assetTypes
                      .map((a) => DropdownMenuItem(
                            value: a['asset'],
                            child: Text(a['label']!),
                          ))
                      .toList(),
                  onChanged: (val) {
                    final match = assetTypes.firstWhere(
                      (a) => a['asset'] == val,
                      orElse: () => assetTypes[0],
                    );
                    setDialogState(() {
                      assetType = match['asset']!;
                      depType = match['dep']!;
                      expType = match['exp']!;
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: costCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Costo Original',
                    prefixText: '\$ ',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: lifeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Vida Útil (meses)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final cost = double.tryParse(costCtrl.text) ?? 0;
                final life = int.tryParse(lifeCtrl.text) ?? 60;
                if (name.isEmpty || cost <= 0) return;

                final asset = FixedAsset(
                  id: '',
                  name: name,
                  assetAccountCode: assetType,
                  depreciationAccountCode: depType,
                  expenseAccountCode: expType,
                  originalCost: cost,
                  usefulLifeMonths: life,
                  purchaseDate: DateTime.now(),
                );
                await _service.saveAsset(asset);
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }
}
