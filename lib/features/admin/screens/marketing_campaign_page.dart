import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:techsc/features/admin/providers/admin_providers.dart';
import 'package:techsc/features/auth/models/user_model.dart';
import 'package:techsc/core/utils/whatsapp_share_helper.dart';
import 'package:techsc/core/theme/app_colors.dart';
import 'package:techsc/l10n/app_localizations.dart';
import 'dart:convert';

class MarketingCampaignPage extends ConsumerStatefulWidget {
  const MarketingCampaignPage({super.key});

  @override
  ConsumerState<MarketingCampaignPage> createState() =>
      _MarketingCampaignPageState();
}

class _MarketingCampaignPageState extends ConsumerState<MarketingCampaignPage> {
  Map<String, dynamic>? _selectedProduct;
  String _searchQuery = '';
  String _productSearchQuery = '';
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.whatsappMarketingTitle),
        elevation: 0,
        backgroundColor: AppColors.primaryBlue,
      ),
      body: Column(
        children: [
          _buildProductPicker(l10n),
          if (_selectedProduct != null) ...[
            _buildCampaignSummary(l10n),
            Expanded(child: _buildClientList(l10n)),
          ] else
            Expanded(child: Center(child: Text(l10n.marketingPrompt))),
        ],
      ),
    );
  }

  Widget _buildProductPicker(AppLocalizations l10n) {
    final productsAsync = ref.watch(availableProductsProvider);

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
          Text(
            l10n.step1SelectProduct,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: InputDecoration(
              hintText: l10n.searchProductHint,
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _productSearchQuery = value),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 100,
            child: productsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
              data: (docs) {
                final products = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  return name.contains(_productSearchQuery.toLowerCase());
                }).toList();

                if (products.isEmpty) {
                  return Center(child: Text(l10n.noProductsFound));
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

  Widget _buildCampaignSummary(AppLocalizations l10n) {
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
                  l10n.promotingText(_selectedProduct!['name'] ?? ''),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  l10n.marketingDescription,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _isExporting ? null : () => _exportCampaignCSV(l10n),
            icon: _isExporting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Icons.file_download, color: AppColors.primaryBlue),
            tooltip: l10n.exportCSVTooltip,
          ),
        ],
      ),
    );
  }

  Future<void> _exportCampaignCSV(AppLocalizations l10n) async {
    if (_selectedProduct == null) return;

    setState(() => _isExporting = true);

    try {
      final clients = ref.read(marketingClientsProvider).value ?? [];
      final productName = _selectedProduct!['name'] ?? 'Producto';

      final StringBuffer buffer = StringBuffer();
      buffer.writeln(
        '"Número con formato 593991090805","Nombre","Mensaje","producto"',
      );

      for (var client in clients) {
        if (client.phone.isEmpty) continue;

        final personalizedMessage =
            WhatsAppShareHelper.generateMarketingMessage(
              _selectedProduct!,
              clientName: client.name,
            );

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
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${l10n.errorPrefix}: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Widget _buildClientList(AppLocalizations l10n) {
    final clientsAsync = ref.watch(marketingClientsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: l10n.searchClientHint,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
        ),
        Expanded(
          child: clientsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
            data: (allClients) {
              var clients = allClients;
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
                return Center(child: Text(l10n.noClientsFound));
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
                        child: Text(
                          client.name.isNotEmpty
                              ? client.name[0].toUpperCase()
                              : '?',
                        ),
                      ),
                      title: Text(client.name),
                      subtitle: Text(client.phone),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.send_rounded,
                          color: AppColors.whatsapp,
                        ),
                        onPressed: () => _sendPromotion(client, l10n),
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

  Future<void> _sendPromotion(UserModel client, AppLocalizations l10n) async {
    if (_selectedProduct == null) return;

    if (client.phone.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.noPhoneNumber)));
      return;
    }

    await WhatsAppShareHelper.sendMarketingMessage(
      productData: _selectedProduct!,
      phone: client.phone,
      context: context,
      clientName: client.name,
    );
  }
}
