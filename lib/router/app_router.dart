import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/screens/splash_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/shell/main_shell.dart';
import '../features/home/screens/home_screen.dart';
import '../features/teacher_profile/screens/teacher_profile_screen.dart';
import '../features/booking/screens/request_session_screen.dart';
import '../features/booking/screens/request_sent_screen.dart';
import '../features/booking/screens/payment_screen.dart';
import '../features/booking/screens/payment_submitted_screen.dart';
import '../features/booking/screens/session_status_screen.dart';
import '../features/booking/screens/live_session_screen.dart';
import '../features/sessions/screens/sessions_list_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/profile/screens/profile_screen.dart';

// Teacher app
import '../features/teacher/shell/teacher_shell.dart';
import '../features/teacher/screens/teacher_dashboard_screen.dart';
import '../features/teacher/screens/teacher_requests_screen.dart';
import '../features/teacher/screens/teacher_request_detail_screen.dart';
import '../features/teacher/screens/teacher_session_status_screen.dart';
import '../features/teacher/screens/teacher_sessions_screen.dart';
import '../features/teacher/screens/teacher_live_session_screen.dart';
import '../features/teacher/screens/teacher_earnings_screen.dart';
import '../features/teacher/screens/teacher_dispute_screen.dart';
import '../features/teacher/screens/teacher_no_show_screen.dart';
import '../features/teacher/screens/teacher_profile_screen.dart' show TeacherSelfProfileScreen;
import '../features/teacher/screens/teacher_onboarding_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: false,
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
      ShellRoute(
        builder: (_, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (_, __) => const NoTransitionPage(child: HomeScreen()),
          ),
          GoRoute(
            path: '/sessions',
            pageBuilder: (_, __) => const NoTransitionPage(child: SessionsListScreen()),
          ),
          GoRoute(
            path: '/notifications',
            pageBuilder: (_, __) => const NoTransitionPage(child: NotificationsScreen()),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (_, __) => const NoTransitionPage(child: ProfileScreen()),
          ),
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
        builder: (_, state) => LiveSessionScreen(sessionId: state.pathParameters['id']!),
      ),

      // ── Teacher App ─────────────────────────────────────────────────────────
      ShellRoute(
        builder: (_, state, child) => TeacherShell(child: child),
        routes: [
          GoRoute(
            path: '/teacher/home',
            pageBuilder: (_, __) => const NoTransitionPage(child: TeacherDashboardScreen()),
          ),
          GoRoute(
            path: '/teacher/requests',
            pageBuilder: (_, __) => const NoTransitionPage(child: TeacherRequestsScreen()),
          ),
          GoRoute(
            path: '/teacher/sessions',
            pageBuilder: (_, __) => const NoTransitionPage(child: TeacherSessionsScreen()),
          ),
          GoRoute(
            path: '/teacher/earnings',
            pageBuilder: (_, __) => const NoTransitionPage(child: TeacherEarningsScreen()),
          ),
          GoRoute(
            path: '/teacher/profile',
            pageBuilder: (_, __) => const NoTransitionPage(child: TeacherSelfProfileScreen()),
          ),
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
        builder: (_, state) => TeacherLiveSessionScreen(sessionId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/teacher/dispute/:id',
        builder: (_, state) => TeacherDisputeScreen(disputeId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/teacher/no-show/:id',
        builder: (_, state) => TeacherNoShowScreen(sessionId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/teacher/onboarding',
        builder: (_, __) => const TeacherOnboardingScreen(),
      ),
    ],
    errorBuilder: (_, state) => Scaffold(
      body: Center(child: Text('الصفحة غير موجودة: ${state.error}')),
    ),
  );
});
