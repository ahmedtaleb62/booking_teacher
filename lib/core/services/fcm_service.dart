import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'supabase_service.dart';

// Must be top-level — called when app is in background/terminated
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // FCM auto-shows notification in background; this handles data-only messages.
}

class FcmService {
  static final _messaging = FirebaseMessaging.instance;
  static final _localNotifs = FlutterLocalNotificationsPlugin();

  static const _channelId   = 'hajez_ustad_channel';
  static const _channelName = 'إشعارات حجز استاذ';

  static Future<void> init() async {
    // Local notifications — foreground only (FCM handles background automatically)
    await _localNotifs.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    await _localNotifs
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId, _channelName,
            importance: Importance.high,
            enableVibration: true,
            playSound: true,
          ),
        );

    // iOS: show notification while app is in foreground
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true, badge: true, sound: true,
    );

    // Android: show local notification while app is in foreground
    FirebaseMessaging.onMessage.listen(_showLocalNotification);
  }

  static Future<void> requestPermission() async {
    await _messaging.requestPermission(
      alert: true, badge: true, sound: true, provisional: false,
    );
  }

  /// Save device FCM token to Supabase after login
  static Future<void> saveToken() async {
    final uid = SupabaseService.userId;
    if (uid == null) return;
    try {
      final token = await _messaging.getToken();
      if (token == null) return;
      await _upsertToken(uid, token);

      // Refresh token when FCM rotates it
      _messaging.onTokenRefresh.listen((t) => _upsertToken(uid, t));
    } catch (_) {}
  }

  /// Remove token from Supabase on logout
  static Future<void> removeToken() async {
    final uid = SupabaseService.userId;
    if (uid == null) return;
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await SupabaseService.client
            .from('device_tokens')
            .delete()
            .eq('user_id', uid)
            .eq('token', token);
      }
      await _messaging.deleteToken();
    } catch (_) {}
  }

  /// Returns the message that launched the app from terminated state
  static Future<RemoteMessage?> getInitialMessage() {
    return _messaging.getInitialMessage();
  }

  /// Extract the deep-link route from FCM data payload
  static String? routeFromMessage(RemoteMessage message) {
    final sessionId = message.data['session_id'] as String?;
    final type = message.data['type'] as String?;
    if (sessionId == null) return null;
    if (type == 'SESSION_REQUESTED' || type == 'TEACHER_REQUEST') {
      return '/teacher/request/$sessionId';
    }
    return '/session/$sessionId';
  }

  // ── Private helpers ─────────────────────────────────────────

  static Future<void> _upsertToken(String uid, String token) async {
    await SupabaseService.client.from('device_tokens').upsert({
      'user_id':    uid,
      'token':      token,
      'platform':   Platform.isAndroid ? 'android' : 'ios',
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,token');
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;
    await _localNotifs.show(
      message.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId, _channelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true, presentBadge: true, presentSound: true,
        ),
      ),
    );
  }
}
