import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/fcm_service.dart';
import 'core/services/supabase_service.dart';
import 'firebase_options.dart';
import 'router/app_router.dart';
import 'shared/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Firebase must init before Supabase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Register background message handler (must be before runApp)
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  await SupabaseService.initialize();
  await FcmService.init();

  runApp(const ProviderScope(child: TeacherBookingApp()));
}

class TeacherBookingApp extends ConsumerStatefulWidget {
  const TeacherBookingApp({super.key});
  @override
  ConsumerState<TeacherBookingApp> createState() => _TeacherBookingAppState();
}

class _TeacherBookingAppState extends ConsumerState<TeacherBookingApp> {
  @override
  void initState() {
    super.initState();
    _setupNotificationNavigation();
  }

  void _setupNotificationNavigation() {
    // App opened from terminated state by tapping a notification
    FcmService.getInitialMessage().then((message) {
      if (message == null) return;
      final route = FcmService.routeFromMessage(message);
      if (route != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(routerProvider).go(route);
        });
      }
    });

    // App in background, user taps notification
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      final route = FcmService.routeFromMessage(message);
      if (route != null) ref.read(routerProvider).go(route);
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'حجز استاذ',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      locale: const Locale('ar'),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
    );
  }
}
