import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:techsc/core/services/config_service.dart';
import 'package:techsc/core/theme/app_colors.dart';
import 'package:techsc/features/admin/models/profit_range_model.dart';
import 'package:techsc/features/admin/providers/admin_providers.dart';

class ProfitMarginSettingsPage extends ConsumerStatefulWidget {
  const ProfitMarginSettingsPage({super.key});

  @override
  ConsumerState<ProfitMarginSettingsPage> createState() =>
      _ProfitMarginSettingsPageState();
}

class _ProfitMarginSettingsPageState
    extends ConsumerState<ProfitMarginSettingsPage> {
  final ConfigService _configService = ConfigService();

  Future<void> addRange(List<ProfitRange> currentRanges) async {
    final minController = TextEditingController();
    final maxController = TextEditingController();
    final profitController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<ProfitRange>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nuevo Rango de Ganancia'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: minController,
                decoration: const InputDecoration(
                  labelText: 'Precio Mínimo (\$)',
                ),
                keyboardType: TextInputType.number,
                validator: (v) =>
                    double.tryParse(v ?? '') == null ? 'Requerido' : null,
              ),
              TextFormField(
                controller: maxController,
                decoration: const InputDecoration(
                  labelText: 'Precio Máximo (\$)',
                ),
                keyboardType: TextInputType.number,
                validator: (v) =>
                    double.tryParse(v ?? '') == null ? 'Requerido' : null,
              ),
              TextFormField(
                controller: profitController,
                decoration: const InputDecoration(labelText: 'Ganancia (%)'),
                keyboardType: TextInputType.number,
                validator: (v) =>
                    double.tryParse(v ?? '') == null ? 'Requerido' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(
                  context,
                  ProfitRange(
                    minPrice: double.parse(minController.text),
                    maxPrice: double.parse(maxController.text),
                    profitPercentage: double.parse(profitController.text),
                  ),
                );
              }
            },
            child: const Text('Agregar'),
          ),
        ],
      ),
    );

    if (result != null) {
      final updated = [...currentRanges, result];
      updated.sort((a, b) => a.minPrice.compareTo(b.minPrice));
      _save(updated);
    }
  }

  Future<void> _save(List<ProfitRange> ranges) async {
    try {
      await _configService.updateProfitRanges(ranges);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuración guardada correctamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final rangesAsync = ref.watch(profitRangesProvider);

    return rangesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (ranges) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                color: AppColors.primaryBlue.withAlpha(25),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: AppColors.primaryBlue),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Configura los porcentajes de ganancia según el costo del producto. El sistema usará estos rangos para calcular el PVP automáticamente.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: ranges.length,
                itemBuilder: (context, index) {
                  final range = ranges[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.primaryBlue.withAlpha(50),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(color: AppColors.primaryBlue),
                      ),
                    ),
                    title: Text(
                      '\$${range.minPrice.toStringAsFixed(2)} - \$${range.maxPrice.toStringAsFixed(2)}',
                    ),
                    subtitle: Text('Ganancia: ${range.profitPercentage}%'),
                    trailing: IconButton(
                      icon: Icon(Icons.delete, color: AppColors.error),
                      onPressed: () {
                        final updated = [...ranges];
                        updated.removeAt(index);
                        _save(updated);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
