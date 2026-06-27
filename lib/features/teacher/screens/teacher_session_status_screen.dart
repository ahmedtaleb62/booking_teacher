import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/subjects.dart';
import '../../../core/extensions/l10n_extension.dart';
import '../../../core/models/session.dart';
import '../../../core/constants/session_states.dart';
import '../../../core/providers/sessions_provider.dart';
import '../../../core/services/session_service.dart';
import '../../../l10n/app_localizations.dart';

class TeacherSessionStatusScreen extends ConsumerWidget {
  final String sessionId;
  const TeacherSessionStatusScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l     = context.l10n;
    final async = ref.watch(sessionProvider(sessionId));

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
        title: Text(l.teacherSessionStatusTitle),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textHint),
              const SizedBox(height: 12),
              Text(l.sessionLoadError),
              TextButton(
                onPressed: () => ref.invalidate(sessionProvider(sessionId)),
                child: Text(l.commonRetry),
              ),
            ],
          ),
        ),
        data: (session) {
          if (session == null) return Center(child: Text(l.sessionNotFound));
          return _SessionBody(session: session);
        },
      ),
    );
  }
}

class _SessionBody extends StatelessWidget {
  final Session session;
  const _SessionBody({required this.session});

  @override
  Widget build(BuildContext context) {
    final s = session;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 22),
            child: Column(
              children: [
                _HeroBanner(s: s),
                const SizedBox(height: 16),
                _MiniStepper(state: s.state),
                const SizedBox(height: 16),
                _SummaryCard(s: s),
                if (s.events.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _TimelineCard(s: s),
                ],
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
        _BottomAction(session: s),
      ],
    );
  }
}

// ── Hero banner ───────────────────────────────────────────────

class _HeroBanner extends StatelessWidget {
  final Session s;
  const _HeroBanner({required this.s});

  (Color, Color) _gradientColors(SessionState state) {
    switch (state) {
      case SessionState.awaitingPayment:
      case SessionState.teacherApproved:
        return (const Color(0xFF7B61FF), const Color(0xFF4935CC));
      case SessionState.paymentSubmitted:
        return (const Color(0xFFC77A1A), const Color(0xFF8B5A14));
      case SessionState.paymentConfirmed:
      case SessionState.confirmedBooking:
        return (const Color(0xFF1B9E77), const Color(0xFF15805F));
      case SessionState.activeSession:
        return (const Color(0xFF1B6B7A), const Color(0xFF0E4550));
      case SessionState.completed:
        return (const Color(0xFF2D6CDF), const Color(0xFF1E468F));
      case SessionState.dispute:
        return (AppColors.error, const Color(0xFF9B2D2D));
      default:
        return (AppColors.primaryDark, const Color(0xFF0E2A33));
    }
  }

  IconData _stateIcon(SessionState state) {
    switch (state) {
      case SessionState.awaitingPayment:  return Icons.payment_rounded;
      case SessionState.paymentSubmitted: return Icons.shield_outlined;
      case SessionState.paymentConfirmed: return Icons.verified_rounded;
      case SessionState.confirmedBooking: return Icons.event_available_rounded;
      case SessionState.activeSession:    return Icons.videocam_rounded;
      case SessionState.completed:        return Icons.star_rounded;
      case SessionState.dispute:          return Icons.warning_rounded;
      default:                            return Icons.info_outline_rounded;
    }
  }

  String _subtitle(Session session, AppLocalizations l) {
    final state = session.state;
    if (state == SessionState.cancelled) {
      final cr = session.cancellationReason ?? '';
      if (cr == 'fake_proof')          return 'غياب الدفع — الوصل مزيف';
      if (cr == 'insufficient_refund') return 'غياب الدفع — المبلغ غير مكتمل';
      return l.sessionCancelledInfo;
    }
    switch (state) {
      case SessionState.awaitingPayment:  return l.teacherSubAwaitingPayment;
      case SessionState.paymentSubmitted: return l.teacherSubPaymentSubmitted;
      case SessionState.paymentConfirmed: return l.teacherSubPaymentConfirmed;
      case SessionState.confirmedBooking: return l.teacherSubConfirmedBooking;
      case SessionState.activeSession:    return l.teacherSubActiveSession;
      case SessionState.completed:        return l.teacherSubCompleted;
      case SessionState.dispute:          return l.teacherSubDispute;
      case SessionState.teacherNoShow:    return l.teacherStatusNoShow;
      case SessionState.studentNoShow:    return l.teacherStatusStudentNoShow;
      case SessionState.teacherRejected:  return l.teacherSubRejected;
      default:                            return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final (bg1, bg2) = _gradientColors(s.state);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [bg1, bg2],
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
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
              Text('#${s.id.substring(0, 8).toUpperCase()}',
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(_stateIcon(s.state), color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(s.state.label,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 5),
          Text(_subtitle(s, l),
            style: const TextStyle(fontSize: 12.5, color: Colors.white70, height: 1.6)),
        ],
      ),
    );
  }
}

