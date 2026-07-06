import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/subjects.dart';
import '../../../core/extensions/l10n_extension.dart';
import '../../../core/providers/sessions_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../l10n/app_localizations.dart';

class TeacherEarningsScreen extends ConsumerWidget {
  const TeacherEarningsScreen({super.key});

  String _fmtDate(String isoStr, AppLocalizations l) {
    final dt = DateTime.tryParse(isoStr);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return l.timeMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) {
      return '${l.timeToday} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _fmtAmount(num amt) {
    return amt.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l            = context.l10n;
    final async        = ref.watch(teacherEarningsProvider);
    final supportPhone = ref.watch(supportPhoneProvider).asData?.value ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(l.teacherEarningsTitle,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
            color: AppColors.textPrimary)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/teacher/home');
            }
          },
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.dashLoadError),
              TextButton(
                onPressed: () => ref.invalidate(teacherEarningsProvider),
                child: Text(l.commonRetry),
              ),
            ],
          ),
        ),
        data: (data) {
          final comm = ref.watch(commissionSettingsProvider).asData?.value
              ?? const CommissionSettings();
          return RefreshIndicator(
          onRefresh: () async => ref.invalidate(teacherEarningsProvider),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 22),
            children: [
              const SizedBox(height: 16),
              _BalanceCard(balance: data.totalBalance, fmtAmount: _fmtAmount, supportPhone: supportPhone),
              const SizedBox(height: 16),
              _StatsRow(
                weekEarnings: data.weekEarnings,
                monthEarnings: data.monthEarnings,
                fmtAmount: _fmtAmount,
              ),
              const SizedBox(height: 10),
              _SourcesRow(
                sessionEarnings: data.sessionEarnings,
                courseEarnings: data.courseEarnings,
                fmtAmount: _fmtAmount,
              ),
              const SizedBox(height: 14),
              _CommissionBanner(sessionPct: comm.sessionPctInt, subPct: comm.subscriptionPctInt),
              const SizedBox(height: 20),
              Text(l.teacherLedgerTitle,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              if (data.entries.isEmpty)
                _EmptyLedger()
              else
                ...data.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: _LedgerRow(
                    entry: e,
                    fmtDate: (s) => _fmtDate(s, l),
                    fmtAmount: _fmtAmount,
                  ),
                )),
              const SizedBox(height: 20),
            ],
          ),
        );
        },
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final double balance;
  final String Function(num) fmtAmount;
  final String supportPhone;
  const _BalanceCard({required this.balance, required this.fmtAmount, required this.supportPhone});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.teacherEarningsBalance,
            style: const TextStyle(fontSize: 12, color: Color(0xFF9DB2B8))),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(fmtAmount(balance),
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700,
                  color: Colors.white)),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(l.dashOugiya,
                  style: const TextStyle(fontSize: 13, color: Color(0xFF7BE0C0))),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(supportPhone.isNotEmpty
                      ? 'للسحب تواصل مع الإدارة عبر واتساب: $supportPhone'
                      : l.teacherEarningsWithdrawContact),
                  backgroundColor: const Color(0xFF1B6B7A),
                  duration: const Duration(seconds: 4),
                ),
              );
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                color: const Color(0xFF7BE0C0),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(l.teacherEarningsWithdraw,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                  color: Color(0xFF11313A))),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final double weekEarnings;
  final double monthEarnings;
  final String Function(num) fmtAmount;
  const _StatsRow({
    required this.weekEarnings,
    required this.monthEarnings,
    required this.fmtAmount,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Row(
      children: [
        Expanded(child: _StatBox(label: l.teacherEarningsWeek, value: fmtAmount(weekEarnings))),
        const SizedBox(width: 10),
        Expanded(child: _StatBox(label: l.teacherEarningsMonth, value: fmtAmount(monthEarnings))),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  const _StatBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700,
              color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
        ],
      ),
    );
  }
}

