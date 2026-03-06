import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:techsc/features/inventory/providers/inventory_providers.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:techsc/core/widgets/app_loading_indicator.dart';
import 'package:techsc/core/widgets/app_error_widget.dart';

class InventoryReportsPage extends ConsumerWidget {
  const InventoryReportsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movementsAsync = ref.watch(allMovementsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Inteligencia de Inventario')),
      body: movementsAsync.when(
        loading: () => const AppLoadingIndicator(),
        error: (err, _) => AppErrorWidget(error: err),
        data: (movements) {
          if (movements.isEmpty) {
            return const Center(
              child: Text('No hay datos suficientes para análisis IA.'),
            );
          }

          // Calculate some metrics for the UI
          int totalInward = movements
              .where((m) => m.type.name == 'inward')
              .fold(0, (sum, m) => sum + m.quantity);
          int totalOutward = movements
              .where((m) => m.type.name == 'outward')
              .fold(0, (sum, m) => sum + m.quantity);

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Métricas de Uso General',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Card(
                        color: Colors.green[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              const Text('Total Entradas'),
                              Text(
                                '$totalInward',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Card(
                        color: Colors.red[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              const Text('Total Salidas'),
                              Text(
                                '$totalOutward',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                const Text(
                  'Preparación para IA',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Usa los datos estructurados a continuación para alimentar modelos de inferencia o LLMs (ej. ChatGPT/Claude) y obtener predicciones de quiebre de stock, sugerencias de reabastecimiento o detectar anomalías.',
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('Copiar JSON del Historial para IA'),
                  onPressed: () async {
                    try {
                      final service = ref.read(inventoryServiceProvider);
                      final report = await service
                          .generateInventoryReportForAI();
                      final jsonString = const JsonEncoder.withIndent(
                        '  ',
                      ).convert(report);
                      await Clipboard.setData(ClipboardData(text: jsonString));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Copiado al portapapeles. ¡Pégalo en tu IA preferida!',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('Error: $e')));
                      }
                    }
                  },
                ),
                const SizedBox(height: 24),
                const Expanded(
                  child: Card(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'Próximamente: Integración automática con API externa para predicciones de stock en tiempo real.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontStyle: FontStyle.italic,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
