import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/session_states.dart';
import '../../../shared/widgets/app_button.dart';

class RequestSentScreen extends StatefulWidget {
  final String sessionId;
  const RequestSentScreen({super.key, required this.sessionId});
  @override
  State<RequestSentScreen> createState() => _RequestSentScreenState();
}

class _RequestSentScreenState extends State<RequestSentScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() { _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final state = SessionState.requested;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.go('/home'),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.home_rounded, size: 18, color: AppColors.textPrimary),
                    ),
                  ),
                  const Spacer(),
                  const Text('حالة الطلب',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const Spacer(),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated icon
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (_, __) => Container(
                      width: 96, height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: state.bgColor,
                        boxShadow: [
                          BoxShadow(
                            color: state.color.withValues(alpha: 0.25 + _pulse.value * 0.25),
                            blurRadius: 20 + _pulse.value * 20,
                            spreadRadius: _pulse.value * 6,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 68, height: 68,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: state.color),
                          child: const Icon(Icons.access_time_rounded, color: Colors.white, size: 32),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: state.bgColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('REQUESTED · بانتظار الموافقة',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: state.color)),
                  ),
                  const SizedBox(height: 18),

                  const Text('تم إرسال طلبك',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'سيراجع د. محمد الأمين طلبك ويردّ عادةً خلال ساعتين. سنُعلمك فور الموافقة لتنتقل إلى الدفع.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, height: 1.7, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Who is responsible
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: state.bgColor,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            alignment: Alignment.center,
                            child: Text('أ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: state.color)),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('المسؤول الآن',
                                style: TextStyle(fontSize: 11, color: AppColors.textHint)),
                              Text('الأستاذ — مراجعة الطلب',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom actions
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
              child: Row(
                children: [
                  Expanded(
                    child: AppButton(
                      label: 'إلغاء الطلب',
                      isOutlined: true,
                      isDanger: true,
                      onTap: () => _showCancelDialog(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppButton(
                      label: 'تتبّع الحالة',
                      color: AppColors.primaryDark,
                      onTap: () => context.push('/session/${widget.sessionId}'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إلغاء الطلب'),
        content: const Text('هل أنت متأكد من رغبتك في إلغاء هذا الطلب؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('تراجع'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/home');
            },
            child: const Text('نعم، إلغاء', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
