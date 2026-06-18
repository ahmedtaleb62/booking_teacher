import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';

class TeacherShell extends StatelessWidget {
  final Widget child;
  const TeacherShell({super.key, required this.child});

  int _selectedIndex(BuildContext context) {
    final loc = GoRouterState.of(context).uri.toString();
    if (loc.startsWith('/teacher/requests')) return 1;
    if (loc.startsWith('/teacher/sessions'))  return 2;
    if (loc.startsWith('/teacher/earnings'))  return 3;
    if (loc.startsWith('/teacher/profile'))   return 4;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0: context.go('/teacher/home');      break;
      case 1: context.go('/teacher/requests');  break;
      case 2: context.go('/teacher/sessions');  break;
      case 3: context.go('/teacher/earnings');  break;
      case 4: context.go('/teacher/profile');   break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: TeacherBottomNav(
        currentIndex: _selectedIndex(context),
        onTap: (i) => _onTap(context, i),
        requestsBadge: 3,
      ),
    );
  }
}

class TeacherBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int requestsBadge;

  const TeacherBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.requestsBadge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              _TNavItem(icon: Icons.home_rounded,           label: 'الرئيسية', selected: currentIndex == 0, onTap: () => onTap(0)),
              _TNavItem(icon: Icons.task_alt_rounded,       label: 'الطلبات',  selected: currentIndex == 1, badge: requestsBadge, onTap: () => onTap(1)),
              _TNavItem(icon: Icons.calendar_month_rounded, label: 'الجلسات',  selected: currentIndex == 2, onTap: () => onTap(2)),
              _TNavItem(icon: Icons.account_balance_wallet_rounded, label: 'الأرباح', selected: currentIndex == 3, onTap: () => onTap(3)),
              _TNavItem(icon: Icons.person_rounded,         label: 'حسابي',   selected: currentIndex == 4, onTap: () => onTap(4)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  const _TNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    this.badge = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textHint;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color, size: 23),
                if (badge > 0)
                  Positioned(
                    top: -4, right: -6,
                    child: Container(
                      width: 16, height: 16,
                      decoration: const BoxDecoration(
                        color: Color(0xFFF2994A), shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        badge > 9 ? '9+' : '$badge',
                        style: const TextStyle(
                          color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
