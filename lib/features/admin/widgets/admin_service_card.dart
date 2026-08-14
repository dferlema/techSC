import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:tscomputer/features/reservations/screens/service_form_page.dart';
import 'package:tscomputer/core/theme/app_colors.dart';

class AdminServiceCard extends StatelessWidget {
  final DocumentSnapshot doc;

  const AdminServiceCard({super.key, required this.doc});

  String? _getFirstImage(Map<String, dynamic> data) {
    // Intentar imageUrls (lista)
    final imageUrls = data['imageUrls'];
    if (imageUrls is List && imageUrls.isNotEmpty) {
      final first = imageUrls[0];
      if (first is String && first.isNotEmpty) return first;
    }
    // Intentar imageUrl (string único)
    final imageUrl = data['imageUrl'];
    if (imageUrl is String && imageUrl.isNotEmpty) return imageUrl;
    return null;
  }

  Future<void> _deleteDocument(
    BuildContext context,
    String collection,
    String docId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar'),
        content: const Text('¿Estás seguro de eliminar este servicio?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection(collection)
          .doc(docId)
          .delete();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Servicio eliminado')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
    }
  }

  void _openEdit(BuildContext context) async {
    final data = doc.data() as Map<String, dynamic>;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ServiceFormPage(
          serviceId: doc.id,
          initialData: data,
        ),
      ),
    );
    if (result == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Servicio actualizado')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['title'] ?? '—';
    final price = data['price'];
    final imageUrl = _getFirstImage(data);

    return GestureDetector(
      onTap: () => _openEdit(context),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Imagen del servicio
            SizedBox(
              height: 160,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageUrl != null)
                    CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: AppColors.primaryBlue.withOpacity(0.05),
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (context, url, error) => _buildPlaceholder(),
                    )
                  else
                    _buildPlaceholder(),
                  // Botón eliminar
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: () => _deleteDocument(context, 'services', doc.id),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Info del servicio
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppColors.nearBlack,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (price != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '\$${(price as num).toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Colors.green[700],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.primaryBlue.withOpacity(0.05),
      child: Center(
        child: Icon(
          Icons.build_outlined,
          color: AppColors.primaryBlue,
          size: 40,
        ),
      ),
    );
  }
}
