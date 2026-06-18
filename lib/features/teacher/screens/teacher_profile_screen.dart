import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';

class TeacherSelfProfileScreen extends StatelessWidget {
  const TeacherSelfProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListView(
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top + 8),
          _ProfileHeader(),
          const SizedBox(height: 20),
          _StatsRow(),
          const SizedBox(height: 24),
          _MenuSection(title: 'الحساب والملف الشخصي', items: [
            _MenuItem(icon: Icons.person_outline_rounded,  label: 'تعديل الملف الشخصي', onTap: () {}),
            _MenuItem(icon: Icons.subject_rounded,         label: 'المواد والتخصصات',   onTap: () {}),
            _MenuItem(icon: Icons.schedule_rounded,        label: 'إدارة الأوقات المتاحة', onTap: () {}),
            _MenuItem(icon: Icons.star_outline_rounded,    label: 'التقييمات',           onTap: () {}),
          ]),
          const SizedBox(height: 16),
          _MenuSection(title: 'الأرباح والمدفوعات', items: [
            _MenuItem(icon: Icons.account_balance_wallet_outlined, label: 'بيانات السحب (بنكيلي)', onTap: () {}),
            _MenuItem(icon: Icons.receipt_long_outlined,           label: 'سجل الأرباح',            onTap: () {}),
          ]),
          const SizedBox(height: 16),
          _MenuSection(title: 'الدعم', items: [
            _MenuItem(icon: Icons.help_outline_rounded,   label: 'مركز المساعدة', onTap: () {}),
            _MenuItem(icon: Icons.privacy_tip_outlined,   label: 'سياسة الخصوصية', onTap: () {}),
            _MenuItem(icon: Icons.gavel_rounded,          label: 'شروط الاستخدام', onTap: () {}),
          ]),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: OutlinedButton(
              onPressed: () => context.go('/login'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                side: const BorderSide(color: Color(0xFFF6CFCF)),
                foregroundColor: AppColors.error,
              ),
              child: const Text('تسجيل الخروج', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF1B6B7A), Color(0xFF11313A)]),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Text('م', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 12),
          const Text('د. محمد الأمين', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          const Text('أستاذ رياضيات وفيزياء', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F6EF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.verified_rounded, size: 14, color: Color(0xFF1B9E77)),
                SizedBox(width: 4),
                Text('أستاذ موثّق', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF15805F))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        children: [
          _StatCard(value: '148',  label: 'جلسة مكتملة'),
          const SizedBox(width: 10),
          _StatCard(value: '4.9',  label: 'التقييم'),
          const SizedBox(width: 10),
          _StatCard(value: '98%',  label: 'الحضور'),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 3),
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
          ],
        ),
      ),
    );
  }
}

class _MenuSection extends StatelessWidget {
  final String title;
  final List<_MenuItem> items;
  const _MenuSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textHint)),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: items.asMap().entries.map((e) {
                final isLast = e.key == items.length - 1;
                return _MenuItemTile(item: e.value, showDivider: !isLast);
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuItem({required this.icon, required this.label, required this.onTap});
}

class _MenuItemTile extends StatelessWidget {
  final _MenuItem item;
  final bool showDivider;
  const _MenuItemTile({required this.item, required this.showDivider});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: item.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(item.icon, size: 20, color: AppColors.textSecondary),
                const SizedBox(width: 12),
                Expanded(child: Text(item.label, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary))),
                const Icon(Icons.arrow_back_ios_rounded, size: 14, color: AppColors.textHint),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 48, color: AppColors.border),
      ],
    );
  }
}
