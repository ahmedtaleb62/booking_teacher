import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/app_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;
  String _role = 'student';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final res = await SupabaseService.client.auth.signUp(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
        data: {'full_name': _nameCtrl.text.trim(), 'role': _role},
      );
      if (!mounted) return;
      if (res.user == null) {
        setState(() => _error = 'تحقق من بريدك الإلكتروني لتأكيد الحساب');
        return;
      }
      if (_role == 'teacher') {
        context.go('/teacher/home');
      } else {
        context.go('/home');
      }
    } on AuthException catch (e) {
      setState(() => _error = _friendlyAuthError(e.message));
    } catch (e) {
      setState(() => _error = 'حدث خطأ غير متوقع، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyAuthError(String raw) {
    final msg = raw.toLowerCase();
    if (msg.contains('already registered') || msg.contains('already exists')) {
      return 'هذا البريد الإلكتروني مسجّل مسبقاً، سجّل دخولك بدلاً من ذلك';
    }
    if (msg.contains('database error') || msg.contains('unexpected_failure') || msg.contains('saving new user')) {
      return 'خطأ في الخادم، تأكد من اتصالك بالإنترنت وأعد المحاولة';
    }
    if (msg.contains('invalid email') || msg.contains('valid email')) {
      return 'صيغة البريد الإلكتروني غير صحيحة';
    }
    if (msg.contains('password') && msg.contains('6')) {
      return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
    }
    if (msg.contains('rate limit') || msg.contains('too many')) {
      return 'محاولات كثيرة، انتظر قليلاً ثم أعد المحاولة';
    }
    if (msg.contains('network') || msg.contains('connection') || msg.contains('socket')) {
      return 'تعذّر الاتصال بالخادم، تحقق من الإنترنت';
    }
    // fallback — don't show raw JSON
    return 'حدث خطأ، حاول مرة أخرى';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
                child: Column(
                  children: [
                    const Text('إنشاء حساب جديد',
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 6),
                    const Text('انضم لمنصة حجز استاذ',
                      style: TextStyle(fontSize: 14, color: Color(0xFF9DB2B8))),
                  ],
                ),
              ),
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
                      _label('نوع الحساب'),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: _roleChip('student', 'طالب', Icons.school_outlined)),
                          const SizedBox(width: 12),
                          Expanded(child: _roleChip('teacher', 'أستاذ', Icons.person_outlined)),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _label('الاسم الكامل'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          hintText: 'سيدنا أحمد',
                          prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.textHint),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'أدخل اسمك الكامل' : null,
                      ),
                      const SizedBox(height: 18),
                      _label('البريد الإلكتروني'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        textDirection: TextDirection.ltr,
                        decoration: const InputDecoration(
                          hintText: 'example@email.com',
                          prefixIcon: Icon(Icons.email_outlined, color: AppColors.textHint),
                        ),
                        validator: (v) => (v == null || !v.contains('@')) ? 'بريد إلكتروني غير صحيح' : null,
                      ),
                      const SizedBox(height: 18),
                      _label('كلمة المرور'),
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
                        validator: (v) => (v == null || v.length < 6) ? 'كلمة المرور 6 أحرف على الأقل' : null,
                      ),
                      const SizedBox(height: 28),
                      AppButton(label: 'إنشاء الحساب', isLoading: _loading, onTap: _register),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('لديك حساب بالفعل؟  ',
                            style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                          GestureDetector(
                            onTap: () => context.pop(),
                            child: const Text('تسجيل الدخول',
                              style: TextStyle(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.w700)),
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
                color: selected ? Colors.white : AppColors.textSecondary,
              )),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
  );
}
