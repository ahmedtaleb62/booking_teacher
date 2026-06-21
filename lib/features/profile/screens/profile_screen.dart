import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/constants/session_states.dart';
import '../../../core/providers/sessions_provider.dart';
import '../../../core/services/supabase_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _loggingOut      = false;
  bool _deletingAccount = false;
  bool _uploadingAvatar = false;

  // ── Avatar upload ─────────────────────────────────────────────

  Future<void> _pickAndUploadAvatar() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;

    setState(() => _uploadingAvatar = true);
    try {
      final uid   = SupabaseService.userId!;
      final bytes = await File(file.path).readAsBytes();
      final ext   = file.path.split('.').last.toLowerCase();
      final contentType = ext == 'png' ? 'image/png' : 'image/jpeg';
      final storagePath = '$uid/avatar.$ext';

      await SupabaseService.client.storage
          .from('avatars')
          .uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );

      final publicUrl = SupabaseService.client.storage
          .from('avatars')
          .getPublicUrl(storagePath);

      await SupabaseService.client
          .from('profiles')
          .update({'avatar_url': publicUrl})
          .eq('id', uid);

      ref.invalidate(currentProfileProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل رفع الصورة: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  // ── Logout ────────────────────────────────────────────────────

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('خروج', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _loggingOut = true);
    try {
      await SupabaseService.client.auth.signOut();
    } finally {
      if (mounted) {
        setState(() => _loggingOut = false);
        context.go('/login');
      }
    }
  }

  // ── Delete account ────────────────────────────────────────────

  Future<void> _deleteAccount() async {
    // Step 1: first confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الحساب', style: TextStyle(color: AppColors.error)),
        content: const Text(
          'هذا الإجراء لا يمكن التراجع عنه.\nسيتم حذف جميع بياناتك بشكل نهائي.',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف',
                style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    // Step 2: type confirmation
    final confirmCtrl = TextEditingController();
    final input = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد الحذف النهائي'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('اكتب "احذف حسابي" للتأكيد:',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            TextField(
              controller: confirmCtrl,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, confirmCtrl.text),
            child: const Text('تأكيد',
                style: TextStyle(
                    color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ).whenComplete(confirmCtrl.dispose);

    if (input != 'احذف حسابي' || !mounted) return;

    setState(() => _deletingAccount = true);
    try {
      await SupabaseService.client.rpc('delete_my_account');
      await SupabaseService.client.auth.signOut();
      if (mounted) context.go('/login');
    } catch (e) {
      if (mounted) {
        setState(() => _deletingAccount = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل حذف الحساب: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync  = ref.watch(currentProfileProvider);
    final sessionsAsync = ref.watch(studentSessionsProvider);

    final name = profileAsync.when(
      data: (p) => p?['full_name'] as String? ?? 'مستخدم',
      loading: () => '...',
      error: (_, __) => 'مستخدم',
    );
    final avatarUrl = profileAsync.when(
      data: (p) => p?['avatar_url'] as String?,
      loading: () => null,
      error: (_, __) => null,
    );
    final email   = SupabaseService.client.auth.currentUser?.email ?? '';
    final initial = name.isNotEmpty && name != '...' ? name[0] : 'م';

    int totalSessions = 0, completedSessions = 0;
    double totalAmount = 0;
    sessionsAsync.whenData((sessions) {
      totalSessions    = sessions.length;
      completedSessions = sessions.where((s) => s.state == SessionState.completed).length;
      totalAmount      = sessions.fold(0.0, (sum, s) => sum + s.amount);
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
            // ── Profile card ──────────────────────────────────
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
                  // Avatar with upload
                  GestureDetector(
                    onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
                    child: Stack(
                      children: [
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            image: avatarUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(avatarUrl),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: _uploadingAvatar
                              ? const CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2)
                              : avatarUrl == null
                                  ? Text(initial,
                                      style: const TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white))
                                  : null,
                        ),
                        Positioned(
                          bottom: 0, right: 0,
                          child: Container(
                            width: 26, height: 26,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.camera_alt_rounded,
                                size: 12, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(name,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(email,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textHint)),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatItem(value: '$totalSessions', label: 'إجمالي الجلسات'),
                      Container(width: 1, height: 32, color: AppColors.border),
                      _StatItem(value: '$completedSessions', label: 'مكتملة'),
                      Container(width: 1, height: 32, color: AppColors.border),
                      _StatItem(
                          value: '${totalAmount.toInt()} أوقية',
                          label: 'إجمالي الدفع'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Account section ───────────────────────────────
            _SectionCard(
              title: 'الحساب',
              items: [
                _MenuItem(
                  icon: Icons.person_outline_rounded,
                  label: 'تعديل الملف الشخصي',
                  onTap: () => context.push('/edit-profile'),
                ),
                _MenuItem(
                  icon: Icons.lock_outline_rounded,
                  label: 'تغيير كلمة المرور',
                  onTap: () => context.push('/change-password'),
                ),
                _MenuItem(
                  icon: Icons.notifications_outlined,
                  label: 'إعدادات الإشعارات',
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Sessions & payments ───────────────────────────
            _SectionCard(
              title: 'الجلسات والمدفوعات',
              items: [
                _MenuItem(
                  icon: Icons.history_rounded,
                  label: 'سجل الجلسات',
                  onTap: () => context.go('/sessions'),
                ),
                _MenuItem(
                  icon: Icons.receipt_long_outlined,
                  label: 'سجل المدفوعات',
                  onTap: () => context.push('/payments'),
                ),
                _MenuItem(
                  icon: Icons.star_outline_rounded,
                  label: 'تقييماتي',
                  onTap: () => context.push('/my-ratings'),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Support ───────────────────────────────────────
            _SectionCard(
              title: 'الدعم',
              items: [
                _MenuItem(icon: Icons.help_outline_rounded,  label: 'مركز المساعدة',   onTap: () {}),
                _MenuItem(icon: Icons.policy_outlined,       label: 'سياسة الخصوصية', onTap: () {}),
                _MenuItem(icon: Icons.gavel_rounded,         label: 'شروط الاستخدام',  onTap: () {}),
              ],
            ),
            const SizedBox(height: 14),

            // ── Logout ────────────────────────────────────────
            GestureDetector(
              onTap: _loggingOut ? null : _logout,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  color: AppColors.statusRejectedBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.statusRejected.withValues(alpha: 0.3)),
                ),
                child: _loggingOut
                    ? const Center(
                        child: SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.error),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded,
                              color: AppColors.error, size: 18),
                          SizedBox(width: 8),
                          Text('تسجيل الخروج',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.error)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Delete account ────────────────────────────────
            GestureDetector(
              onTap: (_deletingAccount || _loggingOut) ? null : _deleteAccount,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: _deletingAccount
                    ? const Center(
                        child: SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.textHint),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete_forever_rounded,
                              color: AppColors.textHint, size: 16),
                          SizedBox(width: 6),
                          Text('حذف الحساب نهائياً',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textHint,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.textHint)),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 8),
            const Text('سولني · الإصدار 1.0.0',
                style: TextStyle(fontSize: 11, color: AppColors.textHint)),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const SizedBox(height: 2),
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
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
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textHint,
                  letterSpacing: 0.5)),
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
  const _MenuItem(
      {required this.icon, required this.label, required this.onTap});

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
              decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 17, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary)),
            ),
            const Icon(Icons.chevron_left_rounded,
                size: 18, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}
