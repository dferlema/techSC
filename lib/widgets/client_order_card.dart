import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ClientOrderCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final Function(String) onPay;

  const ClientOrderCard({
    super.key,
    required this.docId,
    required this.data,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    final date = (data['createdAt'] as Timestamp).toDate();
    final formattedDate = DateFormat('dd MMM yyyy, HH:mm').format(date);
    final status = data['status'] ?? 'pendiente';
    final total = (data['total'] ?? 0.0).toDouble();
    final items = (data['items'] as List<dynamic>? ?? []);
    final String? paymentLink = data['paymentLink'];
    final bool showPayButton =
        (status.toLowerCase() == 'pendiente' ||
            status.toLowerCase() == 'confirmado') &&
        paymentLink != null &&
        paymentLink.toString().trim().isNotEmpty;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _getStatusColor(status).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(_getStatusIcon(status), color: _getStatusColor(status)),
          ),
          title: Row(
            children: [
              Text(
                'Pedido #${docId.substring(0, 5).toUpperCase()}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              _StatusBadge(status: status),
            ],
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              formattedDate,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Detalle del Pedido',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  ...items.map((item) => _buildOrderItem(item)),
                  const SizedBox(height: 16),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total a Pagar',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '\$${total.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                  if (showPayButton) ...[
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => onPay(paymentLink),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.payment),
                        label: const Text(
                          'PAGAR AHORA',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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

  Widget _buildOrderItem(dynamic item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8),
            ),
            child: item['image'] != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      item['image'],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.image, size: 20, color: Colors.grey),
                    ),
                  )
                : const Icon(
                    Icons.shopping_bag_outlined,
                    size: 20,
                    color: Colors.grey,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'],
                  style: const TextStyle(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'x${item['quantity']}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              ],
            ),
          ),
          Text(
            '\$${(item['subtotal'] ?? 0).toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pendiente':
        return Colors.orange;
      case 'confirmado':
        return Colors.blue;
      case 'entregado':
        return Colors.green;
      case 'cancelado':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pendiente':
        return Icons.access_time_filled;
      case 'confirmado':
        return Icons.verified;
      case 'entregado':
        return Icons.check_circle;
      case 'cancelado':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status.toLowerCase()) {
      case 'pendiente':
        color = Colors.orange;
        break;
      case 'confirmado':
        color = Colors.blue;
        break;
      case 'entregado':
        color = Colors.green;
        break;
      case 'cancelado':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
