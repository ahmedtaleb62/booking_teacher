import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:teacher_booking/l10n/app_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/app_colors.dart';
import 'core/providers/locale_provider.dart';
import 'core/providers/notifications_provider.dart';
import 'core/providers/sessions_provider.dart';
import 'core/services/fcm_service.dart';
import 'core/services/session_service.dart';
import 'core/services/supabase_service.dart';
import 'features/sessions/screens/video_call_screen.dart';
import 'firebase_options.dart';
import 'router/app_router.dart' show routerProvider, rootNavigatorKey;
import 'shared/theme/app_theme.dart';

// Runs in a separate isolate — must be a top-level function.
// Firebase must be re-initialized here because it's a fresh isolate.
// The system tray already shows the notification; we just ensure Firebase
// is ready so the message isn't si
//lently dropped.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // No UI work here — when the user taps the notification,
  // onMessageOpenedApp fires in the main isolate and handles navigation.
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();


  if (!kIsWeb) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  // Firebase must init before Supabase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Background handler — mobile only (not supported on web)
  if (!kIsWeb) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  }

  await SupabaseService.initialize();
  if (!kIsWeb) await FcmService.init();

  runApp(const ProviderScope(child: TeacherBookingApp()));
}

class TeacherBookingApp extends ConsumerStatefulWidget {
  const TeacherBookingApp({super.key});
  @override
  ConsumerState<TeacherBookingApp> createState() => _TeacherBookingAppState();
}

class _TeacherBookingAppState extends ConsumerState<TeacherBookingApp> {
  OverlayEntry?      _bannerEntry;
  OverlayEntry?      _callEntry;
  RealtimeChannel?   _notifChannel;
  RealtimeChannel?   _sessionsStudentChannel;
  RealtimeChannel?   _sessionsTeacherChannel;
  RealtimeChannel?   _ledgerChannel;
  StreamSubscription? _authSub;

  @override
  void initState() {
    super.initState();
    _setupNotificationNavigation();
    _setupForegroundBanner();
    // Start Realtime listener after first frame so context/overlay are ready
    WidgetsBinding.instance.addPostFrameCallback((_) => _setupRealtimeNotifications());
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _notifChannel?.unsubscribe();
    _sessionsStudentChannel?.unsubscribe();
    _sessionsTeacherChannel?.unsubscribe();
    _ledgerChannel?.unsubscribe();
    super.dispose();
  }

