import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:techsc/features/catalog/models/supplier_model.dart';
import 'package:techsc/features/catalog/services/supplier_service.dart';
import 'package:techsc/features/catalog/screens/supplier_form_page.dart';

/// Página de gestión de proveedores.
///
/// Muestra la lista de proveedores con opciones para agregar, editar y eliminar.
class SupplierManagementPage extends StatefulWidget {
  const SupplierManagementPage({super.key});

  @override
  State<SupplierManagementPage> createState() => _SupplierManagementPageState();
}

class _SupplierManagementPageState extends State<SupplierManagementPage> {
  final _supplierService = SupplierService();

  Future<void> _deleteSupplier(SupplierModel supplier) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar eliminación'),
        content: Text(
          '¿Estás seguro de eliminar el proveedor "${supplier.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _supplierService.deleteSupplier(supplier.id);
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('✅ Proveedor eliminado')));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Error: ${e.toString()}')));
      }
    }
  }

  Future<void> _navigateToForm({SupplierModel? supplier}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SupplierFormPage(supplier: supplier),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            supplier == null ? '✅ Proveedor creado' : '✅ Proveedor actualizado',
          ),
        ),
      );
    }
  }

  /// Opens WhatsApp with the supplier's contact phone
  Future<void> _openWhatsApp(String phone, String contactName) async {
    // Clean phone number (only digits)
    String cleanPhone = phone.replaceAll(RegExp(r'\D'), '');

    // Add Ecuador country code if needed
    if (cleanPhone.length == 10 && cleanPhone.startsWith('0')) {
      cleanPhone = '593${cleanPhone.substring(1)}';
    } else if (cleanPhone.length == 9) {
      cleanPhone = '593$cleanPhone';
    }

    final Uri whatsappUrl = Uri.parse('https://wa.me/$cleanPhone');

    try {
      if (await canLaunchUrl(whatsappUrl)) {
        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      } else {
        throw 'No se pudo abrir WhatsApp';
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error al abrir WhatsApp: $e'),
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<List<SupplierModel>>(
        stream: _supplierService.getSuppliers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final suppliers = snapshot.data ?? [];

          if (suppliers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.business_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No hay proveedores registrados',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Presiona el botón + para agregar uno',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: suppliers.length,
            itemBuilder: (context, index) {
              final supplier = suppliers[index];
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.blue[100],
                    child: const Icon(Icons.business, color: Colors.blue),
                  ),
                  title: Text(
                    supplier.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      if (supplier.contactName.isNotEmpty)
                        Text('👤 ${supplier.contactName}'),
                      if (supplier.contactPhone.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text('📞 ${supplier.contactPhone}'),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => _openWhatsApp(
                                supplier.contactPhone,
                                supplier.contactName,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '💬',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Colors.green[700],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (supplier.website.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '🌐 ${supplier.website}',
                          style: const TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 18),
                        color: Colors.blue,
                        tooltip: 'Editar',
                        onPressed: () => _navigateToForm(supplier: supplier),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, size: 18),
                        color: Colors.red,
                        tooltip: 'Eliminar',
                        onPressed: () => _deleteSupplier(supplier),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToForm(),
        tooltip: 'Agregar Proveedor',
        child: const Icon(Icons.add),
      ),
    );
  }
}