// ── Step indicator ────────────────────────────────────────────

class _MiniStepper extends StatelessWidget {
  final SessionState state;
  const _MiniStepper({required this.state});

  int get _step {
    switch (state) {
      case SessionState.awaitingPayment:
      case SessionState.teacherApproved:  return 1;
      case SessionState.paymentSubmitted:
      case SessionState.paymentConfirmed: return 2;
      case SessionState.confirmedBooking: return 3;
      case SessionState.activeSession:
      case SessionState.completed:        return 4;
      default:                            return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l    = context.l10n;
    final step = _step;
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
              _Dot(done: step > 0, active: step == 0),
              _Line(done: step > 1),
              _Dot(done: step > 1, active: step == 1),
              _Line(done: step > 2),
              _Dot(done: step > 2, active: step == 2),
              _Line(done: step > 3),
              _Dot(done: step > 3, active: step == 3),
              _Line(done: step > 4),
              _Dot(done: step > 4, active: step == 4),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(width: 24, child: Text(l.stepRequest,  style: _stepStyle, textAlign: TextAlign.center)),
              const Spacer(),
              SizedBox(width: 30, child: Text(l.stepApproval, style: _stepStyle, textAlign: TextAlign.center)),
              const Spacer(),
              SizedBox(width: 28, child: Text(l.stepPayment,  style: _stepStyle, textAlign: TextAlign.center)),
              const Spacer(),
              SizedBox(width: 28, child: Text(l.stepConfirmed,style: _stepStyle, textAlign: TextAlign.center)),
              const Spacer(),
              SizedBox(width: 28, child: Text(l.stepCompleted,style: _stepStyle, textAlign: TextAlign.center)),
            ],
          ),
        ],
      ),
    );
  }

  static const _stepStyle = TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: AppColors.textHint);
}

class _Dot extends StatelessWidget {
  final bool done;
  final bool active;
  const _Dot({this.done = false, this.active = false});

  @override
  Widget build(BuildContext context) {
    if (done) {
      return Container(
        width: 22, height: 22,
        decoration: const BoxDecoration(color: Color(0xFF1B9E77), shape: BoxShape.circle),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 12),
      );
    }
    if (active) {
      return Container(
        width: 22, height: 22,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 2)],
        ),
      );
    }
    return Container(
      width: 22, height: 22,
      decoration: BoxDecoration(
        color: AppColors.surface,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.borderStrong, width: 2),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  final bool done;
  const _Line({required this.done});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(height: 3, color: done ? const Color(0xFF1B9E77) : AppColors.border),
  );
}

// ── Session summary ───────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final Session s;
  const _SummaryCard({required this.s});

  String _fmtDate(DateTime dt, AppLocalizations l) {
    final days = [l.daySun, l.dayMon, l.dayTue, l.dayWed, l.dayThu, l.dayFri, l.daySat];
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? l.timePM : l.timeAM;
    return '${days[dt.weekday % 7]} $h:${dt.minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    final l   = context.l10n;
    final net = s.amount * 0.85;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _Row(label: l.teacherStudentLabel, value: s.studentName.isNotEmpty ? s.studentName : l.authStudent),
          const Divider(height: 18),
          _Row(label: l.teacherSubjectLabel,  value: translateSubject(s.subject, Localizations.localeOf(context))),
          const SizedBox(height: 10),
          _Row(label: l.sessionDate,          value: '${_fmtDate(s.scheduledAt, l)} · ${l.dashMinutesShort(s.durationMinutes)}'),
          const SizedBox(height: 10),
          _Row(label: l.sessionAmountLabel,   value: l.sessionOugiya('${s.amount.toInt()}')),
          const SizedBox(height: 10),
          _Row(label: l.teacherNetEarning,    value: l.sessionOugiya('${net.toInt()}'),
            valueColor: const Color(0xFF1B9E77)),
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
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.textHint)),
      Text(value, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700,
        color: valueColor ?? AppColors.textPrimary)),
    ],
  );
}

