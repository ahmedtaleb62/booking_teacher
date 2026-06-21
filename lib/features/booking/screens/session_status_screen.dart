import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/session_states.dart';
import '../../../core/models/session.dart';
import '../../../core/providers/sessions_provider.dart';
import '../../../core/services/session_service.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/session_stepper.dart';
import '../../../shared/widgets/session_status_badge.dart';

class SessionStatusScreen extends ConsumerStatefulWidget {
  final String sessionId;
  const SessionStatusScreen({super.key, required this.sessionId});

  @override
  ConsumerState<SessionStatusScreen> createState() => _SessionStatusScreenState();
}

class _SessionStatusScreenState extends ConsumerState<SessionStatusScreen> {
  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;
  DateTime? _trackedDeadline;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdownIfNeeded(DateTime deadline) {
    if (_trackedDeadline == deadline) return;
    _trackedDeadline = deadline;
    _countdownTimer?.cancel();
    _remaining = deadline.difference(DateTime.now());
    if (_remaining.isNegative) _remaining = Duration.zero;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final r = deadline.difference(DateTime.now());
      if (mounted) setState(() => _remaining = r.isNegative ? Duration.zero : r);
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(sessionProvider(widget.sessionId));

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
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textHint),
              const SizedBox(height: 12),
              const Text('تعذّر تحميل الجلسة', style: TextStyle(fontSize: 15)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(sessionProvider(widget.sessionId)),
                child: const Text('إعادة المحاولة', style: TextStyle(color: AppColors.primary)),
              ),
            ],
          ),
        ),
        data: (session) {
          if (session == null) {
            return const Center(child: Text('الجلسة غير موجودة'));
          }

          final needsCountdown = session.paymentDeadline != null &&
              (session.state == SessionState.paymentRejected ||
               session.state == SessionState.teacherApproved ||
               session.state == SessionState.awaitingPayment);
          if (needsCountdown) _startCountdownIfNeeded(session.paymentDeadline!);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeroBanner(session),
                const SizedBox(height: 16),
                if (session.state == SessionState.paymentRejected) ...[
                  _buildPaymentRejectedBanner(context, session),
                  const SizedBox(height: 16),
                ],
                if ((session.state == SessionState.teacherApproved ||
                        session.state == SessionState.awaitingPayment) &&
                    session.paymentDeadline != null) ...[
                  _buildPaymentDeadlineBanner(session.paymentDeadline!),
                  const SizedBox(height: 16),
                ],
                SessionStepper(currentState: session.state),
                const SizedBox(height: 14),
                _buildInfoCards(session),
                const SizedBox(height: 16),
                _buildTimeline(session),
                const SizedBox(height: 20),
                _buildActions(context, session),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Payment rejected banner ──────────────────────────────────────

  Widget _buildPaymentRejectedBanner(BuildContext context, Session s) {
    final reason = s.payment?.rejectReason ?? '';
    final isFake = reason.toLowerCase().contains('fake') ||
        reason.contains('مزيف') ||
        reason.contains('fake_proof');

    final mins = _remaining.inMinutes;
    final secs = _remaining.inSeconds % 60;
    final expired = _remaining == Duration.zero;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
              const SizedBox(width: 8),
              const Text('رُفض إثبات الدفع',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
            ],
          ),
          const SizedBox(height: 10),

          // Reason box
          if (reason.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  Icon(
                    isFake ? Icons.report_gmailerrorred_rounded : Icons.money_off_rounded,
                    size: 17, color: const Color(0xFFDC2626),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isFake
                          ? 'إثبات الدفع مزيف — يرجى رفع إثبات حقيقي'
                          : reason,
                      style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: Color(0xFF7F1D1D), height: 1.4),
                    ),
                  ),
                ],
              ),
            ),

          // Instruction
          const SizedBox(height: 10),
          Text(
            isFake
                ? 'يرجى رفع صورة إثبات دفع صحيحة خلال المهلة المحددة.'
                : 'يرجى تسوية المبلغ كاملاً وإعادة رفع الإثبات خلال المهلة.',
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF9B1C1C), height: 1.5),
          ),

          // Countdown
          if (s.paymentDeadline != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: expired ? const Color(0xFFF3F4F6) : const Color(0xFFFFEDD5),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    expired ? Icons.timer_off_rounded : Icons.timer_outlined,
                    size: 15,
                    color: expired ? AppColors.textHint : const Color(0xFFEA580C),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    expired
                        ? 'انتهت المهلة — سيُلغى الطلب تلقائياً'
                        : 'المهلة المتبقية: ${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: expired ? AppColors.textHint : const Color(0xFFEA580C),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // CTA button
          if (!expired) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/payment/${s.id}'),
                icon: const Icon(Icons.upload_file_rounded, size: 18),
                label: const Text('إعادة رفع إثبات الدفع'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Payment deadline banner (shown while awaiting payment) ──────

  Widget _buildPaymentDeadlineBanner(DateTime deadline) {
    final mins    = _remaining.inMinutes;
    final secs    = _remaining.inSeconds % 60;
    final expired = _remaining == Duration.zero;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: expired ? const Color(0xFFF3F4F6) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: expired ? const Color(0xFFD1D5DB) : const Color(0xFFFBBF24)),
      ),
      child: Row(
        children: [
          Icon(
            expired ? Icons.timer_off_rounded : Icons.timer_outlined,
            color: expired ? const Color(0xFF9CA3AF) : const Color(0xFFD97706),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expired ? 'انتهت مهلة الدفع' : 'مهلة إكمال الدفع',
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: expired ? const Color(0xFF6B7280) : const Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  expired
                      ? 'سيُلغى الطلب تلقائياً — تواصل مع الدعم إن احتجت مساعدة'
                      : 'الوقت المتبقي: ${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 12,
                    color: expired ? const Color(0xFF9CA3AF) : const Color(0xFFB45309),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero banner ─────────────────────────────────────────────────

  Widget _buildHeroBanner(Session s) {
    final isConfirmed  = s.state == SessionState.confirmedBooking;
    final isActive     = s.state == SessionState.activeSession;
    final isNegative   = s.state == SessionState.teacherRejected ||
        s.state == SessionState.dispute ||
        s.state == SessionState.teacherNoShow ||
        s.state == SessionState.studentNoShow ||
        s.state == SessionState.paymentRejected;

    Color startColor = s.state.color;
    Color endColor   = s.state.color.withValues(alpha: 0.7);
    if (isConfirmed) { startColor = AppColors.statusConfirmed; endColor = const Color(0xFF15805F); }
    if (isActive)    { startColor = AppColors.statusActive;    endColor = const Color(0xFF15803D); }
    if (isNegative)  { startColor = AppColors.error;           endColor = const Color(0xFF9B2D2D); }

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
              Text('#${s.id.substring(0, 8).toUpperCase()}',
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              Icon(_getIcon(s.state), color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(s.state.label,
                style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 5),
          Text(_getSubtitle(s),
            style: const TextStyle(fontSize: 13, height: 1.6, color: Colors.white70)),
        ],
      ),
    );
  }

  // ── Info cards ──────────────────────────────────────────────────

  Widget _buildInfoCards(Session s) {
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
                Text(_getNextStep(s),
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
                Text(_getResponsible(s.state),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.statusConfirmedText, height: 1.4)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Timeline ────────────────────────────────────────────────────

  Widget _buildTimeline(Session s) {
    if (s.events.isEmpty) return const SizedBox.shrink();
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
                      decoration: const BoxDecoration(color: AppColors.statusConfirmed, shape: BoxShape.circle),
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

  // ── Actions ─────────────────────────────────────────────────────

  Widget _buildActions(BuildContext context, Session s) {
    if (s.state == SessionState.confirmedBooking || s.state == SessionState.activeSession) {
      return AppButton(
        label: s.canEnterSession || s.state == SessionState.activeSession
            ? 'دخول الجلسة'
            : 'الدخول متاح قبل الموعد بـ 10 د',
        color: AppColors.statusActive,
        onTap: (s.canEnterSession || s.state == SessionState.activeSession)
            ? () => context.push('/live/${s.id}')
            : null,
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

    if (s.state == SessionState.paymentRejected) {
      // "Upload again" CTA is already inside the rejection banner.
      // Add a secondary cancel option so the student isn't trapped.
      if (_remaining == Duration.zero) return const SizedBox.shrink();
      return AppButton(
        label: 'إلغاء الجلسة نهائياً',
        isOutlined: true,
        isDanger: true,
        onTap: () => _showCancelDialog(context),
      );
    }

    if (s.state == SessionState.completed) {
      return AppButton(
        label: 'تقييم الأستاذ',
        color: AppColors.statusConfirmed,
        onTap: () => _showRatingDialog(context, s),
      );
    }

    if (s.state == SessionState.teacherNoShow) {
      return Column(
        children: [
          SessionStatusBadge(state: s.state, large: true),
          const SizedBox(height: 12),
          const Text(
            'تم رصد غياب الأستاذ. يمكنك إعادة الجدولة بنفس الدفعة.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, height: 1.6, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          AppButton(
            label: 'إعادة جدولة الجلسة',
            onTap: () => context.push('/reschedule/${s.id}'),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  // ── Dialogs ─────────────────────────────────────────────────────

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إلغاء الطلب'),
        content: const Text('هل أنت متأكد؟ سيتم إلغاء الطلب نهائياً.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('تراجع')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await SessionService.cancelSession(widget.sessionId);
                ref.invalidate(studentSessionsProvider);
                if (context.mounted) context.go('/sessions');
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('خطأ: $e')));
                }
              }
            },
            child: const Text('إلغاء الطلب', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showRatingDialog(BuildContext context, Session s) {
    int rating = 5;
    final commentCtrl = TextEditingController();
    bool sending = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('تقييم الأستاذ', style: TextStyle(fontWeight: FontWeight.w700)),
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
              const SizedBox(height: 12),
              TextField(
                controller: commentCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'تعليق اختياري…',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.all(10),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: sending ? null : () async {
                set(() => sending = true);
                try {
                  await SessionService.submitReview(
                    sessionId: s.id,
                    teacherId: s.teacherId,
                    rating: rating,
                    comment: commentCtrl.text.trim().isEmpty ? null : commentCtrl.text.trim(),
                  );
                  ref.invalidate(studentSessionsProvider);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('شكراً على تقييمك!'),
                        backgroundColor: Color(0xFF1B9E77)));
                  }
                } catch (e) {
                  set(() => sending = false);
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('خطأ: $e')));
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: sending
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('إرسال'),
            ),
          ],
        ),
      ),
    ).whenComplete(commentCtrl.dispose);
  }

  // ── Helpers ─────────────────────────────────────────────────────

  IconData _getIcon(SessionState state) {
    switch (state) {
      case SessionState.requested:        return Icons.access_time_rounded;
      case SessionState.teacherApproved:  return Icons.check_circle_rounded;
      case SessionState.teacherRejected:  return Icons.cancel_rounded;
      case SessionState.awaitingPayment:  return Icons.payment_rounded;
      case SessionState.paymentSubmitted: return Icons.shield_outlined;
      case SessionState.paymentRejected:  return Icons.error_outline_rounded;
      case SessionState.paymentConfirmed: return Icons.verified_rounded;
      case SessionState.confirmedBooking: return Icons.event_available_rounded;
      case SessionState.activeSession:    return Icons.videocam_rounded;
      case SessionState.completed:        return Icons.star_rounded;
      case SessionState.teacherNoShow:
      case SessionState.studentNoShow:    return Icons.person_off_rounded;
      case SessionState.dispute:          return Icons.warning_rounded;
      case SessionState.cancelled:        return Icons.cancel_rounded;
    }
  }

  String _getSubtitle(Session s) {
    switch (s.state) {
      case SessionState.requested:        return 'بانتظار مراجعة الأستاذ ورده على طلبك.';
      case SessionState.teacherApproved:  return 'وافق الأستاذ! أكمل الدفع لتثبيت حجزك.';
      case SessionState.teacherRejected:  return 'رفض الأستاذ الطلب. يمكنك البحث عن أستاذ آخر.';
      case SessionState.awaitingPayment:  return 'الدفع مطلوب لتأكيد الحجز.';
      case SessionState.paymentSubmitted: return 'الإدارة تراجع إثبات الدفع.';
      case SessionState.paymentRejected:  return 'راجع سبب الرفض أدناه وأعد رفع الإثبات.';
      case SessionState.paymentConfirmed: return 'تم تأكيد الدفع من الإدارة.';
      case SessionState.confirmedBooking: return 'الحجز مؤكّد ✓ جلستك جاهزة.';
      case SessionState.activeSession:    return 'الجلسة جارية الآن — ادخل للانضمام.';
      case SessionState.completed:        return 'اكتملت الجلسة بنجاح. يمكنك تقييم الأستاذ.';
      case SessionState.teacherNoShow:    return 'لم يحضر الأستاذ. سنتواصل معك لإعادة الجدولة.';
      case SessionState.studentNoShow:    return 'لم تحضر للجلسة في الوقت المحدد.';
      case SessionState.dispute:          return 'تم فتح نزاع. الإدارة تراجع الحالة.';
      case SessionState.cancelled:        return 'تم إلغاء الجلسة.';
    }
  }

  String _getResponsible(SessionState state) {
    switch (state) {
      case SessionState.requested:        return 'الأستاذ — مراجعة الطلب';
      case SessionState.teacherApproved:
      case SessionState.awaitingPayment:  return 'الطالب — إكمال الدفع';
      case SessionState.paymentSubmitted: return 'الإدارة — تأكيد الدفع';
      case SessionState.paymentRejected:  return 'الطالب — إعادة الإثبات';
      case SessionState.confirmedBooking: return 'لا أحد — بانتظار الموعد';
      case SessionState.activeSession:    return 'الأستاذ والطالب';
      case SessionState.completed:        return 'مكتملة';
      case SessionState.dispute:          return 'الإدارة — حل النزاع';
      default:                            return '—';
    }
  }

  String _getNextStep(Session s) {
    switch (s.state) {
      case SessionState.requested:        return 'انتظر رد الأستاذ';
      case SessionState.teacherApproved:  return 'أكمل الدفع الآن';
      case SessionState.paymentSubmitted: return 'انتظر تأكيد الإدارة';
      case SessionState.paymentRejected:  return 'أعد رفع إثبات الدفع';
      case SessionState.confirmedBooking: return 'تبدأ الجلسة ${_formatDate(s.scheduledAt)}';
      case SessionState.activeSession:    return 'ادخل الجلسة الآن';
      case SessionState.completed:        return 'قيّم الأستاذ';
      default:                            return '—';
    }
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24)   return 'اليوم ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    return '${dt.day}/${dt.month}';
  }

  String _formatDate(DateTime dt) {
    const days = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
    final h = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final period = dt.hour >= 12 ? 'م' : 'ص';
    return '${days[dt.weekday % 7]} $h:${dt.minute.toString().padLeft(2, '0')} $period';
  }
}
