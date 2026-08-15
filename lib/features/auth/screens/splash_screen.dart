import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/l10n_extension.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/device_service.dart';
import '../../../core/services/fcm_service.dart';
import '../../../core/services/supabase_service.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.8, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _ctrl.forward();

    Future.delayed(const Duration(seconds: 2), _navigate);
  }

  Future<void> _navigate() async {
    if (!mounted) return;
    final user = SupabaseService.currentUser;
    if (user == null) {
      context.go('/login');
      return;
    }
    try {
      // Request permission + save FCM token on first login
      await FcmService.requestPermission();
      await FcmService.saveToken();

      final profile = await SupabaseService.client
          .from('profiles')
          .select('role, is_active, device_id')
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted) return;
      final role = profile?['role'] as String?;
      final isActive = profile?['is_active'] as bool? ?? true;
      final boundDeviceId = profile?['device_id'] as String?;

      if (!isActive) {
        await SupabaseService.client.auth.signOut();
        if (!mounted) return;
        final supportPhone = await ref.read(supportPhoneProvider.future);
        if (!mounted) return;
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: Text(context.l10n.authAccountDisabledTitle),
            content: Text(supportPhone.isNotEmpty
                ? '${context.l10n.authAccountDisabled} $supportPhone'
                : context.l10n.authAccountDisabled),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.l10n.authBackToLogin),
              ),
            ],
          ),
        );
        if (!mounted) return;
        context.go('/login');
        return;
      }

      // Lock student accounts to a single device to discourage sharing.
      if (role == 'student') {
        final deviceId = await DeviceService.getDeviceId();
        if (boundDeviceId == null) {
          await SupabaseService.client
              .from('profiles')
              .update({'device_id': deviceId})
              .eq('id', user.id);
        } else if (boundDeviceId != deviceId) {
          await SupabaseService.client.auth.signOut();
          if (!mounted) return;
          final supportPhone = await ref.read(supportPhoneProvider.future);
          if (!mounted) return;
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              title: Text(context.l10n.authDeviceMismatchTitle),
              content: Text(supportPhone.isNotEmpty
                  ? '${context.l10n.authDeviceMismatch} $supportPhone'
                  : context.l10n.authDeviceMismatch),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(context.l10n.authBackToLogin),
                ),
              ],
            ),
          );
          if (!mounted) return;
          context.go('/login');
          return;
        }
      }

      if (role == 'teacher') {
        // Check if teacher has completed onboarding
        final tp = await SupabaseService.client
            .from('teacher_profiles')
            .select('id')
            .eq('id', user.id)
            .maybeSingle();
        if (!mounted) return;
        if (tp == null) {
          context.go('/teacher/onboarding');
        } else {
          context.go('/teacher/home');
        }
      } else {
        context.go('/home');
      }
    } catch (_) {
      if (mounted) context.go('/login');
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.35),
                        blurRadius: 40, spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.asset(
                      'assets/icons/Hessati.logo.png',
                      width: 110,
                      height: 110,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  context.l10n.appName,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.splashTagline,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF9DB2B8)),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: 28, height: 28,
                  child: CircularProgressIndicator(
                    color: AppColors.accent, strokeWidth: 2.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