// ── Timeline ──────────────────────────────────────────────────

class _TimelineCard extends StatelessWidget {
  final Session s;
  const _TimelineCard({required this.s});

  String _fmtTime(DateTime dt, AppLocalizations l) {
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

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
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
          const SizedBox(height: 12),
          ...s.events.asMap().entries.map((e) {
            final isLast = e.key == s.events.length - 1;
            final event  = e.value;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 10, height: 10,
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    ),
                    if (!isLast) Container(width: 2, height: 28, color: AppColors.border),
                  ],
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(event.teacherLabelFor(l),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                        Text(_fmtTime(event.createdAt, l),
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
}

// ── Bottom action button ──────────────────────────────────────

class _BottomAction extends StatefulWidget {
  final Session session;
  const _BottomAction({required this.session});

  @override
  State<_BottomAction> createState() => _BottomActionState();
}

class _BottomActionState extends State<_BottomAction> {
  bool _cancelling = false;

  Future<void> _cancelOrDispute(bool isDispute) async {
    final l      = context.l10n;
    final action = isDispute ? l.teacherOpenDispute : l.teacherCancelSession;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(action, style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Text(isDispute ? l.teacherDisputeDialogContent : l.teacherCancelSessionContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.dialogBack)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: Text(action),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      await SessionService.teacherCancelOrDispute(widget.session.id);
      if (mounted) context.go('/teacher/sessions');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.l10n.commonError}: $e')));
        setState(() => _cancelling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = widget.session;

    // ── CONFIRMED or ACTIVE ───────────────────────────────────
    if (s.state == SessionState.confirmedBooking ||
        s.state == SessionState.activeSession) {
      final canEnter = s.canEnterSession || s.state == SessionState.activeSession;
      return _wrap(context, SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: canEnter ? () => context.push('/teacher/live/${s.id}') : null,
          icon: const Icon(Icons.videocam_rounded, size: 18),
          label: Text(
            canEnter ? 'دخول الجلسة' : l.teacherSessionEntryNote,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            backgroundColor: canEnter ? const Color(0xFF1B9E77) : AppColors.textHint,
            foregroundColor: Colors.white,
          ),
        ),
      ));
    }

    // ── AWAITING / SUBMITTED: can cancel ─────────────────────
    if (s.state == SessionState.awaitingPayment ||
        s.state == SessionState.paymentSubmitted) {
      return _wrap(context, SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _cancelling ? null : () => _cancelOrDispute(false),
          icon: _cancelling
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.error))
              : const Icon(Icons.cancel_outlined, size: 16),
          label: Text(
            _cancelling ? l.teacherCancellingMsg : l.teacherCancelSession,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
            foregroundColor: AppColors.error,
          ),
        ),
      ));
    }

    // ── PAYMENT_CONFIRMED: preparing booking automatically ────
    if (s.state == SessionState.paymentConfirmed) {
      return _wrap(context, Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFD1FAE5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF6EE7B7)),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF065F46)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l.teacherPaymentConfirmedWaiting,
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF065F46), height: 1.5),
              ),
            ),
          ],
        ),
      ));
    }

    // ── CANCELLED: show reason to teacher ────────────────────────
    if (s.state == SessionState.cancelled) {
      final cr = s.cancellationReason ?? '';
      final isPaymentIssue = cr == 'fake_proof' || cr == 'insufficient_refund';
      if (isPaymentIssue) {
        return _wrap(context, Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFBBF24)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.payments_outlined, color: Color(0xFF92400E), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('غياب الدفع — الجلسة ملغاة',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF92400E))),
                    const SizedBox(height: 4),
                    Text(
                      cr == 'fake_proof'
                          ? 'رُفض إثبات دفع الطالب لأنه غير حقيقي.'
                          : 'المبلغ المدفوع من الطالب كان أقل من المطلوب.',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF92400E), height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ));
      }
    }

    return const SizedBox.shrink();
  }

  Widget _wrap(BuildContext context, Widget child) => Container(
    color: AppColors.surface,
    padding: EdgeInsets.only(
      left: 22, right: 22, top: 14,
      bottom: MediaQuery.of(context).padding.bottom + 14,
    ),
    child: child,
  );
}
