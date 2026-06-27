import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/l10n_extension.dart';
import '../../../core/providers/courses_provider.dart';
import '../../../core/services/supabase_service.dart';

class SubscriptionPendingScreen extends ConsumerStatefulWidget {
  final String subscriptionId;
  const SubscriptionPendingScreen({super.key, required this.subscriptionId});

  @override
  ConsumerState<SubscriptionPendingScreen> createState() =>
      _SubscriptionPendingScreenState();
}

class _SubscriptionPendingScreenState
    extends ConsumerState<SubscriptionPendingScreen> {
  RealtimeChannel? _channel;
  bool _activated = false;
  bool _rejected = false;
  bool _cancelled = false;
  String? _rejectReason;
  String? _cancellationReason;
  String? _courseId;
  String? _packageId;

  @override
  void initState() {
    super.initState();
    _checkCurrentStatus();
    _subscribeToChanges();
  }

  Future<void> _checkCurrentStatus() async {
    try {
      final row = await SupabaseService.client
          .from('subscriptions')
          .select('status, reject_reason, cancellation_reason, course_id, package_id')
          .eq('id', widget.subscriptionId)
          .maybeSingle();
      if (!mounted || row == null) return;
      _applyStatus(row);
    } catch (_) {}
  }

  void _applyStatus(Map<String, dynamic> row) {
    final status = row['status'] as String?;
    if (status == 'active') {
      ref.invalidate(mySubscriptionsProvider);
      setState(() => _activated = true);
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) context.go('/my-courses');
      });
    } else if (status == 'rejected') {
      ref.invalidate(mySubscriptionsProvider);
      setState(() {
        _rejected = true;
        _rejectReason = row['reject_reason'] as String?;
        _courseId = row['course_id'] as String?;
        _packageId = row['package_id'] as String?;
      });
    } else if (status == 'cancelled') {
      ref.invalidate(mySubscriptionsProvider);
      setState(() {
        _cancelled = true;
        _cancellationReason = row['cancellation_reason'] as String?;
        _courseId = row['course_id'] as String?;
        _packageId = row['package_id'] as String?;
      });
    }
  }

  void _subscribeToChanges() {
    final uid = SupabaseService.userId;
    if (uid == null) return;
    _channel = SupabaseService.client
        .channel('sub_pending_${widget.subscriptionId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'subscriptions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'student_id',
            value: uid,
          ),
          callback: (payload) {
            if (payload.newRecord['id'] != widget.subscriptionId) return;
            if (!mounted) return;
            _applyStatus(Map<String, dynamic>.from(payload.newRecord as Map));
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    if (_channel != null) {
      SupabaseService.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    if (_cancelled) {
      return _buildCancelledScreen(context);
    }

    if (_activated) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    color: AppColors.statusConfirmedBg,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.check_circle_rounded,
                      size: 50, color: AppColors.statusConfirmed),
                ),
                const SizedBox(height: 24),
                Text(l.subPendingActivatedTitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                Text(l.subPendingActivatedBody,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                Text(l.subPendingRedirecting,
                    style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
                const SizedBox(height: 24),
                const CircularProgressIndicator(color: AppColors.statusConfirmed),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  color: _rejected
                      ? AppColors.statusRejectedBg
                      : const Color(0xFFF0EDFF),
                  borderRadius: BorderRadius.circular(24),
                ),
                alignment: Alignment.center,
                child: Icon(
                  _rejected ? Icons.cancel_outlined : Icons.hourglass_top_rounded,
                  size: 44,
                  color: _rejected ? AppColors.error : const Color(0xFF7B61FF),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _rejected ? l.coursesRejectedLabel : l.subPendingTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 12),
              Text(
                _rejected ? l.subPendingRejectedBody : l.subPendingPendingBody,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary, height: 1.6),
              ),

              if (_rejected) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.statusRejectedBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _isFakeProof(_rejectReason)
                            ? Icons.gpp_bad_rounded
                            : Icons.money_off_rounded,
                        color: AppColors.error, size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _friendlyRejectReason(_rejectReason),
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.error, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (!_rejected) ...[
                const SizedBox(height: 32),
                _buildStepRow(
                  icon: Icons.check_circle_outline_rounded,
                  color: AppColors.statusConfirmed,
                  label: l.subPendingStep1,
                  done: true,
                ),
                const SizedBox(height: 14),
                _buildStepRow(
                  icon: Icons.admin_panel_settings_outlined,
                  color: const Color(0xFF7B61FF),
                  label: l.subPendingStep2,
                  done: false,
                ),
                const SizedBox(height: 14),
                _buildStepRow(
                  icon: Icons.play_circle_outline_rounded,
                  color: AppColors.textHint,
                  label: l.subPendingStep3,
                  done: false,
                ),
              ],

              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.go('/my-courses'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _rejected ? AppColors.error : AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text(
                    _rejected ? l.subPendingBackCourses : l.subPendingViewCourses,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/home'),
                child: Text(l.subPendingBackHome,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isFakeProof(String? reason) {
    final r = (reason ?? '').toUpperCase().replaceAll(RegExp(r'^REFUND:'), '');
    return r == 'FAKE_PROOF' || r.contains('FAKE');
  }

  String _friendlyRejectReason(String? reason) {
    final l = context.l10n;
    final r = (reason ?? '').toUpperCase().replaceAll(RegExp(r'^REFUND:'), '');
    if (r == 'FAKE_PROOF' || r.contains('FAKE')) return l.subRejectedFakeProofNote;
    if (r == 'INCOMPLETE_AMOUNT' || r.contains('INCOMPLETE')) return l.subRejectedIncompleteAmountNote;
    return reason?.replaceAll(RegExp(r'^REFUND:', caseSensitive: false), '') ?? '';
  }

  Widget _buildCancelledScreen(BuildContext context) {
    final l = context.l10n;
    final reason = _cancellationReason ?? '';
    final bool withRefund = reason == 'insufficient_refund';

    final (String title, String body, IconData icon, Color color) = switch (reason) {
      'no_payment_deadline' => (
        l.subCancelledNoPaymentTitle,
        l.subCancelledNoPaymentBody,
        Icons.timer_off_rounded,
        AppColors.error,
      ),
      'fake_proof' => (
        l.subCancelledFakeProofTitle,
        l.subCancelledFakeProofBody,
        Icons.gpp_bad_rounded,
        AppColors.error,
      ),
      'insufficient_refund' => (
        l.subCancelledInsufficientTitle,
        l.subCancelledInsufficientBody,
        Icons.account_balance_wallet_outlined,
        const Color(0xFF7B61FF),
      ),
      _ => (
        l.subCancelledDefaultTitle,
        l.subCancelledDefaultBody,
        Icons.cancel_outlined,
        AppColors.error,
      ),
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 44, color: color),
              ),
              const SizedBox(height: 24),
              Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              Text(body,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.6)),
              if (withRefund) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF059669), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(l.subCancelledRefundNote,
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF059669), fontWeight: FontWeight.w600)),
                    ),
                  ]),
                ),
              ],
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (_courseId != null) {
                      context.go('/course/$_courseId');
                    } else if (_packageId != null) {
                      context.go('/package/$_packageId');
                    } else {
                      context.go('/my-courses');
                    }
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(l.coursesResub),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/home'),
                child: Text(l.subPendingBackHome,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepRow({
    required IconData icon,
    required Color color,
    required String label,
    required bool done,
  }) {
    return Row(
      children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(done ? Icons.check_rounded : icon, color: color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(label,
              style: TextStyle(
                fontSize: 13,
                color: done ? AppColors.statusConfirmed : AppColors.textSecondary,
                fontWeight: done ? FontWeight.w600 : FontWeight.w400,
              )),
        ),
        if (done)
          const Icon(Icons.check_circle_rounded,
              color: AppColors.statusConfirmed, size: 18),
      ],
    );
  }
}
