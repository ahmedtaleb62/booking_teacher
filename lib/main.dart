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
import 'core/services/fcm_service.dart';
import 'core/services/supabase_service.dart';
import 'firebase_options.dart';
import 'router/app_router.dart' show routerProvider, rootNavigatorKey;
import 'shared/theme/app_theme.dart';

// Runs in a separate isolate — must be a top-level function.
// Firebase must be re-initialized here because it's a fresh isolate.
// The system tray already shows the notification; we just ensure Firebase
// is ready so the message isn't silently dropped.
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
  OverlayEntry?    _bannerEntry;
  RealtimeChannel? _notifChannel;

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
    _notifChannel?.unsubscribe();
    super.dispose();
  }

  // ── Supabase Realtime fallback (works even when FCM is unconfigured) ──
  void _setupRealtimeNotifications() {
    // Subscribe now if already logged in
    final uid = SupabaseService.userId;
    if (uid != null) {
      _subscribeToUserNotifications(uid);
      FcmService.saveToken(); // Token may not have been saved on first launch
    }

    // Re-subscribe / unsubscribe on auth changes
    SupabaseService.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      if (session != null) {
        _subscribeToUserNotifications(session.user.id);
        FcmService.saveToken(); // Save token now that userId is available
      } else {
        _notifChannel?.unsubscribe();
        _notifChannel = null;
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

  void _setupForegroundBanner() {
    if (kIsWeb) return;
    FirebaseMessaging.onMessage.listen((message) {
      final title = message.notification?.title ?? '';
      final body  = message.notification?.body  ?? '';
      if (title.isEmpty && body.isEmpty) return;

      // Refresh notifications badge
      ref.invalidate(notificationsProvider);
      ref.invalidate(unreadCountProvider);

      // Show in-app banner
      _showBanner(title, body);
    });
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
      title: 'حصتي',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
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
    Future.delayed(const Duration(seconds: 4), _dismiss);
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
