import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/l10n_extension.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/device_service.dart';
import '../../../core/services/otp_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/whatsapp.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/lang_toggle.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;
  String? _errorPhone;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; _errorPhone = null; });
    try {
      final email = OtpService.phoneToEmail(_phoneCtrl.text.trim());
      final res = await SupabaseService.client.auth.signInWithPassword(
        email:    email,
        password: _passCtrl.text,
      );
      if (!mounted) return;

      final user = res.user;
      if (user == null) {
        setState(() => _error = context.l10n.authErrGeneral);
        return;
      }

      String? role;
      bool isActive = true;
      String? boundDeviceId;
      try {
        final profile = await SupabaseService.client
            .from('profiles')
            .select('role, is_active, device_id')
            .eq('id', user.id)
            .maybeSingle();
        role = profile?['role'] as String?;
        isActive = profile?['is_active'] as bool? ?? true;
        boundDeviceId = profile?['device_id'] as String?;
      } catch (_) {
        role = user.userMetadata?['role'] as String?;
      }

      if (!mounted) return;

      if (!isActive) {
        await SupabaseService.client.auth.signOut();
        if (!mounted) return;
        final supportPhone = await ref.read(supportPhoneProvider.future);
        if (!mounted) return;
        setState(() {
          _error = context.l10n.authAccountDisabled;
          _errorPhone = supportPhone.isNotEmpty ? supportPhone : null;
        });
        return;
      }

      // Lock student accounts to a single device to discourage sharing.
      // Teachers are exempt.
      if (role == 'student') {
        final deviceId = await DeviceService.getDeviceId();
        bool mismatched = false;
        if (boundDeviceId == null) {
          // Claim the device slot atomically (UPDATE ... WHERE device_id IS
          // NULL) instead of read-then-write — two near-simultaneous first
          // logins on different devices could otherwise both see NULL and
          // both "win" the bind.
          final deviceName = await DeviceService.getDeviceName();
          final claimed = await SupabaseService.client
              .from('profiles')
              .update({'device_id': deviceId, 'device_name': deviceName})
              .eq('id', user.id)
              .isFilter('device_id', null)
              .select('id');
          if ((claimed as List).isEmpty) {
            // Someone else claimed it first — re-check against the real value.
            final recheck = await SupabaseService.client
                .from('profiles')
                .select('device_id')
                .eq('id', user.id)
                .maybeSingle();
            final actualDeviceId = recheck?['device_id'] as String?;
            if (actualDeviceId != null && actualDeviceId != deviceId) {
              mismatched = true;
            }
          }
        } else if (boundDeviceId != deviceId) {
          mismatched = true;
        } else {
          // Same device as already bound — backfill device_name for accounts
          // bound before this field existed.
          await SupabaseService.client
              .from('profiles')
              .update({'device_name': await DeviceService.getDeviceName()})
              .eq('id', user.id)
              .isFilter('device_name', null);
        }

        if (mismatched) {
          await SupabaseService.client.auth.signOut();
          if (!mounted) return;
          final supportPhone = await ref.read(supportPhoneProvider.future);
          if (!mounted) return;
          setState(() {
            _error = context.l10n.authDeviceMismatch;
            _errorPhone = supportPhone.isNotEmpty ? supportPhone : null;
          });
          return;
        }
      }

      if (role == 'teacher') {
        context.go('/teacher/home');
      } else {
        context.go('/home');
      }
    } on AuthException catch (e) {
      setState(() { _error = _friendlyAuthError(e.message); _errorPhone = null; });
    } catch (e) {
      setState(() { _error = _friendlyAuthError(e.toString()); _errorPhone = null; });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyAuthError(String raw) {
    final l = context.l10n;
    final msg = raw.toLowerCase();
    if (msg.contains('invalid login') || msg.contains('invalid credentials') || msg.contains('wrong password')) {
      return l.authErrInvalidCredentials;
    }
    if (msg.contains('email not confirmed')) return l.authErrEmailNotConfirmed;
    if (msg.contains('user not found') || msg.contains('no user')) return l.authErrUserNotFound;
    if (msg.contains('rate limit') || msg.contains('too many')) return l.authErrRateLimit;
    if (msg.contains('network') || msg.contains('connection') || msg.contains('socket')) return l.authErrNetwork;
    if (msg.contains('database') || msg.contains('unexpected_failure')) return l.authErrServer;
    return l.authErrGeneral;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                child: Column(
                  children: [
                    // Language toggle
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: const LangToggle(),
                    ),
                    const SizedBox(height: 20),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/icons/Hessati.logo.png',
                        width: 72,
                        height: 72,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(l.authWelcome,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 6),
                    Text(l.authLoginSubtitle,
                      style: const TextStyle(fontSize: 14, color: Color(0xFF9DB2B8))),
                  ],
                ),
              ),
              // Form card
              Container(
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDECEC),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(_error!,
                                style: const TextStyle(fontSize: 13, color: Color(0xFFC0392B))),
                              if (_errorPhone != null)
                                GestureDetector(
                                  onTap: () => openWhatsApp(_errorPhone!),
                                  child: Padding(
                                    padding: const EdgeInsetsDirectional.only(start: 4),
                                    child: Text(_errorPhone!,
                                      style: const TextStyle(
                                        fontSize: 13, color: Color(0xFFC0392B),
                                        fontWeight: FontWeight.w700,
                                        decoration: TextDecoration.underline)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _label(l.authPhone),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        textDirection: TextDirection.ltr,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          hintText: l.authPhoneHint,
                          prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.textHint),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return l.authValidPhone;
                          if (v.trim().length < 7) return l.authValidPhoneInvalid;
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      _label(l.authPassword),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textHint),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: AppColors.textHint, size: 20),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) => (v == null || v.length < 6) ? l.authValidPassword : null,
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton(
                          onPressed: () => context.push('/forgot-password'),
                          child: Text(l.authForgotPassword,
                            style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      AppButton(label: l.authLoginBtn, isLoading: _loading, onTap: _login),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(l.authNoAccount,
                            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                          GestureDetector(
                            onTap: () => context.push('/register'),
                            child: Text(l.authCreateAccount,
                              style: const TextStyle(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
  );
}
