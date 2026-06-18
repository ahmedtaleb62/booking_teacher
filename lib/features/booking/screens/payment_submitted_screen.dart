import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/session_states.dart';
import '../../../shared/widgets/app_button.dart';

class PaymentSubmittedScreen extends StatefulWidget {
  final String sessionId;
  const PaymentSubmittedScreen({super.key, required this.sessionId});
  @override
  State<PaymentSubmittedScreen> createState() => _PaymentSubmittedScreenState();
}

class _PaymentSubmittedScreenState extends State<PaymentSubmittedScreen>
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
    final state = SessionState.paymentSubmitted;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
              child: Row(
                children: [
                  const Spacer(),
                  const Text('حالة الدفع',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const Spacer(),
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
                            color: state.color.withValues(alpha: 0.2 + _pulse.value * 0.2),
                            blurRadius: 20 + _pulse.value * 20,
                            spreadRadius: _pulse.value * 5,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: 68, height: 68,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: state.color),
                          child: const Icon(Icons.shield_outlined, color: Colors.white, size: 30),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: state.bgColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('PAYMENT · قيد التحقق',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: state.color)),
                  ),
                  const SizedBox(height: 18),

                  const Text('الإدارة تتحقق من دفعتك',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const SizedBox(height: 8),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'استلمنا إثبات التحويل. يراجعه فريق الإدارة ويؤكّده عادةً خلال 30 دقيقة. سيتحوّل الحجز إلى «مؤكّد» تلقائياً.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, height: 1.7, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 26),

                  // Payment summary
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          _row('المبلغ', '500 أوقية'),
                          const SizedBox(height: 8),
                          _row('الوسيلة', 'بنكيلي · Bankily'),
                          const SizedBox(height: 8),
                          _row('المرجع', '#PAY-20418'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Admin responsible
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: state.bgColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: state.color,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            alignment: Alignment.center,
                            child: const Text('إ',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('المسؤول الآن',
                                style: TextStyle(fontSize: 11, color: state.color.withValues(alpha: 0.8))),
                              const Text('الإدارة — تأكيد الدفع',
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

            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 32),
              child: AppButton(
                label: 'عرض تفاصيل الجلسة',
                isOutlined: true,
                onTap: () => context.push('/session/${widget.sessionId}'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
      Text(value,  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
    ],
  );
}
