import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/constants/session_states.dart';
import '../../../core/extensions/l10n_extension.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/models/course.dart' show SubscriptionStatus;
import '../../../core/providers/courses_provider.dart';
import '../../../core/providers/sessions_provider.dart';
import 'package:app_settings/app_settings.dart';
import '../../../core/services/fcm_service.dart';
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
    final l = context.l10n;
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
            content: Text('${l.profileAvatarUploadError}: ${e.toString()}'),
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
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.profileLogout),
        content: Text(l.profileLogoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.profileLogoutBtn,
              style: const TextStyle(color: AppColors.error)),
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
    final l = context.l10n;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.profileDeleteTitle,
          style: const TextStyle(color: AppColors.error)),
        content: Text(l.profileDeleteContent,
          style: const TextStyle(height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.commonDelete,
              style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final confirmCtrl = TextEditingController();
    final phrase      = l.profileDeletePhrase;
    final input = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.profileDeleteFinalTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.profileDeleteTypeHint(phrase),
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            TextField(
              controller: confirmCtrl,
              textDirection: TextDirection.rtl,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text(l.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, confirmCtrl.text),
            child: Text(l.commonConfirm,
              style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ).whenComplete(confirmCtrl.dispose);

    if (input != phrase || !mounted) return;

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
            content: Text('${l.profileDeleteAccountError}: ${e.toString()}'),
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
    final l             = context.l10n;
    ref.watch(sessionsRealtimeProvider);
    final profileAsync  = ref.watch(currentProfileProvider);
    final sessionsAsync = ref.watch(studentSessionsProvider);
    final subsAsync     = ref.watch(mySubscriptionsProvider);

    final name = profileAsync.when(
      data: (p) => p?['full_name'] as String? ?? l.profileUserFallback,
      loading: () => '...',
      error: (_, __) => l.profileUserFallback,
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
      totalSessions     = sessions.length;
      completedSessions = sessions.where((s) => s.state == SessionState.completed).length;
      totalAmount      += sessions
          .where((s) =>
              s.state == SessionState.paymentConfirmed ||
              s.state == SessionState.confirmedBooking ||
              s.state == SessionState.activeSession ||
              s.state == SessionState.completed)
          .fold(0.0, (sum, s) => sum + s.amount);
    });
    // Add subscription payments (active or pending = paid)
    subsAsync.whenData((subs) {
      for (final s in subs) {
        if (s.status == SubscriptionStatus.active ||
            s.status == SubscriptionStatus.pending) {
          totalAmount += s.amount;
        }
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(l.navProfile),
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
                              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                              : avatarUrl == null
                                  ? Text(initial,
                                      style: const TextStyle(fontSize: 32,
                                        fontWeight: FontWeight.w700, color: Colors.white))
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
                            child: const Icon(Icons.camera_alt_rounded, size: 12, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(email,
                    style: const TextStyle(fontSize: 13, color: AppColors.textHint)),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _StatItem(value: '$totalSessions', label: l.profileTotalSessions),
                      Container(width: 1, height: 32, color: AppColors.border),
                      _StatItem(value: '$completedSessions', label: l.profileCompletedStat),
                      Container(width: 1, height: 32, color: AppColors.border),
                      _StatItem(
                        value: l.sessionOugiya('${totalAmount.toInt()}'),
                        label: l.profileTotalPayment),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Account section ───────────────────────────────
            _SectionCard(
              title: l.profileSectionAccount,
              items: [
                _MenuItem(
                  icon: Icons.person_outline_rounded,
                  label: l.profileEditProfile,
                  onTap: () => context.push('/edit-profile'),
                ),
                _MenuItem(
                  icon: Icons.lock_outline_rounded,
                  label: l.profileChangePassword,
                  onTap: () => context.push('/change-password'),
                ),
                _MenuItem(
                  icon: Icons.notifications_outlined,
                  label: l.profileNotifSettings,
                  onTap: () async {
                    final settings = await FcmService.getPermissionStatus();
                    if (settings) {
                      AppSettings.openAppSettings(type: AppSettingsType.notification);
                    } else {
                      await FcmService.requestPermission();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Language switcher ─────────────────────────────
            _LanguageSwitcher(),
            const SizedBox(height: 14),

            // ── Sessions & payments ───────────────────────────
            _SectionCard(
              title: l.profileSectionSessions,
              items: [
                _MenuItem(
                  icon: Icons.history_rounded,
                  label: l.profileSessionHistory,
                  onTap: () => context.go('/sessions'),
                ),
                _MenuItem(
                  icon: Icons.receipt_long_outlined,
                  label: l.profilePaymentHistory,
                  onTap: () => context.push('/payments'),
                ),
                _MenuItem(
                  icon: Icons.star_outline_rounded,
                  label: l.profileMyRatings,
                  onTap: () => context.push('/my-ratings'),
                ),
                _MenuItem(
                  icon: Icons.feedback_outlined,
                  label: l.profileComplaint,
                  onTap: () => context.push('/complaint'),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // ── Support ───────────────────────────────────────
            _SectionCard(
              title: l.profileSectionSupport,
              items: [
                _MenuItem(icon: Icons.help_outline_rounded,  label: l.profileHelpCenter,   onTap: () => context.push('/help-center')),
                _MenuItem(icon: Icons.policy_outlined,       label: l.profilePrivacyPolicy, onTap: () => context.push('/help-center?tab=privacy')),
                _MenuItem(icon: Icons.gavel_rounded,         label: l.profileTerms,         onTap: () => context.push('/help-center?tab=terms')),
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
                  border: Border.all(color: AppColors.statusRejected.withValues(alpha: 0.3)),
                ),
                child: _loggingOut
                    ? const Center(
                        child: SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.error),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.logout_rounded, color: AppColors.error, size: 18),
                          const SizedBox(width: 8),
                          Text(l.profileLogout,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
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
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textHint),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.delete_forever_rounded, color: AppColors.textHint, size: 16),
                          const SizedBox(width: 6),
                          Text(l.profileDeleteAccountBtn,
                            style: const TextStyle(fontSize: 13, color: AppColors.textHint,
                              decoration: TextDecoration.underline,
                              decorationColor: AppColors.textHint)),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 8),
            Text('${l.appName} · ${l.profileVersion} 1.0.0',
              style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────

class _LanguageSwitcher extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final isAr   = locale.languageCode == 'ar';
    final l      = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, right: 4),
          child: Text(l.langSwitcher,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
              color: AppColors.textHint, letterSpacing: 0.5)),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          padding: const EdgeInsets.all(6),
          child: Row(
            children: [
              _LangOption(
                label: l.langArabic,
                selected: isAr,
                onTap: () => ref.read(localeProvider.notifier).state = const Locale('ar'),
              ),
              const SizedBox(width: 6),
              _LangOption(
                label: l.langFrench,
                selected: !isAr,
                onTap: () => ref.read(localeProvider.notifier).state = const Locale('fr'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LangOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _LangOption({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
              color: selected ? Colors.white : AppColors.textSecondary)),
        ),
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
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
            color: AppColors.textPrimary)),
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
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(9)),
              child: Icon(icon, size: 17, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary)),
            ),
            const Icon(Icons.chevron_left_rounded, size: 18, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}
