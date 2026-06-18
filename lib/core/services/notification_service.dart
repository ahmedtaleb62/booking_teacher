import '../models/app_notification.dart';
import 'supabase_service.dart';

class NotificationService {
  static final _db = SupabaseService.client;

  static Future<List<AppNotification>> getNotifications() async {
    final uid = SupabaseService.userId;
    if (uid == null) return [];

    final data = await _db
        .from('notifications')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(50);

    return (data as List)
        .map((n) => AppNotification.fromJson(Map<String, dynamic>.from(n as Map)))
        .toList();
  }

  static Future<void> markAsRead(String notificationId) async {
    await _db
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId);
  }

  static Future<void> markAllRead() async {
    final uid = SupabaseService.userId;
    if (uid == null) return;
    await _db
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', uid)
        .eq('is_read', false);
  }

  static Future<int> getUnreadCount() async {
    final uid = SupabaseService.userId;
    if (uid == null) return 0;
    final res = await _db
        .from('notifications')
        .select()
        .eq('user_id', uid)
        .eq('is_read', false);
    return (res as List).length;
  }
}
