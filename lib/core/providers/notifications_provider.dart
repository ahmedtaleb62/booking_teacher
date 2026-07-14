import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/app_notification.dart';
import '../services/notification_service.dart';
import '../services/supabase_service.dart';
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

// ── Notifications realtime ────────────────────────────────────────────────────
// Watches the notifications table for the current user and invalidates
// notificationsProvider (which unreadCountProvider derives from) on any INSERT.
// Anchor this in both MainShell and TeacherShell to keep the badge live.
final notificationsRealtimeProvider = Provider.autoDispose<void>((ref) {
  final uid = SupabaseService.userId;
  if (uid == null) return;

  final channel = SupabaseService.client
      .channel('rt-notifications-$uid')
      .onPostgresChanges(
        event:  PostgresChangeEvent.all,
        schema: 'public',
        table:  'notifications',
        filter: PostgresChangeFilter(
          type:   PostgresChangeFilterType.eq,
          column: 'user_id',
          value:  uid,
        ),
        callback: (_) => ref.invalidate(notificationsProvider),
      )
      .subscribe();

  ref.onDispose(() => SupabaseService.client.removeChannel(channel));
});