  // ── Supabase Realtime fallback (works even when FCM is unconfigured) ──
  void _setupRealtimeNotifications() {
    // Subscribe now if already logged in
    final uid = SupabaseService.userId;
    if (uid != null) {
      _subscribeToUserNotifications(uid);
      _subscribeToUserSessions(uid);
      FcmService.saveToken(); // Token may not have been saved on first launch
    }

    // Re-subscribe / unsubscribe on auth changes
    _authSub = SupabaseService.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        _subscribeToUserNotifications(session.user.id);
        _subscribeToUserSessions(session.user.id);
        FcmService.saveToken(); // Save token now that userId is available
      } else {
        _notifChannel?.unsubscribe();          _notifChannel = null;
        _sessionsStudentChannel?.unsubscribe(); _sessionsStudentChannel = null;
        _sessionsTeacherChannel?.unsubscribe(); _sessionsTeacherChannel = null;
        _ledgerChannel?.unsubscribe();          _ledgerChannel = null;
        FcmService.removeToken(); // Clean up on logout
      }
    });
  }

  void _subscribeToUserNotifications(String uid) {
    _notifChannel?.unsubscribe();
    _notifChannel = SupabaseService.client
        .channel('notifications:$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: uid,
          ),
          callback: (payload) {
            if (!mounted) return;
            final row   = payload.newRecord;
            final title = (row['title'] as String?) ?? '';
            final body  = (row['body']  as String?) ?? '';
            ref.invalidate(notificationsProvider);
            ref.invalidate(unreadCountProvider);
            _showBanner(title, body);
            // Persistent system notification (stays in shade until user dismisses)
            FcmService.showNotification(title, body);
          },
        )
        .subscribe();
  }

  void _setupNotificationNavigation() {
    FcmService.getInitialMessage().then((message) {
      if (message == null) return;
      final route = FcmService.routeFromMessage(message);
      if (route != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(routerProvider).go(route);
        });
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final route = FcmService.routeFromMessage(message);
      if (route != null) ref.read(routerProvider).go(route);
    });
  }

  void _subscribeToUserSessions(String uid) {
    _sessionsStudentChannel?.unsubscribe();
    _sessionsTeacherChannel?.unsubscribe();
    _ledgerChannel?.unsubscribe();

    void invalidateSessions() {
      ref.invalidate(studentSessionsProvider);
      ref.invalidate(teacherSessionsProvider);
      ref.invalidate(teacherDashboardProvider);
      ref.invalidate(teacherPendingRequestsProvider);
      ref.invalidate(teacherInProgressSessionsProvider);
      ref.invalidate(teacherRejectedSessionsProvider);
      ref.invalidate(teacherTodaySessionsProvider);
      ref.invalidate(teacherUpcomingSessionsProvider);
      ref.invalidate(teacherCompletedSessionsProvider);
    }

    // Watch sessions where current user is the STUDENT (state changes, payment, etc.)
    _sessionsStudentChannel = SupabaseService.client
        .channel('global-sessions-student-$uid')
        .onPostgresChanges(
          event:  PostgresChangeEvent.all,
          schema: 'public',
          table:  'sessions',
          filter: PostgresChangeFilter(
            type:   PostgresChangeFilterType.eq,
            column: 'student_id',
            value:  uid,
          ),
          callback: (_) => invalidateSessions(),
        )
        .subscribe();

    // Watch sessions where current user is the TEACHER (new requests + state changes)
    _sessionsTeacherChannel = SupabaseService.client
        .channel('global-sessions-teacher-$uid')
        .onPostgresChanges(
          event:  PostgresChangeEvent.all,
          schema: 'public',
          table:  'sessions',
          filter: PostgresChangeFilter(
            type:   PostgresChangeFilterType.eq,
            column: 'teacher_id',
            value:  uid,
          ),
          callback: (_) => invalidateSessions(),
        )
        .subscribe();

    // Watch ledger_entries for earnings updates
    _ledgerChannel = SupabaseService.client
        .channel('global-ledger-$uid')
        .onPostgresChanges(
          event:  PostgresChangeEvent.all,
          schema: 'public',
          table:  'ledger_entries',
          filter: PostgresChangeFilter(
            type:   PostgresChangeFilterType.eq,
            column: 'teacher_id',
            value:  uid,
          ),
          callback: (_) {
            ref.invalidate(teacherEarningsProvider);
            ref.invalidate(teacherDashboardProvider);
          },
        )
        .subscribe();
  }

  void _setupForegroundBanner() {
    if (kIsWeb) return;
    FirebaseMessaging.onMessage.listen((message) {
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadCountProvider);

      final type      = message.data['type']       as String?;
      final sessionId = message.data['session_id'] as String?;
      final role      = message.data['role']        as String?;

      if (type == 'VIDEO_CALL' && sessionId != null) {
        _showIncomingCallOverlay(sessionId, role);
      }
    });
  }

  void _showIncomingCallOverlay(String sessionId, String? role) {
    _callEntry?.remove();
    final overlay = rootNavigatorKey.currentState?.overlay;
    if (overlay == null) return;

    _callEntry = OverlayEntry(builder: (_) => _IncomingCallOverlay(
      onAccept: () async {
        _callEntry?.remove();
        _callEntry = null;
        final route = role == 'teacher'
            ? '/teacher/live/$sessionId'
            : '/live/$sessionId';
        ref.read(routerProvider).go(route);
        // Give the screen time to mount, then join Jitsi directly
        await Future.delayed(const Duration(milliseconds: 600));
        try {
          final session = await SessionService.getSession(sessionId);
          if (session.roomUrl == null) return;
          final uid  = SupabaseService.userId ?? '';
          final name = role == 'teacher' ? session.teacherName : session.studentName;
          await VideoCallService.join(
            sessionId:    sessionId,
            displayName:  name.isNotEmpty ? name : uid,
            languageCode: ref.read(localeProvider).languageCode,
            onTerminated: () =>
                SessionService.clearVideoCall(sessionId).catchError((_) {}),
            onError: (_) {},
          );
        } catch (_) {}
      },
      onReject: () {
        _callEntry?.remove();
        _callEntry = null;
      },
    ));
    overlay.insert(_callEntry!);
  }

  void _showBanner(String title, String body) {
    _bannerEntry?.remove();
    // rootNavigatorKey targets the Overlay inside MaterialApp.router.
    // Overlay.maybeOf(context) would look ABOVE MaterialApp and always return null.
    final overlay = rootNavigatorKey.currentState?.overlay;
    if (overlay == null) return;

    _bannerEntry = OverlayEntry(builder: (_) => _NotifBanner(
      title: title,
      
      body: body,
      onDismiss: () { _bannerEntry?.remove(); _bannerEntry = null; },
    ));
    overlay.insert(_bannerEntry!);
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);
    return MaterialApp.router(
      title: 'Hessati',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }
}

// ── Global incoming video-call overlay ────────────────────────────────────────
class _IncomingCallOverlay extends StatefulWidget {
  final VoidCallback onAccept;
  final VoidCallback onReject;
  const _IncomingCallOverlay({required this.onAccept, required this.onReject});
  @override
  State<_IncomingCallOverlay> createState() => _IncomingCallOverlayState();
}

class _IncomingCallOverlayState extends State<_IncomingCallOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;
  Timer? _autoReject;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _slide = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
    _autoReject = Timer(const Duration(seconds: 40), widget.onReject);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _autoReject?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top + 8;
    return Positioned(
      top: top, left: 16, right: 16,
      child: SlideTransition(
        position: _slide,
        child: Material(
          elevation: 12,
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.videocam_rounded, color: AppColors.primary, size: 26),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('مكالمة فيديو واردة 📹',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                          color: Colors.black87)),
                  Text('اضغط قبول للانضمام',
                      style: TextStyle(fontSize: 12, color: Colors.black45)),
                ]),
              ),
              TextButton(
                onPressed: widget.onReject,
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('رفض'),
              ),
              const SizedBox(width: 4),
              ElevatedButton(
                onPressed: widget.onAccept,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('قبول'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _NotifBanner extends StatefulWidget {
  final String title;
  final String body;
  final VoidCallback onDismiss;
  const _NotifBanner({required this.title, required this.body, required this.onDismiss});
  @override
  State<_NotifBanner> createState() => _NotifBannerState();
}

class _NotifBannerState extends State<_NotifBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    _slide = Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
    Future.delayed(const Duration(seconds: 8), _dismiss);
  }

  void _dismiss() async {
    if (!mounted) return;
    await _ctrl.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top + 8;
    return Positioned(
      top: top, left: 16, right: 16,
      child: SlideTransition(
        position: _slide,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(16),
          color: AppColors.primaryDark,
          child: InkWell(
            onTap: _dismiss,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    alignment: Alignment.center,
                    child: const Text('🔔', style: TextStyle(fontSize: 18)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(widget.title,
                          style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                        if (widget.body.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(widget.body,
                            maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12, color: Color(0xFFCFE6EA), height: 1.4)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
