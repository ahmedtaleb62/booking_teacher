import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/l10n_extension.dart';
import '../../../core/services/otp_service.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/lang_toggle.dart';
import 'otp_screen.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure  = true;
  bool _loading  = false;
  String? _error;
  String _role = 'student';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      final phone = _phoneCtrl.text.trim();
      final code  = await OtpService.sendOtp(phone);

      if (!mounted) return;
      // Navigate to OTP verification screen
      context.push('/otp', extra: OtpArgs(
        expectedCode: code,
        phone:        phone,
        name:         _nameCtrl.text.trim(),
        password:     _passCtrl.text,
        role:         _role,
      ));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
              // ── Header ─────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 20),
                child: Column(
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: const LangToggle(),
                    ),
                    const SizedBox(height: 16),
                    Text(l.authRegisterTitle,
                        style: const TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 6),
                    Text(l.authRegisterSubtitle,
                        style: const TextStyle(fontSize: 14, color: Color(0xFF9DB2B8))),
                  ],
                ),
              ),

              // ── Form card ───────────────────────────────────────────────────
              Container(
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(32),
                    topRight: Radius.circular(32),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
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

                      // ── Role selector ─────────────────────────────────────
                      _label(l.authAccountType),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _roleChip('student', l.authStudent, Icons.school_outlined)),
                          const SizedBox(width: 12),
                          Expanded(child: _roleChip('teacher', l.authTeacher, Icons.person_outlined)),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ── Full name ─────────────────────────────────────────
                      _label(l.authFullName),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: l.authFullNameHint,
                          prefixIcon: const Icon(Icons.person_outline_rounded,
                              color: AppColors.textHint),
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? l.authValidName : null,
                      ),
                      const SizedBox(height: 18),

                      // ── Phone number ──────────────────────────────────────
                      _label('رقم الهاتف'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        textDirection: TextDirection.ltr,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          hintText: '44800028',
                          prefixIcon: Icon(Icons.phone_outlined, color: AppColors.textHint),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'أدخل رقم الهاتف';
                          if (v.trim().length < 7) return 'رقم الهاتف غير صحيح';
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      // ── Password ──────────────────────────────────────────
                      _label(l.authPassword),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        textDirection: TextDirection.ltr,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _sendOtp(),
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          prefixIcon: const Icon(Icons.lock_outline_rounded,
                              color: AppColors.textHint),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: AppColors.textHint, size: 20,
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: (v) =>
                            (v == null || v.length < 6) ? l.authValidPassword : null,
                      ),
                      const SizedBox(height: 28),

                      AppButton(
                        label: 'إرسال رمز التحقق',
                        isLoading: _loading,
                        onTap: _sendOtp,
                        leading: const Icon(Icons.sms_outlined, color: Colors.white, size: 18),
                      ),
                      const SizedBox(height: 18),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(l.authHaveAccount,
                              style: const TextStyle(
                                  fontSize: 14, color: AppColors.textSecondary)),
                          GestureDetector(
                            onTap: () => context.pop(),
                            child: Text(l.authLoginLink,
                                style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700)),
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

  Widget _roleChip(String value, String label, IconData icon) {
    final selected = _role == value;
    return GestureDetector(
      onTap: () => setState(() => _role = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18,
                color: selected ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
      );
}
