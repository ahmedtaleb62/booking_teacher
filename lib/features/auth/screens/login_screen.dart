import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/app_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      final res = await SupabaseService.client.auth.signInWithPassword(
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      if (!mounted) return;
      final profile = await SupabaseService.client
          .from('profiles')
          .select('role')
          .eq('id', res.user!.id)
          .maybeSingle();
      if (!mounted) return;
      final role = profile?['role'] as String?;
      if (role == 'teacher') {
        context.go('/teacher/home');
      } else {
        context.go('/home');
      }
    } on AuthException catch (e) {
      setState(() => _error = _friendlyAuthError(e.message));
    } catch (_) {
      setState(() => _error = 'حدث خطأ غير متوقع، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _friendlyAuthError(String raw) {
    final msg = raw.toLowerCase();
    if (msg.contains('invalid login') || msg.contains('invalid credentials') || msg.contains('wrong password')) {
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
    }
    if (msg.contains('email not confirmed')) {
      return 'لم يتم تأكيد البريد الإلكتروني، تحقق من صندوق الوارد';
    }
    if (msg.contains('user not found') || msg.contains('no user')) {
      return 'لا يوجد حساب بهذا البريد الإلكتروني';
    }
    if (msg.contains('rate limit') || msg.contains('too many')) {
      return 'محاولات كثيرة، انتظر قليلاً ثم أعد المحاولة';
    }
    if (msg.contains('network') || msg.contains('connection') || msg.contains('socket')) {
      return 'تعذّر الاتصال بالخادم، تحقق من الإنترنت';
    }
    if (msg.contains('database') || msg.contains('unexpected_failure')) {
      return 'خطأ في الخادم، أعد المحاولة لاحقاً';
    }
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
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(28, 48, 28, 36),
                child: Column(
                  children: [
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Center(
                        child: Text('ح', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('أهلاً بك',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 6),
                    const Text('سجّل دخولك للمتابعة',
                      style: TextStyle(fontSize: 14, color: Color(0xFF9DB2B8))),
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
                        validator: (v) => (v == null || v.isEmpty) ? 'أدخل البريد الإلكتروني' : null,
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
                      const SizedBox(height: 8),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton(
                          onPressed: () {},
                          child: const Text('نسيت كلمة المرور؟',
                            style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      AppButton(label: 'تسجيل الدخول', isLoading: _loading, onTap: _login),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('ليس لديك حساب؟  ',
                            style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                          GestureDetector(
                            onTap: () => context.push('/register'),
                            child: const Text('أنشئ حساباً',
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

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
  );
}
