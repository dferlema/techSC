import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tscomputer/core/models/notification_model.dart';
import 'package:tscomputer/core/services/notification_service.dart';

/// Provider for NotificationService singleton
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// StreamProvider for current user's notifications
final notificationsProvider = StreamProvider<List<NotificationModel>>((ref) {
  final notificationService = ref.watch(notificationServiceProvider);
  return notificationService.getUserNotifications().handleError(
    (error) => debugPrint('Stream error [notifications]: $error'),
  );
});

/// StreamProvider for unread notifications count
final unreadNotificationsCountProvider = StreamProvider<int>((ref) {
  final notificationService = ref.watch(notificationServiceProvider);
  return notificationService.getUnreadCount().handleError(
    (error) => debugPrint('Stream error [unreadNotificationsCount]: $error'),
  );
});
