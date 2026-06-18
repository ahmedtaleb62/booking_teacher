import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/sessions_provider.dart';
import '../../../core/services/supabase_service.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final sessionsAsync = ref.watch(studentSessionsProvider);

    final name = profileAsync.when(
      data: (p) => p?['full_name'] as String? ?? 'مستخدم',
      loading: () => '...',
      error: (_, __) => 'مستخدم',
    );
    final email = SupabaseService.client.auth.currentUser?.email ?? '';
    final initial = name.isNotEmpty && name != '...' ? name[0] : 'م';

    int totalSessions = 0, completedSessions = 0;
    double totalAmount = 0;
    sessionsAsync.whenData((sessions) {
      totalSessions = sessions.length;
      completedSessions = sessions.where((s) => s.state.name == 'completed').length;
      totalAmount = sessions.fold(0.0, (sum, s) => sum + s.amount);
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('حسابي'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 100),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Container(
                    width: 72, height: 72,
                    decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(initial,
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                  const SizedBox(height: 12),
                  Text(name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(email,
                    style: const TextStyle(fontSize: 13, color: AppColors.textHint)),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatItem(value: '$totalSessions', label: 'إجمالي الجلسات'),
                      Container(width: 1, height: 32, color: AppColors.border),
                      _StatItem(value: '$completedSessions', label: 'مكتملة'),
                      Container(width: 1, height: 32, color: AppColors.border),
                      _StatItem(value: '${totalAmount.toInt()} أوقية', label: 'إجمالي الدفع'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _SectionCard(
              title: 'الحساب',
              items: [
                _MenuItem(icon: Icons.person_outline_rounded, label: 'تعديل الملف الشخصي', onTap: () {}),
                _MenuItem(icon: Icons.lock_outline_rounded, label: 'تغيير كلمة المرور', onTap: () {}),
                _MenuItem(icon: Icons.notifications_outlined, label: 'إعدادات الإشعارات', onTap: () {}),
              ],
            ),
            const SizedBox(height: 14),

            _SectionCard(
              title: 'الجلسات والمدفوعات',
              items: [
                _MenuItem(icon: Icons.history_rounded, label: 'سجل الجلسات', onTap: () => context.go('/sessions')),
                _MenuItem(icon: Icons.receipt_long_outlined, label: 'سجل المدفوعات', onTap: () {}),
                _MenuItem(icon: Icons.star_outline_rounded, label: 'تقييماتي', onTap: () {}),
              ],
            ),
            const SizedBox(height: 14),

            _SectionCard(
              title: 'الدعم',
              items: [
                _MenuItem(icon: Icons.help_outline_rounded, label: 'مركز المساعدة', onTap: () {}),
                _MenuItem(icon: Icons.policy_outlined, label: 'سياسة الخصوصية', onTap: () {}),
                _MenuItem(icon: Icons.gavel_rounded, label: 'شروط الاستخدام', onTap: () {}),
              ],
            ),
            const SizedBox(height: 14),

            GestureDetector(
              onTap: () => _showLogoutDialog(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.statusRejectedBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.statusRejected.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.logout_rounded, color: AppColors.error, size: 18),
                    SizedBox(width: 8),
                    Text('تسجيل الخروج',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.error)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('حجز استاذ · الإصدار 1.0.0',
              style: TextStyle(fontSize: 11, color: AppColors.textHint)),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await SupabaseService.client.auth.signOut();
              if (context.mounted) context.go('/login');
            },
            child: const Text('خروج', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<_MenuItem> items;
  const _SectionCard({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, right: 4),
          child: Text(title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                color: AppColors.textHint, letterSpacing: 0.5)),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: items.asMap().entries.map((e) {
              final isLast = e.key == items.length - 1;
              return Column(
                children: [
                  e.value,
                  if (!isLast) const Divider(height: 1, indent: 52),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuItem({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 17, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
            ),
            const Icon(Icons.chevron_left_rounded, size: 18, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}
