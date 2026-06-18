import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_notification.dart';
import '../services/notification_service.dart';

final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  return NotificationService.getNotifications();
});

final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final notifications = await ref.watch(notificationsProvider.future);
  return notifications.where((n) => !n.isRead).length;
});
