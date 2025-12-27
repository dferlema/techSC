import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/notification_model.dart';
import '../models/reservation_model.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'reservation_detail_page.dart';
import 'order_detail_page.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({Key? key}) : super(key: key);

  Future<void> _handleNotificationTap(
    BuildContext context,
    NotificationModel notification,
  ) async {
    try {
      if (notification.type == 'reservation') {
        // Fetch reservation and navigate
        final doc = await FirebaseFirestore.instance
            .collection('reservations')
            .doc(notification.relatedId)
            .get();

        if (!doc.exists) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Reserva no encontrada')),
            );
          }
          return;
        }

        final reservation = ReservationModel.fromFirestore(doc);
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  ReservationDetailPage(reservation: reservation),
            ),
          );
        }
      } else if (notification.type == 'order') {
        // Navigate to order detail
        if (context.mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  OrderDetailPage(orderId: notification.relatedId),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al abrir: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationService = NotificationService();

    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: StreamBuilder<List<NotificationModel>>(
        stream: notificationService.getUserNotifications(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No tienes notificaciones',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final notifications = snapshot.data!;

          return ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (ctx, i) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return ListTile(
                tileColor: notification.isRead
                    ? Colors.transparent
                    : AppColors.primaryBlue.withOpacity(0.05),
                leading: CircleAvatar(
                  backgroundColor: _getIconColor(notification.type),
                  child: Icon(_getIcon(notification.type), color: Colors.white),
                ),
                title: Text(
                  notification.title,
                  style: TextStyle(
                    fontWeight: notification.isRead
                        ? FontWeight.normal
                        : FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(notification.body),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat(
                        'dd/MM/yyyy HH:mm',
                      ).format(notification.createdAt),
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
                onTap: () {
                  // Mark as read
                  if (!notification.isRead) {
                    notificationService.markAsRead(notification.id);
                  }

                  // Navigate to detail
                  _handleNotificationTap(context, notification);
                },
              );
            },
          );
        },
      ),
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'order':
        return Icons.shopping_bag;
      case 'reservation':
        return Icons.calendar_today;
      case 'comment':
        return Icons.comment;
      case 'authorization':
        return Icons.security;
      default:
        return Icons.notifications;
    }
  }

  Color _getIconColor(String type) {
    switch (type) {
      case 'order':
        return Colors.blue;
      case 'reservation':
        return Colors.orange;
      case 'comment':
        return Colors.green;
      case 'authorization':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}
