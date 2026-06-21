import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _newCtrl     = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _saving       = false;
  bool _showNew      = false;
  bool _showConfirm  = false;
  String? _errorMsg;

  @override
  void dispose() {
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final newPass     = _newCtrl.text.trim();
    final confirmPass = _confirmCtrl.text.trim();

    if (newPass.length < 8) {
      setState(() => _errorMsg = 'كلمة المرور يجب أن تكون 8 أحرف على الأقل');
      return;
    }
    if (newPass != confirmPass) {
      setState(() => _errorMsg = 'كلمتا المرور غير متطابقتين');
      return;
    }

    setState(() { _saving = true; _errorMsg = null; });
    try {
      await SupabaseService.client.auth.updateUser(
        UserAttributes(password: newPass),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم تغيير كلمة المرور بنجاح'),
            backgroundColor: AppColors.statusConfirmed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMsg = 'فشل تغيير كلمة المرور — تأكد من اتصالك أو سجّل دخولك مجدداً';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: const Icon(Icons.arrow_forward_rounded, color: AppColors.textPrimary),
        ),
        title: const Text('تغيير كلمة المرور',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.statusApprovedBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: AppColors.statusApproved, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'ستحتاج إلى تسجيل الدخول مجدداً بعد تغيير كلمة المرور',
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.statusApproved,
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // New password
            const Text('كلمة المرور الجديدة',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            TextField(
              controller: _newCtrl,
              obscureText: !_showNew,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: '٨ أحرف على الأقل',
                hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
                filled: true,
                fillColor: AppColors.surface,
                prefixIcon: const Icon(Icons.lock_outline_rounded,
                    color: AppColors.textHint, size: 20),
                suffixIcon: GestureDetector(
                  onTap: () => setState(() => _showNew = !_showNew),
                  child: Icon(
                    _showNew ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: AppColors.textHint, size: 20,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),
            const SizedBox(height: 16),

            // Confirm password
            const Text('تأكيد كلمة المرور',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            TextField(
              controller: _confirmCtrl,
              obscureText: !_showConfirm,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'أعد كتابة كلمة المرور',
                hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
                filled: true,
                fillColor: AppColors.surface,
                prefixIcon: const Icon(Icons.lock_reset_rounded,
                    color: AppColors.textHint, size: 20),
                suffixIcon: GestureDetector(
                  onTap: () => setState(() => _showConfirm = !_showConfirm),
                  child: Icon(
                    _showConfirm
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.textHint, size: 20,
                  ),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              ),
            ),

            if (_errorMsg != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.statusRejectedBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppColors.error, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_errorMsg!,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.error)),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('تغيير كلمة المرور',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
