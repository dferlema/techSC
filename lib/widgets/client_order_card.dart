import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../theme/app_colors.dart';

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
    final originalQuote = data['originalQuote'] as Map<String, dynamic>?;

    // Robustly get items
    final items =
        (data['items'] as List<dynamic>?) ??
        (originalQuote?['items'] as List<dynamic>?) ??
        [];

    // Robustly get total
    double total = 0.0;
    double subtotal = 0.0;
    final discountPercentage =
        (data['discountPercentage'] as num?)?.toDouble() ??
        (originalQuote?['discountPercentage'] as num?)?.toDouble() ??
        0.0;

    for (var item in items) {
      final price = (item['price'] as num?)?.toDouble() ?? 0.0;
      final qty = (item['quantity'] as num?)?.toInt() ?? 1;
      subtotal += price * qty;
    }

    final discountAmount = subtotal * (discountPercentage / 100);
    final taxableAmount = subtotal - discountAmount;

    if (data['total'] != null && discountPercentage == 0) {
      total = (data['total'] as num).toDouble();
    } else {
      total = taxableAmount;
      // Apply tax if applicable in originalQuote
      if (originalQuote?['applyTax'] == true) {
        final taxRate = (originalQuote?['taxRate'] as num?)?.toDouble() ?? 0.15;
        total += taxableAmount * taxRate;
      }
    }

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
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
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
                  if (discountPercentage > 0) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Descuento (${discountPercentage.toStringAsFixed(0)}%)',
                          style: TextStyle(
                            color: AppColors.success,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '-\$${discountAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            color: AppColors.success,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
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
                          backgroundColor: AppColors.success,
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
              color: AppColors.backgroundGray,
              borderRadius: BorderRadius.circular(8),
            ),
            child: item['image'] != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      item['image'],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.image,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : Icon(
                    Icons.shopping_bag_outlined,
                    size: 20,
                    color: AppColors.textSecondary,
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
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
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
        return AppColors.warning;
      case 'confirmado':
        return AppColors.primaryBlue;
      case 'entregado':
        return AppColors.success;
      case 'cancelado':
        return AppColors.error;
      default:
        return AppColors.textSecondary;
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
        color = AppColors.warning;
        break;
      case 'confirmado':
        color = AppColors.primaryBlue;
        break;
      case 'entregado':
        color = AppColors.success;
        break;
      case 'cancelado':
        color = AppColors.error;
        break;
      default:
        color = AppColors.textSecondary;
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
