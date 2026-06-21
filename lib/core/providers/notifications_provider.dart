import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_notification.dart';
import '../services/notification_service.dart';
import 'auth_provider.dart';

final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>((ref) async {
  final session = ref.watch(currentSessionProvider);
  if (session == null) return [];
  return NotificationService.getNotifications();
});

final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final notifications = await ref.watch(notificationsProvider.future);
  return notifications.where((n) => !n.isRead).length;
});
