import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../services/config_service.dart';

class AppColorsConfigPage extends StatefulWidget {
  const AppColorsConfigPage({super.key});

  @override
  State<AppColorsConfigPage> createState() => _AppColorsConfigPageState();
}

class _AppColorsConfigPageState extends State<AppColorsConfigPage> {
  late Map<String, int> _currentColors;
  bool _isLoading = false;

  final Map<String, Map<String, String>> _colorInfo = {
    'primaryBlue': {
      'label': 'Azul Primario',
      'description': 'Color principal (AppBar, Botones primarios)',
    },
    'primaryDark': {
      'label': 'Azul Oscuro',
      'description': 'Variantes oscuras y estados activos',
    },
    'accentOrange': {
      'label': 'Acento (Naranja)',
      'description': 'Botones de acción, destacados y llamadas a la acción',
    },
    'backgroundGray': {
      'label': 'Fondo Gris',
      'description': 'Fondo general de las pantallas (Scaffold)',
    },
    'white': {
      'label': 'Blanco',
      'description': 'Fondos de tarjetas, diálogos y texto sobre color',
    },
    'black': {'label': 'Negro', 'description': 'Elementos de alto contraste'},
    'error': {
      'label': 'Error',
      'description': 'Mensajes de error, validaciones y alertas',
    },
    'success': {
      'label': 'Éxito',
      'description': 'Indicadores de éxito, completado y confirmaciones',
    },
    'warning': {
      'label': 'Advertencia',
      'description': 'Alertas no críticas y estados de precaución',
    },
    'textPrimary': {
      'label': 'Texto Primario',
      'description': 'Títulos y contenido principal legible',
    },
    'textSecondary': {
      'label': 'Texto Secundario',
      'description': 'Subtítulos, fechas y metadatos',
    },
    'divider': {
      'label': 'Divisor',
      'description': 'Líneas divisorias y bordes sutiles',
    },
    'roleAdmin': {
      'label': 'Rol Admin',
      'description': 'Identificador visual para Administradores',
    },
    'roleSeller': {
      'label': 'Rol Vendedor',
      'description': 'Identificador visual para Vendedores',
    },
    'roleTechnician': {
      'label': 'Rol Técnico',
      'description': 'Identificador visual para Técnicos/Operarios',
    },
    'roleClient': {
      'label': 'Rol Cliente',
      'description': 'Identificador visual para Clientes finales',
    },
  };

  @override
  void initState() {
    super.initState();
    _currentColors = AppColors.toColorMap();
  }

  Future<void> _saveColors() async {
    setState(() => _isLoading = true);
    try {
      final configService = ConfigService();
      await configService.saveColorConfig(_currentColors);
      AppColors.updateColors(_currentColors);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Colores guardados correctamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetDefaults() {
    AppColors.resetToDefaults();
    setState(() {
      _currentColors = AppColors.toColorMap();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Colores restablecidos. Recuerda guardar.')),
    );
  }

  void _editColor(String key, int currentColorValue) {
    Color currentColor = Color(currentColorValue);
    double r = currentColor.red.toDouble();
    double g = currentColor.green.toDouble();
    double b = currentColor.blue.toDouble();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Color previewColor = Color.fromARGB(
              255,
              r.toInt(),
              g.toInt(),
              b.toInt(),
            );
            return AlertDialog(
              title: Text('Editar ${_colorInfo[key]?['label'] ?? key}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 50,
                    width: double.infinity,
                    color: previewColor,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('R'),
                      Expanded(
                        child: Slider(
                          value: r,
                          min: 0,
                          max: 255,
                          activeColor: const Color(0xFFFF0000),
                          onChanged: (v) => setStateDialog(() => r = v),
                        ),
                      ),
                      Text(r.toInt().toString()),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('G'),
                      Expanded(
                        child: Slider(
                          value: g,
                          min: 0,
                          max: 255,
                          activeColor: const Color(0xFF00FF00),
                          onChanged: (v) => setStateDialog(() => g = v),
                        ),
                      ),
                      Text(g.toInt().toString()),
                    ],
                  ),
                  Row(
                    children: [
                      const Text('B'),
                      Expanded(
                        child: Slider(
                          value: b,
                          min: 0,
                          max: 255,
                          activeColor: const Color(0xFF0000FF),
                          onChanged: (v) => setStateDialog(() => b = v),
                        ),
                      ),
                      Text(b.toInt().toString()),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _currentColors[key] = previewColor.value;
                    });
                    // Apply preview immediately? No, wait for save?
                    // Or maybe apply locally to see effect?
                    // Let's just update local state map.
                    Navigator.pop(context);
                  },
                  child: const Text('Aplicar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configurar Colores'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restore),
            tooltip: 'Restablecer valores por defecto',
            onPressed: _resetDefaults,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _colorInfo.length,
              itemBuilder: (context, index) {
                final key = _colorInfo.keys.elementAt(index);
                final info = _colorInfo[key]!;
                final label = info['label']!;
                final description = info['description']!;
                final colorValue = _currentColors[key] ?? 0xFF000000;
                final color = Color(colorValue);

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    title: Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'HEX: #${colorValue.toRadixString(16).toUpperCase().substring(2)}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => _editColor(key, colorValue),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _saveColors,
        child: const Icon(Icons.save),
      ),
    );
  }
}
