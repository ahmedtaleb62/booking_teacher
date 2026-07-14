import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers/courses_provider.dart';
import '../../core/providers/notifications_provider.dart';
import '../../core/providers/sessions_provider.dart';
import '../../shared/widgets/bottom_nav.dart';

class MainShell extends ConsumerWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  int _selectedIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    if (location.startsWith('/sessions'))   return 1;
    if (location.startsWith('/my-courses')) return 2;
    if (location.startsWith('/profile'))    return 3;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0: context.go('/home');        break;
      case 1: context.go('/sessions');    break;
      case 2: context.go('/my-courses');  break;
      case 3: context.go('/profile');     break;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep all realtime subscriptions alive regardless of which tab is active.
    ref.watch(sessionsRealtimeProvider);
    ref.watch(subscriptionsRealtimeProvider);
    ref.watch(notificationsRealtimeProvider);
    return Scaffold(
      body: child,
      bottomNavigationBar: AppBottomNav(
        currentIndex: _selectedIndex(context),
        onTap: (i) => _onTap(context, i),
      ),
    );
  }
}
