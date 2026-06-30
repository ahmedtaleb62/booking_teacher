import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthState;

import '../core/services/supabase_service.dart';
import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/auth/screens/otp_screen.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/reset_password_screen.dart';
import '../features/shell/main_shell.dart';
import '../features/home/screens/home_screen.dart';
import '../features/teacher_profile/screens/teacher_profile_screen.dart';
import '../features/booking/screens/request_session_screen.dart';
import '../features/booking/screens/request_sent_screen.dart';
import '../features/booking/screens/payment_screen.dart';
import '../features/booking/screens/payment_submitted_screen.dart';
import '../features/booking/screens/session_status_screen.dart';
import '../features/sessions/screens/session_room_screen.dart';
import '../features/sessions/screens/sessions_list_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/profile/screens/profile_screen.dart';
import '../features/courses/screens/course_details_screen.dart';
import '../features/courses/screens/package_details_screen.dart';
import '../features/courses/screens/subscription_screen.dart';
import '../features/courses/screens/subscription_pending_screen.dart';
import '../features/courses/screens/my_courses_screen.dart';
import '../features/courses/screens/lesson_player_screen.dart';
import '../features/payments/screens/payment_history_screen.dart';
import '../features/profile/screens/edit_profile_screen.dart';
import '../features/profile/screens/change_password_screen.dart';
import '../features/profile/screens/my_ratings_screen.dart';

// Teacher app
import '../features/teacher/shell/teacher_shell.dart';
import '../features/teacher/screens/teacher_dashboard_screen.dart';
import '../features/teacher/screens/teacher_requests_screen.dart';
import '../features/teacher/screens/teacher_request_detail_screen.dart';
import '../features/teacher/screens/teacher_session_status_screen.dart';
import '../features/teacher/screens/teacher_sessions_screen.dart';
import '../features/teacher/screens/teacher_earnings_screen.dart';
import '../features/teacher/screens/teacher_profile_screen.dart' show TeacherSelfProfileScreen;
import '../features/teacher/screens/teacher_onboarding_screen.dart';
import '../features/teacher/screens/teacher_availability_screen.dart';
import '../features/teacher/screens/teacher_ratings_screen.dart';
import '../features/shared/screens/help_center_screen.dart';

// Global navigator key — lets code outside the widget tree access the correct Overlay
// (the one inside MaterialApp.router, not above it).
final rootNavigatorKey = GlobalKey<NavigatorState>();

// Notifies GoRouter when Supabase auth state changes so redirect is re-evaluated
class _AuthRefreshNotifier extends ChangeNotifier {
  late final StreamSubscription<AuthState> _sub;
  _AuthRefreshNotifier() {
    _sub = SupabaseService.authStateChanges.listen((_) => notifyListeners());
  }
  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthRefreshNotifier();
  ref.onDispose(notifier.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    refreshListenable: notifier,
    redirect: (context, state) {
      final session = SupabaseService.client.auth.currentSession;
      final isAuth  = session != null;
      final loc     = state.matchedLocation;
      final role    = SupabaseService.client.auth.currentUser
          ?.userMetadata?['role'] as String?;

      if (loc == '/splash') return null;

      // These screens are always public (no auth required)
      const publicPaths = {
        '/login', '/register', '/otp',
        '/forgot-password', '/reset-password',
      };

      if (publicPaths.contains(loc)) {
        // Only redirect authenticated users away from login/register.
        // /otp, /forgot-password, /reset-password must remain accessible even
        // when auth state fires mid-flow (e.g. sendOtp creates a temporary session).
        if (isAuth && (loc == '/login' || loc == '/register')) {
          return role == 'teacher' ? '/teacher/home' : '/home';
        }
        return null;
      }

      // Protected route — must be authenticated
      if (!isAuth) return '/login';

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/otp',
        builder: (_, state) {
          final args = state.extra as OtpArgs?;
          if (args == null) return const RegisterScreen();
          return OtpScreen(args: args);
        },
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (_, __) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          final phone = extra['phone'] as String? ?? '';
          return ResetPasswordScreen(phone: phone);
        },
      ),

