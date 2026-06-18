import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;
import '../../../core/constants/app_colors.dart';
import '../../../core/models/app_notification.dart';
import '../../../core/providers/notifications_provider.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/supabase_service.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});
  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    final uid = SupabaseService.userId;
    if (uid == null) return;

    _channel = SupabaseService.client
        .channel('notifications-screen-$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: uid,
          ),
          callback: (_) {
            // Refresh provider when any notification row changes
            ref.invalidate(notificationsProvider);
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24)   return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays < 7)     return 'منذ ${diff.inDays} يوم';
    return 'منذ ${(diff.inDays / 7).floor()} أسبوع';
  }

  Future<void> _markAsRead(AppNotification n, int index) async {
    if (n.isRead) return;
    await NotificationService.markAsRead(n.id);
    ref.invalidate(notificationsProvider);
  }

  Future<void> _markAllRead() async {
    await NotificationService.markAllRead();
    ref.invalidate(notificationsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: async.whenData((list) {
          final unread = list.where((n) => !n.isRead).length;
          return Row(
            children: [
              const Text('الإشعارات'),
              if (unread > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('$unread',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          );
        }).value ?? const Text('الإشعارات'),
        actions: [
          async.whenData((list) {
            final unread = list.where((n) => !n.isRead).length;
            if (unread == 0) return const SizedBox.shrink();
            return TextButton(
              onPressed: _markAllRead,
              child: const Text('تحديد الكل كمقروء',
                style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
            );
          }).value ?? const SizedBox.shrink(),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textHint),
              const SizedBox(height: 12),
              const Text('تعذّر تحميل الإشعارات',
                style: TextStyle(fontSize: 15, color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => ref.invalidate(notificationsProvider),
                child: const Text('إعادة المحاولة', style: TextStyle(color: AppColors.primary)),
              ),
            ],
          ),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none_rounded, size: 54, color: AppColors.textHint),
                  SizedBox(height: 12),
                  Text('لا توجد إشعارات',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => ref.invalidate(notificationsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 100),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
              itemBuilder: (_, i) {
                final n = notifications[i];
                return _NotifTile(
                  notification: n,
                  timeStr: _timeAgo(n.createdAt),
                  onTap: () {
                    _markAsRead(n, i);
                    if (n.sessionId != null) context.push('/session/${n.sessionId}');
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  final AppNotification notification;
  final String timeStr;
  final VoidCallback onTap;

  const _NotifTile({required this.notification, required this.timeStr, required this.onTap});

  Color get _iconBg {
    switch (notification.type) {
      case 'TEACHER_APPROVED':
      case 'PAYMENT_CONFIRMED':
      case 'SESSION_CONFIRMED': return AppColors.statusConfirmedBg;
      case 'TEACHER_REJECTED':  return AppColors.statusRejectedBg;
      case 'PAYMENT_REQUIRED':  return AppColors.statusApprovedBg;
      case 'SESSION_STARTING':  return AppColors.statusActiveBg;
      case 'DISPUTE_OPENED':    return AppColors.statusDisputeBg;
      default:                  return AppColors.accentLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        color: notification.isRead ? Colors.transparent : AppColors.accentLight.withValues(alpha: 0.4),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: _iconBg, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(notification.icon, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(notification.title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.w700,
                            color: AppColors.textPrimary,
                          )),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8, height: 8,
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(notification.body,
                    style: const TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary)),
                  const SizedBox(height: 5),
                  Text(timeStr,
                    style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
