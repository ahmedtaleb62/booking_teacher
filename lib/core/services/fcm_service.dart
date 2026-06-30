import 'dart:async';
import 'dart:io' show Platform;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'supabase_service.dart';

class FcmService {
  static final _messaging = FirebaseMessaging.instance;
  static final _localNotifs = FlutterLocalNotificationsPlugin();
  static StreamSubscription<String>? _tokenRefreshSub;

  static const _channelId   = 'hajez_ustad_channel';
  static const _channelName = 'إشعارات حجز استاذ';

  static Future<void> init() async {
    if (kIsWeb) return;

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

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true, badge: true, sound: true,
    );

    // Request permission automatically — essential so FCM token can be obtained.
    // On Android ≤12 this is a no-op; on Android 13+ and iOS it shows the dialog.
    await _messaging.requestPermission(
      alert: true, badge: true, sound: true, provisional: false,
    );

    // Foreground: show system notification so it stays in the notification shade.
    // Background/terminated: Android auto-shows from FCM payload — no code needed.
    FirebaseMessaging.onMessage.listen(_showLocalNotification);
  }

  static Future<void> requestPermission() async {
    await _messaging.requestPermission(
      alert: true, badge: true, sound: true, provisional: false,
    );
  }

  /// Returns true if notification permission is already granted.
  static Future<bool> getPermissionStatus() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
           settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Save device FCM token to Supabase after login
  static Future<void> saveToken() async {
    if (kIsWeb) return;
    final uid = SupabaseService.userId;
    if (uid == null) return;
    try {
      // Ensure permission is granted before requesting token
      final settings = await _messaging.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        await _messaging.requestPermission(alert: true, badge: true, sound: true);
      }
      final token = await _messaging.getToken();
      if (token == null) {
        debugPrint('[FCM] getToken() returned null — permission denied?');
        return;
      }
      await _upsertToken(uid, token);

      // Refresh token when FCM rotates it — cancel previous sub to avoid leak
      _tokenRefreshSub?.cancel();
      _tokenRefreshSub = _messaging.onTokenRefresh.listen((t) => _upsertToken(uid, t));
    } catch (e) {
      debugPrint('[FCM] saveToken error: $e');
    }
  }

  /// Remove token from Supabase on logout
  static Future<void> removeToken() async {
    _tokenRefreshSub?.cancel();
    _tokenRefreshSub = null;
    final uid = SupabaseService.userId;
    if (uid == null) return;
    try {
      await SupabaseService.client
          .from('device_tokens')
          .delete()
          .eq('user_id', uid);
      await _messaging.deleteToken();
    } catch (e) {
      debugPrint('[FCM] removeToken error: $e');
    }
  }

  /// Returns the message that launched the app from terminated state
  static Future<RemoteMessage?> getInitialMessage() {
    return _messaging.getInitialMessage();
  }

  /// Extract the deep-link route from FCM data payload
  static String? routeFromMessage(RemoteMessage message) {
    final type      = message.data['type']       as String?;
    final sessionId = message.data['session_id'] as String?;
    final role      = message.data['role']        as String?; // 'teacher' | 'student'

    // Subscription notifications → courses screen
    if (type != null && type.startsWith('SUB_')) return '/my-courses';

    // Session request → teacher request detail
    if (type == 'SESSION_REQUESTED' || type == 'TEACHER_REQUEST') {
      return sessionId != null ? '/teacher/request/$sessionId' : null;
    }

    // Live session / video call
    if (type == 'SESSION_MESSAGE' || type == 'VIDEO_CALL') {
      if (sessionId == null) return null;
      return role == 'teacher' ? '/teacher/live/$sessionId' : '/live/$sessionId';
    }

    // All other session notifications — route by role
    if (sessionId != null && sessionId.isNotEmpty) {
      return role == 'teacher'
          ? '/teacher/session/$sessionId'
          : '/session/$sessionId';
    }

    return null;
  }

  // ── Private helpers ─────────────────────────────────────────

  /// Show a persistent system notification (stays in the notification shade).
  /// Called from Realtime callback so it works even without FCM delivery.
  static Future<void> showNotification(String title, String body) async {
    if (kIsWeb) return;
    await _localNotifs.show(
      title.hashCode ^ body.hashCode,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId, _channelName,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_notification',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true, presentBadge: true, presentSound: true,
        ),
      ),
    );
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;
    await showNotification(n.title ?? '', n.body ?? '');
  }

  static Future<void> _upsertToken(String uid, String token) async {
    if (kIsWeb) return;
    final platform = Platform.isAndroid ? 'android' : 'ios';
    // Remove this token from any OTHER user (same device, account switch).
    await SupabaseService.client
        .from('device_tokens')
        .delete()
        .eq('token', token)
        .neq('user_id', uid);
    // Remove old tokens for this user+platform.
    await SupabaseService.client
        .from('device_tokens')
        .delete()
        .eq('user_id', uid)
        .eq('platform', platform);
    await SupabaseService.client.from('device_tokens').insert({
      'user_id':  uid,
      'token':    token,
      'platform': platform,
    });
    debugPrint('[FCM] Token saved: ...${token.length > 8 ? token.substring(token.length - 8) : token}');
  }

}
