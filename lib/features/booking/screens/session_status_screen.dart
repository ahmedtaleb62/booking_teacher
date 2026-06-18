import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/session_states.dart';
import '../../../core/models/session.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/session_stepper.dart';
import '../../../shared/widgets/session_status_badge.dart';

class SessionStatusScreen extends StatelessWidget {
  final String sessionId;
  const SessionStatusScreen({super.key, required this.sessionId});

  Session get _session => MockSessions.list.firstWhere(
    (s) => s.id == sessionId,
    orElse: () => MockSessions.list.first,
  );

  @override
  Widget build(BuildContext context) {
    final s = _session;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.textPrimary),
          ),
          onPressed: () => context.pop(),
        ),
        title: const Text('حالة الجلسة'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroBanner(s),
            const SizedBox(height: 16),
            SessionStepper(currentState: s.state),
            const SizedBox(height: 14),
            _buildInfoCards(s),
            const SizedBox(height: 16),
            _buildTimeline(s),
            const SizedBox(height: 20),
            _buildActions(context, s),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner(Session s) {
    final isConfirmed = s.state == SessionState.confirmedBooking;
    final isActive    = s.state == SessionState.activeSession;
    final isRejected  = s.state == SessionState.teacherRejected;
    final isDispute   = s.state == SessionState.dispute;
    final isNoShow    = s.state == SessionState.teacherNoShow || s.state == SessionState.studentNoShow;

    Color startColor = s.state.color;
    Color endColor   = s.state.color.withValues(alpha: 0.7);
    if (isConfirmed) { startColor = AppColors.statusConfirmed; endColor = const Color(0xFF15805F); }
    if (isActive)    { startColor = AppColors.statusActive;    endColor = const Color(0xFF15803D); }
    if (isRejected || isDispute || isNoShow) {
      startColor = AppColors.error; endColor = const Color(0xFF9B2D2D);
    }

    String title = s.state.label;
    String subtitle = _getSubtitle(s);
    IconData icon = _getIcon(s.state);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [startColor, endColor],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(s.state.englishKey,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.3)),
              ),
              Text('#${s.id.toUpperCase()}',
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(title,
                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 5),
          Text(subtitle,
            style: const TextStyle(fontSize: 13, height: 1.6, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildInfoCards(Session s) {
    String responsible = _getResponsible(s.state);
    String nextStep    = _getNextStep(s);

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('الخطوة التالية',
                  style: TextStyle(fontSize: 10.5, color: AppColors.textHint)),
                const SizedBox(height: 4),
                Text(nextStep,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary, height: 1.4)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.statusConfirmedBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.statusConfirmed.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('المسؤول الآن',
                  style: TextStyle(fontSize: 10.5, color: AppColors.statusConfirmed.withValues(alpha: 0.8))),
                const SizedBox(height: 4),
                Text(responsible,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.statusConfirmedText, height: 1.4)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeline(Session s) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('سجل الجلسة',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 13),
          ...s.events.asMap().entries.map((e) {
            final isLast = e.key == s.events.length - 1;
            final event  = e.value;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 11, height: 11,
                      decoration: BoxDecoration(
                        color: AppColors.statusConfirmed,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (!isLast)
                      Container(width: 2, height: 30, color: AppColors.border),
                  ],
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(event.label,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        Text(_formatTime(event.createdAt),
                          style: const TextStyle(fontSize: 10.5, color: AppColors.textHint)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, Session s) {
    if (s.state == SessionState.confirmedBooking) {
      return Column(
        children: [
          Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.textSecondary, size: 20),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: AppButton(
                  label: s.canEnterSession ? 'دخول الجلسة' : 'الدخول متاح قبل الموعد بـ 10 د',
                  color: s.canEnterSession ? AppColors.statusActive : null,
                  onTap: s.canEnterSession ? () => context.push('/live/${s.id}') : null,
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (s.state == SessionState.requested) {
      return AppButton(
        label: 'إلغاء الطلب',
        isOutlined: true,
        isDanger: true,
        onTap: () => _showCancelDialog(context),
      );
    }

    if (s.state == SessionState.awaitingPayment || s.state == SessionState.teacherApproved) {
      return AppButton(
        label: 'إكمال الدفع',
        onTap: () => context.push('/payment/${s.id}'),
      );
    }

    if (s.state == SessionState.completed) {
      return AppButton(
        label: 'تقييم الأستاذ',
        color: AppColors.statusConfirmed,
        onTap: () => _showRatingDialog(context),
      );
    }

    if (s.state == SessionState.teacherNoShow) {
      return Column(
        children: [
          SessionStatusBadge(state: s.state, large: true),
          const SizedBox(height: 12),
          const Text(
            'تم رصد غياب الأستاذ. سيتم إعادة جدولة الجلسة تلقائياً أو استرداد دفعتك.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.6, color: AppColors.textSecondary),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إلغاء الطلب'),
        content: const Text('هل أنت متأكد؟ سيتم إلغاء الطلب نهائياً.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('تراجع')),
          TextButton(
            onPressed: () { Navigator.pop(context); context.go('/sessions'); },
            child: const Text('إلغاء الطلب', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showRatingDialog(BuildContext context) {
    int rating = 5;
    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (_, set) => AlertDialog(
          title: const Text('تقييم الأستاذ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) => GestureDetector(
                  onTap: () => set(() => rating = i + 1),
                  child: Icon(Icons.star_rounded, size: 36,
                    color: i < rating ? const Color(0xFFF59E0B) : AppColors.border),
                )),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إرسال')),
          ],
        ),
      ),
    );
  }

  String _getSubtitle(Session s) {
    switch (s.state) {
      case SessionState.requested:         return 'بانتظار مراجعة الأستاذ ورده على طلبك.';
      case SessionState.teacherApproved:   return 'وافق الأستاذ! أكمل الدفع لتثبيت حجزك.';
      case SessionState.teacherRejected:   return 'رفض الأستاذ الطلب. يمكنك البحث عن أستاذ آخر.';
      case SessionState.awaitingPayment:   return 'الدفع مطلوب لتأكيد الحجز.';
      case SessionState.paymentSubmitted:  return 'الإدارة تراجع إثبات الدفع.';
      case SessionState.paymentConfirmed:  return 'تم تأكيد الدفع من الإدارة.';
      case SessionState.confirmedBooking:  return 'الحجز مؤكّد ✓ جلستك جاهزة وتبدأ تلقائياً في موعدها.';
      case SessionState.activeSession:     return 'الجلسة جارية الآن — ادخل للانضمام.';
      case SessionState.completed:         return 'اكتملت الجلسة بنجاح. يمكنك تقييم الأستاذ.';
      case SessionState.teacherNoShow:     return 'لم يحضر الأستاذ. سنتواصل معك لإعادة الجدولة.';
      case SessionState.studentNoShow:     return 'لم تحضر للجلسة في الوقت المحدد.';
      case SessionState.dispute:           return 'تم فتح نزاع. الإدارة تراجع الحالة.';
      case SessionState.cancelled:         return 'تم إلغاء الجلسة.';
    }
  }

  IconData _getIcon(SessionState state) {
    switch (state) {
      case SessionState.requested:         return Icons.access_time_rounded;
      case SessionState.teacherApproved:   return Icons.check_circle_rounded;
      case SessionState.teacherRejected:   return Icons.cancel_rounded;
      case SessionState.awaitingPayment:   return Icons.payment_rounded;
      case SessionState.paymentSubmitted:  return Icons.shield_outlined;
      case SessionState.paymentConfirmed:  return Icons.verified_rounded;
      case SessionState.confirmedBooking:  return Icons.event_available_rounded;
      case SessionState.activeSession:     return Icons.videocam_rounded;
      case SessionState.completed:         return Icons.star_rounded;
      case SessionState.teacherNoShow:     return Icons.person_off_rounded;
      case SessionState.studentNoShow:     return Icons.person_off_rounded;
      case SessionState.dispute:           return Icons.warning_rounded;
      case SessionState.cancelled:         return Icons.cancel_rounded;
    }
  }

  String _getResponsible(SessionState state) {
    switch (state) {
      case SessionState.requested:         return 'الأستاذ — مراجعة الطلب';
      case SessionState.teacherApproved:
      case SessionState.awaitingPayment:   return 'الطالب — إكمال الدفع';
      case SessionState.paymentSubmitted:  return 'الإدارة — تأكيد الدفع';
      case SessionState.paymentConfirmed:
      case SessionState.confirmedBooking:  return 'لا أحد — بانتظار الموعد';
      case SessionState.activeSession:     return 'الأستاذ والطالب';
      case SessionState.completed:         return 'مكتملة';
      case SessionState.dispute:           return 'الإدارة — حل النزاع';
      default:                             return '—';
    }
  }

  String _getNextStep(Session s) {
    switch (s.state) {
      case SessionState.requested:        return 'انتظر رد الأستاذ';
      case SessionState.teacherApproved:  return 'أكمل الدفع الآن';
      case SessionState.paymentSubmitted: return 'انتظر تأكيد الإدارة';
      case SessionState.confirmedBooking: return 'تبدأ الجلسة ${_formatDate(s.scheduledAt)}';
      case SessionState.activeSession:    return 'ادخل الجلسة الآن';
      case SessionState.completed:        return 'قيّم الأستاذ';
      default:                            return '—';
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24)   return 'اليوم ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    return '${dt.day}/${dt.month}';
  }

  String _formatDate(DateTime dt) {
    final days = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
    final h = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final period = dt.hour >= 12 ? 'م' : 'ص';
    return '${days[dt.weekday % 7]} $h:${dt.minute.toString().padLeft(2, '0')} $period';
  }
}
