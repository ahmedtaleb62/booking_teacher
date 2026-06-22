import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/session_states.dart';
import '../../../core/extensions/l10n_extension.dart';
import '../../../core/providers/sessions_provider.dart';
import '../../../core/services/session_service.dart';
import '../../../l10n/app_localizations.dart';

class TeacherRequestDetailScreen extends ConsumerStatefulWidget {
  final String requestId;
  const TeacherRequestDetailScreen({super.key, required this.requestId});
  @override
  ConsumerState<TeacherRequestDetailScreen> createState() => _TeacherRequestDetailScreenState();
}

class _TeacherRequestDetailScreenState extends ConsumerState<TeacherRequestDetailScreen> {
  bool _approving = false;
  bool _rejecting = false;

  Future<void> _approve() async {
    setState(() => _approving = true);
    try {
      await SessionService.approveSession(widget.requestId);
      if (mounted) {
        ref.invalidate(teacherDashboardProvider);
        ref.invalidate(teacherPendingRequestsProvider);
        ref.invalidate(teacherInProgressSessionsProvider);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.l10n.commonError}: $e')));
      }
    } finally {
      if (mounted) setState(() => _approving = false);
    }
  }

  Future<void> _reject([String? reason]) async {
    setState(() => _rejecting = true);
    try {
      await SessionService.rejectSession(widget.requestId, reason: reason);
      if (mounted) {
        ref.invalidate(teacherDashboardProvider);
        ref.invalidate(teacherPendingRequestsProvider);
        ref.invalidate(teacherRejectedSessionsProvider);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.l10n.commonError}: $e')));
      }
    } finally {
      if (mounted) setState(() => _rejecting = false);
    }
  }

  String _formatDate(DateTime dt, AppLocalizations l) {
    final days = [l.daySun, l.dayMon, l.dayTue, l.dayWed, l.dayThu, l.dayFri, l.daySat];
    final h = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final period = dt.hour >= 12 ? l.timePM : l.timeAM;
    return '${days[dt.weekday % 7]} $h:${dt.minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    final l            = context.l10n;
    final sessionAsync = ref.watch(sessionProvider(widget.requestId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.teacherLoadRequestError),
              TextButton(
                onPressed: () => ref.invalidate(sessionProvider(widget.requestId)),
                child: Text(l.commonRetry),
              ),
            ],
          ),
        ),
        data: (session) {
          if (session == null) return Center(child: Text(l.teacherRequestNotFound));

          final isStillPending   = session.state == SessionState.requested;
          const commissionRate   = 0.15;
          final net              = session.amount * (1 - commissionRate);

          return Column(
            children: [
              // AppBar
              Container(
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
                    Text(l.teacherReviewRequestTitle,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      // Status banner
                      if (isStillPending)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3E2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFF8DEB8)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF2994A),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(Icons.access_time_rounded, color: Colors.white, size: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(l.teacherNowResponsible,
                                      style: const TextStyle(fontSize: 11, color: Color(0xFFB07A2A))),
                                    Text(l.teacherStillPending,
                                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                          decoration: BoxDecoration(
                            color: _bannerBg(session.state),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Icon(_bannerIcon(session.state), color: _bannerColor(session.state)),
                              const SizedBox(width: 10),
                              Text(
                                _bannerText(session.state, l),
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 14),

                      // Student card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.accentLight,
                                borderRadius: BorderRadius.circular(13),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                session.studentName.isNotEmpty ? session.studentName[0] : 'ط',
                                style: const TextStyle(color: AppColors.primary,
                                  fontWeight: FontWeight.w700, fontSize: 19),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  session.studentName.isNotEmpty ? session.studentName : l.authStudent,
                                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary)),
                                Text(l.authStudent,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Session details
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            _DetailRow(label: l.teacherSubjectLabel, value: session.subject),
                            const SizedBox(height: 11),
                            if (session.studentLevel != null && session.studentLevel!.isNotEmpty) ...[
                              _DetailRow(label: l.teacherLevelLabel, value: session.studentLevel!),
                              const SizedBox(height: 11),
                            ],
                            _DetailRow(label: l.teacherDateLabel,
                              value: _formatDate(session.scheduledAt, l)),
                            const SizedBox(height: 11),
                            _DetailRow(label: l.teacherDurationLabel,
                              value: l.sessionMinutes(session.durationMinutes)),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 11),
                              child: Divider(height: 1, color: Color(0xFFF0F1F3)),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(l.teacherNetEarning,
                                  style: const TextStyle(fontSize: 13, color: AppColors.textHint)),
                                RichText(
                                  text: TextSpan(
                                    style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic'),
                                    children: [
                                      TextSpan(
                                        text: '${l.sessionOugiya('${net.toInt()}')} ',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                                          color: Color(0xFF1B9E77)),
                                      ),
                                      TextSpan(
                                        text: l.teacherCommissionNote('${session.amount.toInt()}'),
                                        style: const TextStyle(fontSize: 10, color: AppColors.textHint),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Student note
                      if (session.studentNote != null && session.studentNote!.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.teacherStudentNote,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary)),
                              const SizedBox(height: 7),
                              Text(session.studentNote!,
                                style: const TextStyle(fontSize: 12.5,
                                  color: AppColors.textSecondary, height: 1.7)),
                            ],
                          ),
                        ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),

              // Bottom actions — only if still pending
              if (isStillPending)
                Container(
                  color: AppColors.surface,
                  padding: EdgeInsets.only(
                    left: 22, right: 22, top: 13,
                    bottom: MediaQuery.of(context).padding.bottom + 13,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _rejecting ? null : () => _showRejectDialog(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            side: const BorderSide(color: Color(0xFFE6E9ED)),
                            foregroundColor: AppColors.error,
                          ),
                          child: _rejecting
                              ? const SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.error))
                              : Text(l.teacherRejectBtn,
                                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _approving ? null : _approve,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            backgroundColor: const Color(0xFF1B9E77),
                            foregroundColor: Colors.white,
                            elevation: 8,
                            shadowColor: const Color(0xFF1B9E77).withValues(alpha: 0.5),
                          ),
                          child: _approving
                              ? const SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text(l.teacherApproveBtn,
                                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Color _bannerBg(SessionState s) {
    if (s == SessionState.teacherRejected || s == SessionState.cancelled) {
      return const Color(0xFFFDECEC);
    }
    return AppColors.statusApprovedBg;
  }

  Color _bannerColor(SessionState s) {
    if (s == SessionState.teacherRejected || s == SessionState.cancelled) {
      return AppColors.error;
    }
    return AppColors.statusApproved;
  }

  IconData _bannerIcon(SessionState s) {
    if (s == SessionState.teacherRejected || s == SessionState.cancelled) {
      return Icons.cancel_outlined;
    }
    return Icons.check_circle_outline_rounded;
  }

  String _bannerText(SessionState s, AppLocalizations l) {
    switch (s) {
      case SessionState.teacherRejected: return l.teacherRequestRejected;
      case SessionState.cancelled:       return l.teacherRequestCancelledByStudent;
      default:                           return l.teacherRequestProcessed;
    }
  }

  void _showRejectDialog(BuildContext context) {
    final l          = context.l10n;
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l.teacherRejectDialogTitle,
          style: const TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.teacherRejectDialogBody,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: l.teacherRejectReasonHint,
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.textHint),
                filled: true,
                fillColor: AppColors.surfaceAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(11),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.commonCancel)),
          ElevatedButton(
            onPressed: () {
              final reason = reasonCtrl.text.trim();
              Navigator.pop(ctx);
              _reject(reason.isNotEmpty ? reason : null);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: Text(l.commonReject),
          ),
        ],
      ),
    ).whenComplete(reasonCtrl.dispose);
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textHint)),
      Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
        color: AppColors.textPrimary)),
    ],
  );
}