class _SourcesRow extends StatelessWidget {
  final double sessionEarnings;
  final double courseEarnings;
  final String Function(num) fmtAmount;
  const _SourcesRow({
    required this.sessionEarnings,
    required this.courseEarnings,
    required this.fmtAmount,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Row(
      children: [
        Expanded(
          child: _SourceBox(
            icon: Icons.video_call_outlined,
            label: l.teacherEarningsFromSessions,
            value: fmtAmount(sessionEarnings),
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SourceBox(
            icon: Icons.menu_book_outlined,
            label: l.teacherEarningsFromCourses,
            value: fmtAmount(courseEarnings),
            color: const Color(0xFF7B61FF),
          ),
        ),
      ],
    );
  }
}

class _SourceBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _SourceBox({
    required this.icon, required this.label,
    required this.value, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
                Text(label,
                  style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommissionBanner extends StatelessWidget {
  final int sessionPct;
  final int subPct;
  const _CommissionBanner({required this.sessionPct, required this.subPct});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3E2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFC77A1A)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l.earningsCommissionText('$sessionPct', '$subPct'),
              style: const TextStyle(fontSize: 11, color: Color(0xFF8A5A14), height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  final Map<String, dynamic> entry;
  final String Function(String) fmtDate;
  final String Function(num) fmtAmount;
  const _LedgerRow({required this.entry, required this.fmtDate, required this.fmtAmount});

  @override
  Widget build(BuildContext context) {
    final l         = context.l10n;
    final amt       = (entry['net_amount'] as num?) ?? 0;
    final createdAt = (entry['created_at'] as String?) ?? '';
    final type      = (entry['type'] as String?) ?? '';

    final paymentMap    = entry['payment'] as Map?;
    final disputeStatus = (paymentMap?['dispute_status'] as String?) ?? 'confirmed';
    final isFrozen      = type == 'session_payment' && disputeStatus == 'frozen';
    final isRefunded    = type == 'session_payment' && disputeStatus == 'refunded';

    final isCourse  = type == 'course_subscription';
    final isSession = type == 'session_payment';
    final isPayout  = type == 'payout_sent';

    final sessionMap  = entry['session'] as Map?;
    final rawSubject  = (sessionMap?['subject'] as String?) ?? '';
    final subject     = translateSubject(rawSubject, Localizations.localeOf(context));
    final studentMap  = sessionMap?['student'] as Map?;
    final studentName = (studentMap?['full_name'] as String?) ?? '';

    final title = isCourse
        ? (entry['description'] as String? ?? l.earningsCourseDesc)
        : isSession
            ? (studentName.isNotEmpty
                ? l.earningsSessionDescWithStudent(subject, studentName)
                : l.earningsSessionDesc(subject))
            : isPayout
                ? l.teacherLedgerPayout
                : type.replaceAll('_', ' ');

    final Color iconColor;
    final Color iconBg;
    final IconData icon;

    if (isFrozen) {
      iconColor = const Color(0xFFC77A1A);
      iconBg    = const Color(0xFFFEF3E2);
      icon      = Icons.lock_clock_outlined;
    } else if (isRefunded) {
      iconColor = const Color(0xFF7B61FF);
      iconBg    = const Color(0xFFF0EDFF);
      icon      = Icons.reply_rounded;
    } else if (isCourse) {
      iconColor = const Color(0xFF7B61FF);
      iconBg    = const Color(0xFFF0EDFF);
      icon      = Icons.menu_book_outlined;
    } else if (isSession) {
      iconColor = const Color(0xFF1B9E77);
      iconBg    = const Color(0xFFE3F6EF);
      icon      = Icons.video_call_outlined;
    } else if (isPayout) {
      iconColor = const Color(0xFFC77A1A);
      iconBg    = const Color(0xFFFEF3E2);
      icon      = Icons.account_balance_wallet_outlined;
    } else {
      iconColor = AppColors.textSecondary;
      iconBg    = const Color(0xFFEEF0F2);
      icon      = Icons.swap_horiz_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isFrozen
            ? const Color(0xFFFFFBF0)
            : isRefunded
                ? const Color(0xFFF8F5FF)
                : AppColors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: isFrozen
              ? const Color(0xFFFCD34D)
              : isRefunded
                  ? const Color(0xFFC4B5FD)
                  : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                  style: TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700,
                    color: isFrozen || isRefunded
                        ? AppColors.textSecondary
                        : AppColors.textPrimary,
                  ),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(fmtDate(createdAt),
                  style: const TextStyle(fontSize: 10.5, color: AppColors.textHint)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (isFrozen)
            _StatusChip(label: '⚠ مجمَّد', color: const Color(0xFFC77A1A), bg: const Color(0xFFFEF3E2))
          else if (isRefunded)
            _StatusChip(label: '↩ مسترد', color: const Color(0xFF7B61FF), bg: const Color(0xFFF0EDFF))
          else
            Text(
              isPayout
                  ? '-${fmtAmount(amt.abs())}'
                  : '+${fmtAmount(amt)}',
              style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: isPayout ? const Color(0xFFE03E3E) : iconColor,
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  const _StatusChip({required this.label, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _EmptyLedger extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.receipt_long_outlined, size: 32, color: AppColors.textHint),
          const SizedBox(height: 8),
          Text(l.teacherLedgerEmpty,
            style: const TextStyle(fontSize: 13, color: AppColors.textHint)),
        ],
      ),
    );
  }
}
