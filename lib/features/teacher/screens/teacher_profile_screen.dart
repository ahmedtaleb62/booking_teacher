import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/subjects.dart';
import '../../../core/extensions/l10n_extension.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/providers/sessions_provider.dart';
import '../../../core/services/supabase_service.dart';

// Cache-busting version for avatar URL — increments after each upload
final _avatarVersionProvider = StateProvider<int>((ref) => 0);

class TeacherSelfProfileScreen extends ConsumerStatefulWidget {
  const TeacherSelfProfileScreen({super.key});
  @override
  ConsumerState<TeacherSelfProfileScreen> createState() => _TeacherSelfProfileScreenState();
}

class _TeacherSelfProfileScreenState extends ConsumerState<TeacherSelfProfileScreen> {
  bool _loggingOut      = false;
  bool _uploadingAvatar = false;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _subscribeApproval();
  }

  void _subscribeApproval() {
    final uid = SupabaseService.userId;
    if (uid == null) return;
    _channel = SupabaseService.client
        .channel('teacher-profile-approval-$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'teacher_profiles',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: uid,
          ),
          callback: (_) => ref.invalidate(teacherProfileProvider),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _pickAndUploadAvatar() async {
    final l = context.l10n;
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

      await SupabaseService.client.storage
          .from('avatars')
          .uploadBinary(
            '$uid/avatar.$ext',
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );

      final publicUrl = SupabaseService.client.storage
          .from('avatars')
          .getPublicUrl('$uid/avatar.$ext');

      await SupabaseService.client
          .from('profiles')
          .update({'avatar_url': publicUrl})
          .eq('id', uid);

      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      ref.read(_avatarVersionProvider.notifier).state++;
      ref.invalidate(teacherProfileProvider);
      ref.invalidate(currentProfileProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.editProfileUploadError(e.toString())),
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

  Future<void> _deleteAccount() async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.profileDeleteAccount,
            style: const TextStyle(color: AppColors.error)),
        content: Text(l.profileDeleteAccountBody,
            style: const TextStyle(height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.dialogCancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.profileDeleteBtn,
                style: const TextStyle(
                    color: AppColors.error, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final phrase = l.profileDeleteConfirmPhrase;
    final input = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: Text(l.profileDeleteConfirmTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.profileDeleteConfirmBody(phrase),
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              TextField(
                controller: ctrl,
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
              child: Text(l.dialogCancel)),
            TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: Text(l.dialogConfirm,
                  style: const TextStyle(
                      color: AppColors.error, fontWeight: FontWeight.w700))),
          ],
        );
      },
    );
    if (input != phrase || !mounted) return;

    try {
      await SupabaseService.client.rpc('delete_my_account');
      await SupabaseService.client.auth.signOut();
      if (mounted) context.go('/login');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.profileDeleteAccountErr(e.toString())),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.profileLogout),
        content: Text(l.profileLogoutConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.dialogCancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.profileLogoutConfirmYes,
                style: const TextStyle(color: AppColors.error))),
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

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(teacherProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async => ref.invalidate(teacherProfileProvider),
        child: profileAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary)),
          error: (_, __) => _buildBody(context, null),
          data: (profile) => _buildBody(context, profile),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, Map<String, dynamic>? profile) {
    final l = context.l10n;
    final profileInner = profile?['profile'] as Map? ?? {};
    final name       = (profileInner['full_name'] as String?) ?? l.teacherDefaultName;
    final rawUrl     = (profileInner['avatar_url'] as String?);
    final v          = ref.watch(_avatarVersionProvider);
    final avatarUrl  = rawUrl != null ? '$rawUrl?v=$v' : null;
    final isActive   = (profileInner['is_active'] as bool?) ?? false;
    final isApproved = (profile?['is_approved'] as bool?) ?? false;
    final subjects   = (profile?['subjects'] as List?)?.cast<String>() ?? [];
    final rating     = (profile?['rating'] as num?)?.toDouble() ?? 0.0;
    final reviews    = (profile?['review_count'] as int?) ?? 0;
    final sessions   = (profile?['total_sessions'] as int?) ?? 0;
    final attendance = (profile?['attendance_rate'] as num?)?.toDouble() ?? 100.0;
    final initial    = name.isNotEmpty ? name[0] : 'أ';
    final hasProfile = profile != null;

    return ListView(
      children: [
        SizedBox(height: MediaQuery.of(context).padding.top + 8),

        // ── Header ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            children: [
              GestureDetector(
                onTap: _uploadingAvatar ? null : _pickAndUploadAvatar,
                child: Stack(
                  children: [
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                        gradient: avatarUrl == null
                            ? const LinearGradient(
                                colors: [Color(0xFF1B6B7A), Color(0xFF11313A)])
                            : null,
                        color: avatarUrl != null ? AppColors.surfaceAlt : null,
                        shape: BoxShape.circle,
                        image: avatarUrl != null
                            ? DecorationImage(
                                image: NetworkImage(avatarUrl),
                                fit: BoxFit.cover)
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: _uploadingAvatar
                          ? const CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2)
                          : avatarUrl == null
                              ? Text(initial,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 32,
                                      fontWeight: FontWeight.w700))
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
                      fontSize: 20, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              if (subjects.isNotEmpty)
                Text(subjects.take(3).map((s) => translateSubject(s, Localizations.localeOf(context))).join(' · '),
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: isApproved
                      ? const Color(0xFFE3F6EF)
                      : const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isApproved
                          ? Icons.verified_rounded
                          : Icons.hourglass_empty_rounded,
                      size: 14,
                      color: isApproved
                          ? const Color(0xFF1B9E77)
                          : const Color(0xFFF57C00),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isApproved
                          ? (isActive
                              ? l.teacherStatusApprovedActive
                              : l.teacherStatusApprovedInactive)
                          : l.teacherStatusPending,
                      style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: isApproved
                            ? const Color(0xFF15805F)
                            : const Color(0xFFE65100),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Stats ─────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Row(
            children: [
              _StatCard(value: '$sessions',  label: l.teacherStatSessions),
              const SizedBox(width: 10),
              _StatCard(
                value: rating > 0 ? rating.toStringAsFixed(1) : '—',
                label: l.teacherStatRating(reviews)),
              const SizedBox(width: 10),
              _StatCard(
                value: '${attendance.toInt()}%',
                label: l.teacherStatAttendance),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Complete profile banner ───────────────────────────
        if (!hasProfile) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: GestureDetector(
              onTap: () => context.push('/teacher/onboarding'),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFFFFCC02).withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Color(0xFFF57C00), size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.teacherCompleteProfile,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700,
                                color: Color(0xFFE65100))),
                          const SizedBox(height: 2),
                          Text(l.teacherCompleteProfileHint,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFFF57C00))),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_back_ios_rounded,
                        size: 14, color: Color(0xFFF57C00)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── Menus ─────────────────────────────────────────────
        _MenuSection(title: l.profileSectionAccount, items: [
          _MenuItem(
            icon: Icons.person_outline_rounded,
            label: l.profileEditProfile,
            onTap: () => context.push('/edit-profile'),
          ),
          _MenuItem(
            icon: Icons.badge_outlined,
            label: hasProfile ? l.teacherEditTeachingInfo : l.teacherOnboardingMenuItem,
            trailing: !hasProfile
                ? _WarningBadge(label: l.teacherBadgeRequired)
                : null,
            onTap: () => context.push('/teacher/onboarding'),
          ),
          _MenuItem(
            icon: Icons.lock_outline_rounded,
            label: l.profileChangePassword,
            onTap: () => context.push('/change-password'),
          ),
          _MenuItem(
            icon: Icons.schedule_rounded,
            label: l.availTitle,
            onTap: () => context.push('/teacher/availability'),
          ),
          _MenuItem(
            icon: Icons.notifications_outlined,
            label: l.notifTitle,
            onTap: () => context.go('/teacher/notifications'),
          ),
          _MenuItem(
            icon: Icons.star_outline_rounded,
            label: l.profileMyRatings,
            onTap: () => context.push('/teacher/ratings'),
          ),
        ]),
        const SizedBox(height: 16),

        _MenuSection(title: l.profileSectionEarnings, items: [
          _MenuItem(
            icon: Icons.account_balance_wallet_outlined,
            label: l.teacherMenuEarnings,
            onTap: () => context.go('/teacher/earnings'),
          ),
        ]),
        const SizedBox(height: 16),

        _MenuSection(title: l.profileSectionSupport, items: [
          _MenuItem(
            icon: Icons.help_outline_rounded,
            label: l.profileMenuHelp,
            onTap: () => context.push('/help-center')),
          _MenuItem(
            icon: Icons.privacy_tip_outlined,
            label: l.profileMenuPrivacy,
            onTap: () => context.push('/help-center?tab=privacy')),
          _MenuItem(
            icon: Icons.gavel_rounded,
            label: l.profileMenuTerms,
            onTap: () => context.push('/help-center?tab=terms')),
        ]),
        const SizedBox(height: 16),

        // ── Language switcher ─────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.langSwitcher,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                  color: AppColors.textHint, letterSpacing: 0.5)),
              const SizedBox(height: 10),
              _LanguageSwitcher(),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Logout ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: GestureDetector(
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
                      ))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.logout_rounded,
                            color: AppColors.error, size: 18),
                        const SizedBox(width: 8),
                        Text(l.profileLogout,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700,
                              color: AppColors.error)),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── Delete account link ───────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: GestureDetector(
            onTap: _deleteAccount,
            child: Center(
              child: Text(
                l.profileDeleteAccountLink,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.error.withValues(alpha: 0.7),
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.error.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(l.profileAppVersion,
              style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  const _StatCard({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(fontSize: 10, color: AppColors.textHint),
              textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _WarningBadge extends StatelessWidget {
  final String label;
  const _WarningBadge({required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(999)),
    child: Text(label,
        style: const TextStyle(
            fontSize: 10, fontWeight: FontWeight.w700,
            color: Color(0xFFF57C00))),
  );
}

class _MenuSection extends StatelessWidget {
  final String title;
  final List<_MenuItem> items;
  const _MenuSection({required this.title, required this.items});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 22),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: AppColors.textHint)),
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
              return Column(
                children: [
                  InkWell(
                    onTap: e.value.onTap,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Icon(e.value.icon, size: 20,
                              color: AppColors.textSecondary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(e.value.label,
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textPrimary))),
                          if (e.value.trailing != null) ...[
                            e.value.trailing!,
                            const SizedBox(width: 8),
                          ],
                          const Icon(Icons.arrow_back_ios_rounded,
                              size: 14, color: AppColors.textHint),
                        ],
                      ),
                    ),
                  ),
                  if (!isLast)
                    const Divider(
                        height: 1, indent: 48, color: AppColors.border),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    ),
  );
}

class _MenuItem {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback onTap;
  const _MenuItem({
      required this.icon,
      required this.label,
      required this.onTap,
      this.trailing});
}

class _LanguageSwitcher extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final isAr   = locale.languageCode == 'ar';
    final l      = context.l10n;

    return Container(
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
    );
  }
}

class _LangOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _LangOption({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.textHint,
          )),
      ),
    ),
  );
}
