import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/otp_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/app_button.dart';

/// Data passed from RegisterScreen (or ForgotPasswordScreen) via GoRouter extra.
class OtpArgs {
  final String expectedCode;
  final String phone;
  final String? name;
  final String? password;
  final String? role;
  // When true, after OTP verification navigate to /reset-password instead of signing up.
  final bool isPasswordReset;

  const OtpArgs({
    required this.expectedCode,
    required this.phone,
    this.name,
    this.password,
    this.role,
    this.isPasswordReset = false,
  });
}

class OtpScreen extends StatefulWidget {
  final OtpArgs args;
  const OtpScreen({super.key, required this.args});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _controllers = List.generate(6, (_) => TextEditingController());
  final _focuses     = List.generate(6, (_) => FocusNode());

  String? _error;
  bool _loading = false;

  // Resend cooldown
  int _resendSeconds = 60;
  Timer? _resendTimer;
  bool _resending = false;

  // Live expected code (can change on resend)
  late String _expectedCode;

  @override
  void initState() {
    super.initState();
    _expectedCode = widget.args.expectedCode;
    _startResendCountdown();
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    for (final f in _focuses) f.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _resendSeconds--;
        if (_resendSeconds <= 0) t.cancel();
      });
    });
  }

  String get _enteredCode =>
      _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    final code = _enteredCode;
    if (code.length < 6) {
      setState(() => _error = 'أدخل رمز التحقق المكوّن من 6 أرقام');
      return;
    }
    if (code != _expectedCode) {
      setState(() => _error = 'رمز التحقق غير صحيح — تأكد من الرمز وأعد المحاولة');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      // Password-reset flow: OTP verified — go to reset password screen
      if (widget.args.isPasswordReset) {
        if (!mounted) return;
        context.go('/reset-password', extra: {'phone': widget.args.phone});
        return;
      }

      final email = OtpService.phoneToEmail(widget.args.phone);
      final res = await SupabaseService.client.auth.signUp(
        email:    email,
        password: widget.args.password!,
        data: {
          'full_name': widget.args.name ?? '',
          'role':      widget.args.role ?? 'student',
          'phone':     widget.args.phone,
        },
      );
      if (!mounted) return;

      if (res.user == null) {
        setState(() => _error = 'فشل إنشاء الحساب — حاول مجدداً');
        return;
      }

      // Also store phone in profiles table
      try {
        await SupabaseService.client.from('profiles').upsert(
          {'id': res.user!.id, 'phone': widget.args.phone},
          onConflict: 'id',
        );
      } catch (_) {}

      if (!mounted) return;
      if (widget.args.role == 'teacher') {
        context.go('/teacher/home');
      } else {
        context.go('/home');
      }
    } on AuthException catch (e) {
      setState(() => _error = _authError(e.message));
    } catch (e) {
      setState(() => _error = 'خطأ غير متوقع: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_resending || _resendSeconds > 0) return;
    setState(() { _resending = true; _error = null; });
    try {
      final code = await OtpService.sendOtp(widget.args.phone);
      _expectedCode = code;
      for (final c in _controllers) c.clear();
      _focuses.first.requestFocus();
      _startResendCountdown();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  String _authError(String raw) {
    final msg = raw.toLowerCase();
    if (msg.contains('already registered') || msg.contains('already exists')) {
      return 'هذا الرقم مسجّل مسبقاً — سجّل الدخول بدلاً من ذلك';
    }
    if (msg.contains('password') && msg.contains('6')) {
      return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
    }
    return 'فشل إنشاء الحساب: $raw';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── Header ────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
                child: Column(
                  children: [
                    Container(
                      width: 68, height: 68,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: const Center(
                        child: Icon(Icons.sms_outlined, color: AppColors.primary, size: 32),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('التحقق من رقم الهاتف',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 8),
                    Text(
                      'أرسلنا رمز التحقق إلى\n${widget.args.phone}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: Color(0xFF9DB2B8), height: 1.5),
                    ),
                  ],
                ),
              ),

              // ── Form card ─────────────────────────────────────────────────
              Container(
                constraints: const BoxConstraints(minHeight: 400),
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(28, 36, 28, 40),
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
                      const SizedBox(height: 20),
                    ],

                    // ── 6-digit OTP boxes ─────────────────────────────────
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(6, (i) => _OtpBox(
                          controller: _controllers[i],
                          focusNode:  _focuses[i],
                          onChanged: (val) {
                            setState(() => _error = null);
                            if (val.isNotEmpty && i < 5) {
                              _focuses[i + 1].requestFocus();
                            }
                            if (_enteredCode.length == 6) _verify();
                          },
                          onBackspace: () {
                            if (_controllers[i].text.isEmpty && i > 0) {
                              _controllers[i - 1].clear();
                              _focuses[i - 1].requestFocus();
                            }
                          },
                        )),
                      ),
                    ),

                    const SizedBox(height: 32),
                    AppButton(
                      label: 'تأكيد',
                      isLoading: _loading,
                      onTap: _verify,
                    ),
                    const SizedBox(height: 20),

                    // ── Resend ─────────────────────────────────────────────
                    Center(
                      child: _resendSeconds > 0
                          ? Text(
                              'إعادة الإرسال خلال $_resendSeconds ث',
                              style: const TextStyle(fontSize: 13, color: AppColors.textHint),
                            )
                          : GestureDetector(
                              onTap: _resend,
                              child: _resending
                                  ? const SizedBox(
                                      width: 18, height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: AppColors.primary))
                                  : const Text(
                                      'إعادة إرسال الرمز',
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700),
                                    ),
                            ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: GestureDetector(
                        onTap: () => context.pop(),
                        child: const Text(
                          'تغيير رقم الهاتف',
                          style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              decoration: TextDecoration.underline),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Single OTP digit box ───────────────────────────────────────────────────────
class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onBackspace;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46, height: 56,
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              controller.text.isEmpty) {
            onBackspace();
          }
        },
        child: TextField(
          controller:    controller,
          focusNode:     focusNode,
          textAlign:     TextAlign.center,
          keyboardType:  TextInputType.number,
          maxLength:     1,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          decoration: InputDecoration(
            counterText: '',
            contentPadding: EdgeInsets.zero,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
            filled: true,
            fillColor: AppColors.surface,
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
