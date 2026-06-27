import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/session_states.dart';
import '../../../core/extensions/l10n_extension.dart';
import '../../../core/models/session.dart';
import '../../../core/providers/sessions_provider.dart';
import '../../../core/services/session_service.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/session_stepper.dart';

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
  bool _rated = false;

  @override
  void initState() {
    super.initState();
    _checkIfAlreadyRated();
  }

  Future<void> _checkIfAlreadyRated() async {
    try {
      final rated = await SessionService.hasReviewedSession(widget.sessionId);
      if (mounted && rated) setState(() => _rated = true);
    } catch (_) {}
  }

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
    final l = context.l10n;
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
          onPressed: () => context.canPop() ? context.pop() : context.go('/sessions'),
        ),
        title: Text(l.sessionStatusTitle),
      ),
      body: SafeArea(
        top: false,
        child: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textHint),
              const SizedBox(height: 12),
              Text(l.sessionLoadError, style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(sessionProvider(widget.sessionId)),
                child: Text(l.commonRetry, style: const TextStyle(color: AppColors.primary)),
              ),
            ],
          ),
        ),
        data: (session) {
          if (session == null) {
            return Center(child: Text(l.sessionNotFound));
          }

          final needsCountdown = session.paymentDeadline != null &&
              (session.state == SessionState.teacherApproved ||
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
      ),
    );
  }

  // ── Payment rejected banner ──────────────────────────────────────
  // Both rejection reasons (FAKE_PROOF / INCOMPLETE_AMOUNT) now cancel the session
  // immediately — no retry window, no countdown. Student is informed and can re-book.

  Widget _buildPaymentRejectedBanner(BuildContext context, Session s) {
    final l = context.l10n;
    final reason = (s.payment?.rejectReason ?? '').toUpperCase();
    final isFake = reason.contains('FAKE');

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
          Row(
            children: [
              Icon(
                isFake ? Icons.report_gmailerrorred_rounded : Icons.money_off_rounded,
                color: const Color(0xFFDC2626), size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                isFake ? l.paymentFakeProofLabel : l.paymentIncompleteLabel,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isFake
                ? l.paymentFakeInstruction
                : l.cancelledInsufficientBody,
            style: const TextStyle(fontSize: 13, color: Color(0xFF9B1C1C), height: 1.5),
          ),
        ],
      ),
    );
  }

  // ── Payment deadline banner ──────────────────────────────────────

  Widget _buildPaymentDeadlineBanner(DateTime deadline) {
    final l = context.l10n;
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
                  expired ? l.paymentDeadlineExpired : l.paymentDeadlineLabel,
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: expired ? const Color(0xFF6B7280) : const Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  expired
                      ? l.paymentDeadlineContactSupport
                      : l.paymentTimeLabel('${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}'),
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
    final l = context.l10n;
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
                Text(l.sessionNextStep,
                  style: const TextStyle(fontSize: 10.5, color: AppColors.textHint)),
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
                Text(l.sessionResponsible,
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
    final l = context.l10n;
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
          Text(l.sessionHistory,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
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
                        Text(event.labelFor(l),
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
    final l = context.l10n;

    if (s.state == SessionState.activeSession) {
      return AppButton(
        label: l.actionEnterNow,
        color: const Color(0xFF059669),
        leading: const Icon(Icons.circle, color: Colors.white, size: 8),
        onTap: () => context.push('/live/${s.id}'),
      );
    }

    if (s.state == SessionState.confirmedBooking) {
      return AppButton(
        label: s.canEnterSession ? l.actionEnterSession : l.actionEnterIn10,
        color: AppColors.statusActive,
        onTap: s.canEnterSession ? () => context.push('/live/${s.id}') : null,
      );
    }

    if (s.state == SessionState.requested) {
      return AppButton(
        label: l.actionCancelRequest,
        isOutlined: true,
        isDanger: true,
        onTap: () => _showCancelDialog(context),
      );
    }

    if (s.state == SessionState.awaitingPayment || s.state == SessionState.teacherApproved) {
      final deadlineExpired = s.paymentDeadline != null && _remaining == Duration.zero;
      if (deadlineExpired) {
        return _buildInfoBanner(
          icon: Icons.timer_off_rounded,
          message: l.paymentDeadlineExpiredAction,
          color: const Color(0xFF9CA3AF),
          bgColor: const Color(0xFFF3F4F6),
        );
      }
      return AppButton(
        label: l.actionCompletePayment,
        onTap: () => context.push('/payment/${s.id}'),
      );
    }

    if (s.state == SessionState.completed) {
      return Column(
        children: [
          if (_rated)
            _buildInfoBanner(
              icon: Icons.check_circle_outline_rounded,
              message: l.sessionRatingThanks,
              color: AppColors.statusConfirmed,
              bgColor: AppColors.statusConfirmedBg,
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'كيف كانت جلستك؟',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'جيدة — قيم الأستاذ ⭐',
                    color: AppColors.statusConfirmed,
                    onTap: () => _showRatingDialog(context, s),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _openWhatsApp,
                      icon: const Icon(Icons.chat_rounded, size: 16),
                      label: const Text(
                        'واجهت مشاكل — تواصل معنا',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: const BorderSide(color: Color(0xFF25D366)),
                        foregroundColor: const Color(0xFF25D366),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 10),
          AppButton(
            label: l.actionViewChat,
            color: const Color(0xFF7B61FF),
            leading: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 17),
            onTap: () => context.push('/session-history/${s.id}'),
          ),
        ],
      );
    }

    if (s.state == SessionState.paymentConfirmed) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.statusConfirmedBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.statusConfirmed.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(
                  width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: AppColors.statusConfirmed),
                ),
                const SizedBox(width: 10),
                Text(l.paymentConfirmedTitle,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                    color: AppColors.statusConfirmedText)),
              ],
            ),
            const SizedBox(height: 8),
            Text(l.paymentConfirmedInfo,
              style: const TextStyle(fontSize: 12.5, color: AppColors.statusConfirmedText, height: 1.5)),
          ],
        ),
      );
    }

    if (s.state == SessionState.teacherRejected) {
      return Column(
        children: [
          _buildInfoBanner(
            icon: Icons.cancel_outlined,
            message: l.sessionTeacherRejectedInfo,
            color: AppColors.error,
            bgColor: const Color(0xFFFDECEC),
          ),
          const SizedBox(height: 12),
          AppButton(label: l.sessionReturnSearch, onTap: () => context.go('/home')),
        ],
      );
    }

    if (s.state == SessionState.cancelled) {
      return _buildCancelledSection(context, s);
    }

    if (s.state == SessionState.studentNoShow) {
      return _buildInfoBanner(
        icon: Icons.info_outline_rounded,
        message: l.sessionStudentAbsentInfo,
        color: const Color(0xFFC77A1A),
        bgColor: const Color(0xFFFEF3E2),
      );
    }

    if (s.state == SessionState.dispute) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFDECEC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFCA5A5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.policy_outlined, color: AppColors.error, size: 18),
                const SizedBox(width: 8),
                Text(l.sessionDisputeTitle,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.error)),
              ],
            ),
            const SizedBox(height: 8),
            Text(l.sessionDisputeInfo,
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF7F1D1D), height: 1.5)),
            const SizedBox(height: 10),
            Text(l.sessionDisputeNextStep,
              style: const TextStyle(fontSize: 12, color: Color(0xFF9B1C1C), height: 1.5,
                fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    if (s.state == SessionState.teacherNoShow) {
      final alreadyRescheduled = s.events.any((e) => e.eventType == 'RESCHEDULED');
      if (alreadyRescheduled) {
        return _buildInfoBanner(
          icon: Icons.check_circle_outline_rounded,
          message: l.sessionRescheduledSuccess,
          color: AppColors.statusConfirmed,
          bgColor: AppColors.statusConfirmedBg,
        );
      }

      if (s.hasRefundRequested) {
        return _buildInfoBanner(
          icon: Icons.hourglass_top_rounded,
          message: l.sessionRefundPendingMsg,
          color: const Color(0xFF7B61FF),
          bgColor: const Color(0xFFF0EDFF),
        );
      }

      return Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Column(
              children: [
                const Icon(Icons.person_off_rounded, color: AppColors.error, size: 36),
                const SizedBox(height: 10),
                Text(
                  l.sessionTeacherNoShowInfo,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, height: 1.6, color: Color(0xFF7F1D1D)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/reschedule/${s.id}'),
                  icon: const Icon(Icons.calendar_today_rounded, size: 16),
                  label: Text(l.actionReschedule),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: AppColors.primary),
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showRefundDialog(context, s),
                  icon: const Icon(Icons.account_balance_wallet_outlined, size: 16),
                  label: Text(l.actionRequestRefund),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    backgroundColor: const Color(0xFF7B61FF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  // ── Cancelled sub-reason section ────────────────────────────────

  Widget _buildCancelledSection(BuildContext context, Session s) {
    final l      = context.l10n;
    final reason = s.cancellationReason ?? '';
    final bool withRefund = reason == 'teacher_no_show_refund' || reason == 'insufficient_refund';

    final (IconData icon, String title, String body, Color color, Color bg) = switch (reason) {
      'no_payment_deadline' => (
        Icons.timer_off_rounded,
        l.cancelledNoPaymentTitle,
        l.cancelledNoPaymentBody,
        AppColors.error,
        const Color(0xFFFDECEC),
      ),
      'fake_proof' => (
        Icons.gpp_bad_rounded,
        l.cancelledFakeProofTitle,
        l.cancelledFakeProofBody,
        AppColors.error,
        const Color(0xFFFDECEC),
      ),
      'insufficient_refund' => (
        Icons.account_balance_wallet_outlined,
        l.cancelledInsufficientTitle,
        l.cancelledInsufficientBody,
        const Color(0xFF7B61FF),
        const Color(0xFFF0EDFF),
      ),
      'teacher_no_show_refund' => (
        Icons.account_balance_wallet_rounded,
        l.cancelledNoShowRefundTitle,
        l.cancelledNoShowRefundBody,
        const Color(0xFF059669),
        const Color(0xFFD1FAE5),
      ),
      _ => (
        Icons.cancel_outlined,
        l.cancelledDefaultTitle,
        l.cancelledDefaultBody,
        AppColors.error,
        const Color(0xFFFDECEC),
      ),
    };

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
                ),
              ]),
              const SizedBox(height: 8),
              Text(body,
                style: TextStyle(fontSize: 12.5, color: color, height: 1.5)),
              if (withRefund) ...[
                const SizedBox(height: 10),
                Row(children: [
                  Icon(Icons.check_circle_outline_rounded,
                    color: const Color(0xFF059669), size: 14),
                  const SizedBox(width: 6),
                  Expanded(child: Text(l.cancelledAutoDeposit,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF059669), fontWeight: FontWeight.w600))),
                ]),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppButton(label: l.sessionNewSession, onTap: () => context.go('/home')),
      ],
    );
  }

  // ── WhatsApp support ────────────────────────────────────────────

  Future<void> _openWhatsApp() async {
    final uri = Uri.parse('https://wa.me/22242740370');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  // ── Dialogs ─────────────────────────────────────────────────────

  void _showRefundDialog(BuildContext context, Session s) {
    final l = context.l10n;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(children: [
          const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFF7B61FF), size: 22),
          const SizedBox(width: 8),
          Text(l.dialogRefundTitle,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ]),
        content: Text(
          l.dialogRefundContent,
          style: const TextStyle(fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.dialogBack2),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await SessionService.requestRefund(s.id);
                ref.invalidate(sessionProvider(s.id));
                ref.invalidate(studentSessionsProvider);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7B61FF),
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: Text(l.actionConfirmRequest),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context) {
    final l = context.l10n;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.actionCancelRequest),
        content: Text(l.dialogCancelConfirmText2),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l.dialogBack2)),
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
                    SnackBar(content: Text('$e')));
                }
              }
            },
            child: Text(l.actionCancelRequest, style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showRatingDialog(BuildContext context, Session s) {
    final l = context.l10n;
    int rating = 5;
    final commentCtrl = TextEditingController();
    bool sending = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(l.dialogRatingTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
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
                  hintText: l.dialogRatingCommentOptional,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.all(10),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.commonCancel)),
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
                  if (mounted) setState(() => _rated = true);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l.ratingThanksSnackbar),
                        backgroundColor: const Color(0xFF1B9E77)));
                  }
                } catch (e) {
                  set(() => sending = false);
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('$e')));
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
              child: sending
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(l.commonSend),
            ),
          ],
        ),
      ),
    ).whenComplete(commentCtrl.dispose);
  }

  // ── Helpers ─────────────────────────────────────────────────────

  Widget _buildInfoBanner({
    required IconData icon,
    required String message,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
              style: TextStyle(fontSize: 12.5, color: color, height: 1.5)),
          ),
        ],
      ),
    );
  }

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
    final l = context.l10n;
    switch (s.state) {
      case SessionState.requested:        return l.subRequested;
      case SessionState.teacherApproved:  return l.subTeacherApproved;
      case SessionState.teacherRejected:  return l.subTeacherRejected;
      case SessionState.awaitingPayment:  return l.subAwaitingPayment;
      case SessionState.paymentSubmitted: return l.subPaymentSubmitted;
      case SessionState.paymentRejected:  return l.subPaymentRejected;
      case SessionState.paymentConfirmed: return l.subPaymentConfirmed;
      case SessionState.confirmedBooking: return l.subConfirmedBooking;
      case SessionState.activeSession:    return l.subActiveSession;
      case SessionState.completed:        return l.subCompleted;
      case SessionState.teacherNoShow:    return l.subTeacherNoShow;
      case SessionState.studentNoShow:    return l.sessionStudentAbsentInfo;
      case SessionState.dispute:          return l.subDispute;
      case SessionState.cancelled:        return l.subCancelled;
    }
  }

  String _getResponsible(SessionState state) {
    final l = context.l10n;
    switch (state) {
      case SessionState.requested:        return l.respTeacherReview;
      case SessionState.teacherApproved:
      case SessionState.awaitingPayment:  return l.respStudent;
      case SessionState.paymentSubmitted: return l.respAdmin;
      case SessionState.paymentConfirmed: return l.respAdminConfirm;
      case SessionState.confirmedBooking: return l.respNoneWaiting;
      case SessionState.activeSession:    return l.respBothJoin;
      case SessionState.completed:        return l.respCompleted;
      case SessionState.dispute:          return l.respAdminDispute;
      default:                            return l.respNone;
    }
  }

  String _getNextStep(Session s) {
    final l = context.l10n;
    switch (s.state) {
      case SessionState.requested:        return l.nextWaitTeacher;
      case SessionState.teacherApproved:
      case SessionState.awaitingPayment:  return l.nextCompletePayment;
      case SessionState.paymentSubmitted: return l.nextWaitAdmin;
      case SessionState.paymentConfirmed: return l.nextWaitAdminConfirm;
      case SessionState.confirmedBooking: return l.sessionStartDate(_formatDate(s.scheduledAt));
      case SessionState.activeSession:    return l.nextEnterSession;
      case SessionState.completed:        return _rated ? l.nextRated : l.nextRateTeacher;
      case SessionState.teacherRejected:  return l.nextFindTeacher;
      case SessionState.teacherNoShow:    return l.nextReschedule;
      case SessionState.dispute:          return l.nextWaitDecision;
      default:                            return l.respNone;
    }
  }

  String _formatTime(DateTime dt) {
    final l = context.l10n;
    final now  = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return l.timeMinutesAgo(diff.inMinutes);
    final hhmm = '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    final isToday     = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final yesterday   = now.subtract(const Duration(days: 1));
    final isYesterday = dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day;
    if (isToday)     return '${l.timeToday} $hhmm';
    if (isYesterday) return '${l.timeYesterday} $hhmm';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _formatDate(DateTime dt) {
    final l = context.l10n;
    final days = [l.daySun, l.dayMon, l.dayTue, l.dayWed, l.dayThu, l.dayFri, l.daySat];
    final h = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final period = dt.hour >= 12 ? l.timePM : l.timeAM;
    return '${days[dt.weekday % 7]} $h:${dt.minute.toString().padLeft(2, '0')} $period';
  }
}
