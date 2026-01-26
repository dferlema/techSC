import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../services/marketing_service.dart';
import '../models/user_model.dart';
import '../utils/whatsapp_share_helper.dart';
import '../theme/app_colors.dart';
import 'dart:convert';

/// Página de Campaña de Marketing
/// Permite a los administradores y personal seleccionar un producto y enviarlo
/// como publicidad a los clientes registrados a través de WhatsApp.
class MarketingCampaignPage extends StatefulWidget {
  const MarketingCampaignPage({super.key});

  @override
  State<MarketingCampaignPage> createState() => _MarketingCampaignPageState();
}

class _MarketingCampaignPageState extends State<MarketingCampaignPage> {
  // Servicio para manejar datos de marketing (clientes y productos)
  final MarketingService _marketingService = MarketingService();

  // Producto seleccionado para la campaña
  Map<String, dynamic>? _selectedProduct;

  // Consulta de búsqueda para la lista de clientes
  String _searchQuery = '';

  // Consulta de búsqueda para el selector de productos
  String _productSearchQuery = '';

  // Estado de carga durante la exportación de CSV
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Se agregó AppBar para permitir navegación hacia atrás (retroceder)
      appBar: AppBar(
        title: const Text('Campaña de Marketing WhatsApp'),
        elevation: 0,
        backgroundColor: AppColors.primaryBlue,
      ),
      body: Column(
        children: [
          // Sección de selección de producto con búsqueda inteligente
          _buildProductPicker(),
          // Muestra el resumen de la campaña y la lista de clientes si un producto está seleccionado
          if (_selectedProduct != null) ...[
            // Resumen del producto seleccionado y opción de exportar CSV
            _buildCampaignSummary(),
            // Lista de clientes para enviar la promoción
            Expanded(child: _buildClientList()),
          ] else
            // Mensaje para seleccionar un producto si no hay ninguno
            const Expanded(
              child: Center(
                child: Text('Selecciona un producto para comenzar la campaña'),
              ),
            ),
        ],
      ),
    );
  }

  /// Selector de productos con búsqueda en tiempo real
  Widget _buildProductPicker() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '1. Selecciona el Producto (Búsqueda Inteligente)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              hintText: 'Buscar por nombre de producto...',
              prefixIcon: Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _productSearchQuery = value),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: StreamBuilder<QuerySnapshot>(
              stream: _marketingService.getAvailableProducts(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final products = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  return name.contains(_productSearchQuery.toLowerCase());
                }).toList();

                if (products.isEmpty) {
                  return const Center(
                    child: Text('No se encontraron productos'),
                  );
                }

                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final doc = products[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final isSelected = _selectedProduct?['id'] == doc.id;
                    final imageUrl = data['image'] ?? data['imageUrl'] ?? '';

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedProduct = {...data, 'id': doc.id};
                        });
                      },
                      child: Container(
                        width: 80,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primaryBlue
                                : Colors.grey[300]!,
                            width: isSelected ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          color: isSelected
                              ? AppColors.primaryBlue.withOpacity(0.1)
                              : AppColors.white,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (imageUrl.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: Image.network(
                                  imageUrl,
                                  height: 40,
                                  width: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.image_not_supported,
                                    size: 20,
                                  ),
                                ),
                              )
                            else
                              const Icon(Icons.inventory_2, size: 30),
                            const SizedBox(height: 4),
                            Text(
                              data['name'] ?? 'P...',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Resumen de la campaña seleccionada y botón de exportación CSV
  Widget _buildCampaignSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.warning.withOpacity(0.1),
      child: Row(
        children: [
          Icon(Icons.campaign, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Promocionando: ${_selectedProduct!['name']}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Envía mensajes individuales o descarga el CSV para envíos masivos.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _isExporting ? null : _exportCampaignCSV,
            icon: _isExporting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.file_download, color: AppColors.primaryBlue),
            tooltip: 'Exportar CSV para WaSender',
          ),
        ],
      ),
    );
  }

  /// Exporta los datos de la campaña a un archivo CSV formateado para WaSender
  Future<void> _exportCampaignCSV() async {
    if (_selectedProduct == null) return;

    setState(() => _isExporting = true);

    try {
      final clients = await _marketingService.getClients().first;
      final productName = _selectedProduct!['name'] ?? 'Producto';

      final StringBuffer buffer = StringBuffer();
      // Headers requested by user
      buffer.writeln(
        '"Número con formato 593991090805","Nombre","Mensaje","producto"',
      );

      for (var client in clients) {
        if (client.phone.isEmpty) continue;

        // Generate personalized message for each client
        final personalizedMessage =
            WhatsAppShareHelper.generateMarketingMessage(
              _selectedProduct!,
              clientName: client.name,
            );

        // Formato internacional (593...) sin + para máxima compatibilidad
        String cleanPhone = client.phone.replaceAll(RegExp(r'\D'), '');
        if (cleanPhone.length == 10 && cleanPhone.startsWith('0')) {
          cleanPhone = '593${cleanPhone.substring(1)}';
        } else if (cleanPhone.length == 9) {
          cleanPhone = '593$cleanPhone';
        }

        buffer.writeln(
          '"$cleanPhone","${client.name}","${personalizedMessage.replaceAll('"', '""')}","$productName"',
        );
      }

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/campana_marketing.csv');
      await file.writeAsString(buffer.toString(), encoding: utf8);

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Campaña Marketing - $productName',
        text: 'CSV para envío masivo de publicidad.',
      );
    } catch (e) {
      debugPrint('Error exporting campaign CSV: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al exportar: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  /// Lista de clientes con barra de búsqueda
  Widget _buildClientList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Buscar clientes...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        Expanded(
          child: StreamBuilder<List<UserModel>>(
            stream: _marketingService.getClients(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              var clients = snapshot.data ?? [];
              if (_searchQuery.isNotEmpty) {
                clients = clients
                    .where(
                      (c) =>
                          c.name.toLowerCase().contains(
                            _searchQuery.toLowerCase(),
                          ) ||
                          c.phone.contains(_searchQuery),
                    )
                    .toList();
              }

              if (clients.isEmpty) {
                return const Center(child: Text('No se encontraron clientes'));
              }

              return ListView.builder(
                itemCount: clients.length,
                itemBuilder: (context, index) {
                  final client = clients[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primaryBlue.withOpacity(0.2),
                        child: Text(client.name[0].toUpperCase()),
                      ),
                      title: Text(client.name),
                      subtitle: Text(client.phone),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.send_rounded,
                          color: AppColors.whatsapp,
                        ),
                        onPressed: () => _sendPromotion(client),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _sendPromotion(UserModel client) async {
    if (_selectedProduct == null) return;

    if (client.phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Este cliente no tiene número de teléfono'),
        ),
      );
      return;
    }

    await WhatsAppShareHelper.sendMarketingMessage(
      productData: _selectedProduct!,
      phone: client.phone,
      context: context,
      clientName: client.name,
    );

    // Optional: Log it
    // _marketingService.logPromotionSent(
    //   productId: _selectedProduct!['id'],
    //   clientUid: client.uid,
    //   sentBy: 'admin',
    // );
  }
}
