import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:techsc/features/reservations/screens/service_form_page.dart';

class AdminServiceCard extends StatelessWidget {
  final DocumentSnapshot doc;

  const AdminServiceCard({super.key, required this.doc});

  /// Elimina un documento de Firestore dado su ID y nombre de colección.
  Future<void> _deleteDocument(
    BuildContext context,
    String collection,
    String docId,
  ) async {
    try {
      await FirebaseFirestore.instance
          .collection(collection)
          .doc(docId)
          .delete();
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ Elemento eliminado')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
    }
  }

  /// Construye los botones de Editar y Eliminar (Iconos).
  Widget _buildActionButtons(
    BuildContext context, {
    required String collection,
    required String docId,
    required VoidCallback onEdit,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          onPressed: onEdit,
          icon: const Icon(Icons.edit, color: Colors.blue),
          tooltip: 'Editar',
        ),
        IconButton(
          onPressed: () => _deleteDocument(context, collection, docId),
          icon: const Icon(Icons.delete, color: Colors.red),
          tooltip: 'Eliminar',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data['title'] ?? '—',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 6),
            Text(
              data['description'] ?? '',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              'Desde \$${data['price'] ?? '0'}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _buildActionButtons(
              context,
              collection: 'services',
              docId: doc.id,
              onEdit: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ServiceFormPage(serviceId: doc.id, initialData: data),
                  ),
                );
                if (result == true && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Servicio actualizado')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