      // ── Student shell (IndexedStack keeps tabs alive) ────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (_, __, navigationShell) => MainShell(child: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/home',
              pageBuilder: (_, __) => const NoTransitionPage(child: HomeScreen()),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/sessions',
              pageBuilder: (_, __) => const NoTransitionPage(child: SessionsListScreen()),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/my-courses',
              pageBuilder: (_, __) => const NoTransitionPage(child: MyCoursesScreen()),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/profile',
              pageBuilder: (_, __) => const NoTransitionPage(child: ProfileScreen()),
            ),
          ]),
        ],
      ),

      GoRoute(
        path: '/tutor/:id',
        builder: (_, state) => TeacherProfileScreen(teacherId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/request-session/:teacherId',
        builder: (_, state) => RequestSessionScreen(teacherId: state.pathParameters['teacherId']!),
      ),
      GoRoute(
        path: '/request-sent/:sessionId',
        builder: (_, state) => RequestSentScreen(sessionId: state.pathParameters['sessionId']!),
      ),
      GoRoute(
        path: '/payment/:sessionId',
        builder: (_, state) => PaymentScreen(sessionId: state.pathParameters['sessionId']!),
      ),
      GoRoute(
        path: '/payment-submitted/:sessionId',
        builder: (_, state) => PaymentSubmittedScreen(sessionId: state.pathParameters['sessionId']!),
      ),
      GoRoute(
        path: '/session/:id',
        builder: (_, state) => SessionStatusScreen(sessionId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/live/:id',
        builder: (_, state) => SessionRoomScreen(sessionId: state.pathParameters['id']!, isTeacher: false),
      ),
      GoRoute(
        path: '/session-history/:id',
        builder: (_, state) => SessionRoomScreen(
          sessionId: state.pathParameters['id']!,
          isTeacher: false,
          readOnly: true,
        ),
      ),
      // ── Courses & Packages ───────────────────────────────────────────────────
      GoRoute(
        path: '/notifications',
        builder: (_, __) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/payments',
        builder: (_, __) => const PaymentHistoryScreen(),
      ),
      GoRoute(
        path: '/edit-profile',
        builder: (_, __) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/change-password',
        builder: (_, __) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/my-ratings',
        builder: (_, __) => const MyRatingsScreen(),
      ),
      GoRoute(
        path: '/course/:id',
        builder: (_, state) => CourseDetailsScreen(courseId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/package/:id',
        builder: (_, state) => PackageDetailsScreen(packageId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/subscribe/:type/:id',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return SubscriptionScreen(
            type: state.pathParameters['type']!,
            itemId: state.pathParameters['id']!,
            priceMonthly: (extra['priceMonthly'] as num?)?.toDouble() ?? (extra['amount'] as num?)?.toDouble() ?? 0,
            priceYearly: (extra['priceYearly'] as num?)?.toDouble(),
            title: extra['title'] as String? ?? '',
          );
        },
      ),
      GoRoute(
        path: '/subscription-pending/:id',
        builder: (_, state) =>
            SubscriptionPendingScreen(subscriptionId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/lesson/:id',
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return LessonPlayerScreen(
            lessonId: state.pathParameters['id']!,
            courseId: extra['courseId'] as String?,
            title: extra['title'] as String?,
            videoUrl: extra['videoUrl'] as String?,
            subscriptionId: extra['subscriptionId'] as String?,
            lessonType: extra['lessonType'] as String? ?? 'video',
            quizData: (extra['quizData'] as List?)
                ?.map((q) => Map<String, dynamic>.from(q as Map))
                .toList(),
          );
        },
      ),

      // ── Teacher shell (IndexedStack keeps tabs alive) ────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (_, __, navigationShell) => TeacherShell(child: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/teacher/home',
              pageBuilder: (_, __) => const NoTransitionPage(child: TeacherDashboardScreen()),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/teacher/requests',
              pageBuilder: (_, __) => const NoTransitionPage(child: TeacherRequestsScreen()),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/teacher/sessions',
              pageBuilder: (_, __) => const NoTransitionPage(child: TeacherSessionsScreen()),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/teacher/notifications',
              pageBuilder: (_, __) => const NoTransitionPage(child: NotificationsScreen(isTeacher: true)),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/teacher/profile',
              pageBuilder: (_, __) => const NoTransitionPage(child: TeacherSelfProfileScreen()),
            ),
          ]),
        ],
      ),

      GoRoute(
        path: '/teacher/request/:id',
        builder: (_, state) => TeacherRequestDetailScreen(requestId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/teacher/session/:id',
        builder: (_, state) => TeacherSessionStatusScreen(sessionId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/teacher/live/:id',
        builder: (_, state) => SessionRoomScreen(sessionId: state.pathParameters['id']!, isTeacher: true),
      ),
      GoRoute(
        path: '/teacher/session-history/:id',
        builder: (_, state) => SessionRoomScreen(
          sessionId: state.pathParameters['id']!,
          isTeacher: true,
          readOnly: true,
        ),
      ),
      GoRoute(
        path: '/teacher/earnings',
        builder: (_, __) => const TeacherEarningsScreen(),
      ),
      GoRoute(
        path: '/teacher/onboarding',
        builder: (_, __) => const TeacherOnboardingScreen(),
      ),
      GoRoute(
        path: '/teacher/availability',
        builder: (_, __) => const TeacherAvailabilityScreen(),
      ),
      GoRoute(
        path: '/teacher/ratings',
        builder: (_, __) => const TeacherRatingsScreen(),
      ),
      GoRoute(
        path: '/help-center',
        builder: (_, state) {
          final tab = state.uri.queryParameters['tab'];
          return HelpCenterScreen(initialTab: tab);
        },
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('الصفحة غير موجودة: ${state.error}')),
    ),
  );
});
