import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/l10n_extension.dart';
import '../../../core/services/otp_service.dart';
import '../../../core/services/supabase_service.dart';
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

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
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
      try {
        final profile = await SupabaseService.client
            .from('profiles')
            .select('role')
            .eq('id', user.id)
            .maybeSingle();
        role = profile?['role'] as String?;
      } catch (_) {
        role = user.userMetadata?['role'] as String?;
      }

      if (!mounted) return;
      if (role == 'teacher') {
        context.go('/teacher/home');
      } else {
        context.go('/home');
      }
    } on AuthException catch (e) {
      setState(() => _error = _friendlyAuthError(e.message));
    } catch (e) {
      setState(() => _error = _friendlyAuthError(e.toString()));
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
                          child: Text(_error!,
                            style: const TextStyle(fontSize: 13, color: Color(0xFFC0392B))),
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
