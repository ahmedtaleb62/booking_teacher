import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';

/// Shows status of a session from the teacher's perspective.
/// Reused for: APPROVED → AWAITING_PAYMENT → PAYMENT_SUBMITTED → CONFIRMED → etc.
class TeacherSessionStatusScreen extends StatelessWidget {
  final String sessionId;
  const TeacherSessionStatusScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _AppBar(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  _StatusHero(),
                  const SizedBox(height: 16),
                  _MiniStepper(),
                  const SizedBox(height: 16),
                  _ResponsibleCard(),
                  const SizedBox(height: 16),
                  _SessionSummaryCard(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
          _BottomAction(sessionId: sessionId),
        ],
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              margin: const EdgeInsets.all(12),
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textPrimary),
            ),
          ),
          const Text('حالة الطلب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _StatusHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF2D6CDF), Color(0xFF1E468F)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text('APPROVED', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
          const SizedBox(height: 11),
          const Text('قبلت الطلب ✓', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 5),
          const Text(
            'في انتظار أن يُكمل الطالب الدفع وتؤكّده الإدارة. لا إجراء مطلوب منك الآن.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFFDCE8FD), height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _MiniStepper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _StepCircle(done: true),
              Expanded(child: Container(height: 3, color: const Color(0xFF1B9E77))),
              _StepCircle(done: true),
              Expanded(child: Container(height: 3, color: const Color(0xFF7B61FF))),
              _StepCircle(active: true, color: const Color(0xFF7B61FF)),
              Expanded(child: Container(height: 3, color: AppColors.border)),
              _StepCircle(),
            ],
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              SizedBox(width: 20, child: Text('طلب', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Color(0xFF1B9E77)), textAlign: TextAlign.center)),
              Spacer(),
              SizedBox(width: 40, child: Text('موافقة', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF15805F)), textAlign: TextAlign.center)),
              Spacer(),
              SizedBox(width: 30, child: Text('دفع', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF5B43D6)), textAlign: TextAlign.center)),
              Spacer(),
              SizedBox(width: 30, child: Text('مؤكّد', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: AppColors.textMuted), textAlign: TextAlign.center)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepCircle extends StatelessWidget {
  final bool done;
  final bool active;
  final Color? color;
  const _StepCircle({this.done = false, this.active = false, this.color});

  @override
  Widget build(BuildContext context) {
    if (done) {
      return Container(
        width: 24, height: 24,
        decoration: const BoxDecoration(color: Color(0xFF1B9E77), shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 13),
      );
    }
    if (active) {
      return Container(
        width: 24, height: 24,
        decoration: BoxDecoration(
          color: color ?? AppColors.primary,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: (color ?? AppColors.primary).withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 2)],
        ),
      );
    }
    return Container(
      width: 24, height: 24,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFD7DCE1), width: 2),
      ),
    );
  }
}

class _ResponsibleCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EDFF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(color: const Color(0xFF7B61FF), borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: const Text('إ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('المسؤول الآن', style: TextStyle(fontSize: 11, color: Color(0xFF8A78D6))),
              Text('الطالب يدفع ← ثم الإدارة تؤكّد',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SessionSummaryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _Row(label: 'الطالب',   value: 'سيدنا أحمد'),
          const SizedBox(height: 10),
          _Row(label: 'الموعد',   value: 'الإثنين 4:00 م · 60 د'),
          const SizedBox(height: 10),
          _Row(label: 'صافي ربحك', value: '425 أوقية', valueColor: const Color(0xFF1B9E77)),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _Row({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textHint)),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: valueColor ?? AppColors.textPrimary)),
      ],
    );
  }
}

class _BottomAction extends StatelessWidget {
  final String sessionId;
  const _BottomAction({required this.sessionId});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.only(
        left: 22, right: 22, top: 14,
        bottom: MediaQuery.of(context).padding.bottom + 14,
      ),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: () {},
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            side: const BorderSide(color: AppColors.borderStrong),
            foregroundColor: AppColors.textSecondary,
          ),
          child: const Text('مراسلة الطالب', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}
