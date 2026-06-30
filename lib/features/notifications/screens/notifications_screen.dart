import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/l10n_extension.dart';
import '../../../core/models/app_notification.dart';
import '../../../core/providers/notifications_provider.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/supabase_service.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  final bool isTeacher;
  const NotificationsScreen({super.key, this.isTeacher = false});
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
          callback: (_) => ref.invalidate(notificationsProvider),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  String _timeAgo(DateTime dt) {
    final l = context.l10n;
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return l.timeNow;
    if (diff.inMinutes < 60) return l.timeMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24)   return l.timeHoursAgo(diff.inHours);
    if (diff.inDays < 7)     return l.timeDaysAgo(diff.inDays);
    return l.timeWeeksAgo((diff.inDays / 7).floor());
  }

  Future<void> _markAsRead(AppNotification n) async {
    if (n.isRead) return;
    await NotificationService.markAsRead(n.id);
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadCountProvider);
  }

  void _onNotificationTap(AppNotification n) {
    _markAsRead(n);

    if (n.type == 'SUB_PENDING' || n.type == 'SUB_ACTIVE' || n.type == 'SUB_REJECTED') {
      if (n.subscriptionId != null) {
        context.push('/subscription-pending/${n.subscriptionId}');
      }
      return;
    }

    if (n.sessionId == null) return;

    if (widget.isTeacher) {
      final isNewRequest = n.type == 'SESSION_REQUESTED' || n.type == 'session_requested';
      if (isNewRequest) {
        context.push('/teacher/request/${n.sessionId}');
      } else {
        context.push('/teacher/session/${n.sessionId}');
      }
    } else {
      context.push('/session/${n.sessionId}');
    }
  }

  Future<void> _markAllRead() async {
    await NotificationService.markAllRead();
    ref.invalidate(notificationsProvider);
    ref.invalidate(unreadCountProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final async = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: async.whenData((list) {
          final unread = list.where((n) => !n.isRead).length;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(l.notifTitle,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1),
              ),
              if (unread > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
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
        }).value ?? Text(l.notifTitle),
        actions: [
          async.whenData((list) {
            final unread = list.where((n) => !n.isRead).length;
            if (unread == 0) return const SizedBox.shrink();
            return TextButton(
              onPressed: _markAllRead,
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10)),
              child: Text(l.notifMarkAll,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
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
              Text(l.notifLoadError,
                style: const TextStyle(fontSize: 15, color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => ref.invalidate(notificationsProvider),
                child: Text(l.commonRetry, style: const TextStyle(color: AppColors.primary)),
              ),
            ],
          ),
        ),
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.notifications_none_rounded, size: 54, color: AppColors.textHint),
                  const SizedBox(height: 12),
                  Text(l.notifEmpty,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
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
                  onTap: () => _onNotificationTap(n),
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
      case 'session_approved':
      case 'TEACHER_APPROVED':
      case 'payment_confirmed':
      case 'PAYMENT_CONFIRMED':
      case 'SESSION_CONFIRMED':
      case 'teacher_approved':
      case 'SUB_ACTIVE':
      case 'NEW_COURSE':
      case 'NEW_PACKAGE':
      case 'NEW_TEACHER':        return AppColors.statusConfirmedBg;
      case 'session_rejected':
      case 'TEACHER_REJECTED':
      case 'teacher_rejected':
      case 'teacher_revoked':
      case 'session_cancelled':
      case 'payment_rejected':
      case 'SUB_REJECTED':       return AppColors.statusRejectedBg;
      case 'session_started':
      case 'SESSION_STARTING':   return AppColors.statusActiveBg;
      case 'session_completed':  return AppColors.statusConfirmedBg;
      case 'SUB_PENDING':        return AppColors.accentLight;
      default:                   return AppColors.accentLight;
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
                        child: Text(notification.localizedTitle(context.l10n),
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
                  Text(notification.localizedBody(context.l10n),
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
