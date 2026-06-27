import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/l10n_extension.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/app_button.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String phone;
  const ResetPasswordScreen({super.key, required this.phone});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _loading  = false;
  String? _error;

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    if (!_formKey.currentState!.validate()) return;
    final l = context.l10n;
    setState(() { _loading = true; _error = null; });
    try {
      await SupabaseService.client.rpc('reset_password_by_phone', params: {
        'p_phone':        widget.phone,
        'p_new_password': _passCtrl.text,
      });
      if (!mounted) return;
      _showSuccess();
    } catch (e) {
      final msg = e.toString();
      if (msg.contains('غير مسجل') || msg.contains('not registered')) {
        setState(() => _error = l.resetPassErrNotFound);
      } else if (msg.contains('Could not find the function') ||
                 msg.contains('function') && msg.contains('does not exist')) {
        setState(() => _error = 'خطأ في الإعداد — تواصل مع الدعم (RPC missing)');
      } else {
        setState(() => _error = '${l.resetPassErrGeneral}\n$msg');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSuccess() {
    final l = context.l10n;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(Icons.check_rounded, color: Color(0xFF2E7D32), size: 34),
            ),
            const SizedBox(height: 16),
            Text(l.resetPassSuccessTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(l.resetPassSuccessBody,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/login');
                },
                child: Text(l.authLoginBtn,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
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
                        child: Icon(Icons.lock_outline_rounded, color: AppColors.primary, size: 32),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(l.resetPassTitle,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(height: 8),
                    Text(l.resetPassSubtitle(widget.phone),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14, color: Color(0xFF9DB2B8), height: 1.5)),
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
                        const SizedBox(height: 20),
                      ],

                      Text(l.changePassNewLabel,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passCtrl,
                        obscureText: _obscure1,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textHint),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure1 ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: AppColors.textHint, size: 20),
                            onPressed: () => setState(() => _obscure1 = !_obscure1),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.length < 6) return l.resetPassErrTooShort;
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),

                      Text(l.changePassConfirmLabel,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _confirmCtrl,
                        obscureText: _obscure2,
                        textDirection: TextDirection.ltr,
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppColors.textHint),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure2 ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: AppColors.textHint, size: 20),
                            onPressed: () => setState(() => _obscure2 = !_obscure2),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return l.resetPassErrConfirmEmpty;
                          if (v != _passCtrl.text) return l.changePassErrMismatch;
                          return null;
                        },
                      ),
                      const SizedBox(height: 28),

                      AppButton(
                        label: l.resetPassSaveBtn,
                        isLoading: _loading,
                        onTap: _reset,
                      ),
                      const SizedBox(height: 20),
                      GestureDetector(
                        onTap: () => context.go('/login'),
                        child: Center(
                          child: Text(l.authBackToLogin,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
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
}
