import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/l10n_extension.dart';
import '../../../core/providers/sessions_provider.dart';
import '../../../l10n/app_localizations.dart';

class TeacherRequestsScreen extends ConsumerStatefulWidget {
  const TeacherRequestsScreen({super.key});
  @override
  ConsumerState<TeacherRequestsScreen> createState() => _TeacherRequestsScreenState();
}

class _TeacherRequestsScreenState extends ConsumerState<TeacherRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  String _fmtDate(String isoStr, AppLocalizations l) {
    final dt = DateTime.tryParse(isoStr);
    if (dt == null) return '';
    final days = [l.daySun, l.dayMon, l.dayTue, l.dayWed, l.dayThu, l.dayFri, l.daySat];
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? l.timePM : l.timeAM;
    return '${days[dt.weekday % 7]} $h:${dt.minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final pendingAsync    = ref.watch(teacherPendingRequestsProvider);
    final inProgressAsync = ref.watch(teacherInProgressSessionsProvider);
    final rejectedAsync   = ref.watch(teacherRejectedSessionsProvider);

    final pendingCount    = pendingAsync.value?.length    ?? 0;
    final inProgressCount = inProgressAsync.value?.length ?? 0;
    final rejectedCount   = rejectedAsync.value?.length   ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 14),
            child: Text(l.teacherRequestsTitle,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: _TabBar(
              controller: _tabs,
              pendingCount: pendingCount,
              inProgressCount: inProgressCount,
              rejectedCount: rejectedCount,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                pendingAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  error: (e, _) => _ErrorWidget(onRetry: () => ref.invalidate(teacherPendingRequestsProvider)),
                  data: (list) => list.isEmpty
                      ? _EmptyTab(icon: Icons.inbox_outlined, label: l.reqEmptyNew)
                      : RefreshIndicator(
                          onRefresh: () async => ref.invalidate(teacherPendingRequestsProvider),
                          child: ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                            children: list.map((s) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _PendingCard(session: s, fmtDate: (d) => _fmtDate(d, l)),
                            )).toList(),
                          ),
                        ),
                ),
                inProgressAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  error: (e, _) => _ErrorWidget(onRetry: () => ref.invalidate(teacherInProgressSessionsProvider)),
                  data: (list) => list.isEmpty
                      ? _EmptyTab(icon: Icons.event_note_outlined, label: l.reqEmptyInProgress)
                      : RefreshIndicator(
                          onRefresh: () async => ref.invalidate(teacherInProgressSessionsProvider),
                          child: ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                            children: list.map((s) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _InProgressCard(session: s, fmtDate: (d) => _fmtDate(d, l)),
                            )).toList(),
                          ),
                        ),
                ),
                rejectedAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  error: (e, _) => _ErrorWidget(onRetry: () => ref.invalidate(teacherRejectedSessionsProvider)),
                  data: (list) => list.isEmpty
                      ? _EmptyTab(icon: Icons.do_not_disturb_alt_rounded, label: l.reqEmptyRejected)
                      : RefreshIndicator(
                          onRefresh: () async => ref.invalidate(teacherRejectedSessionsProvider),
                          child: ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                            children: list.map((s) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _RejectedCard(session: s, fmtDate: (d) => _fmtDate(d, l)),
                            )).toList(),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Custom tab bar ────────────────────────────────────────────
class _TabBar extends StatelessWidget {
  final TabController controller;
  final int pendingCount;
  final int inProgressCount;
  final int rejectedCount;
  const _TabBar({required this.controller, required this.pendingCount,
    required this.inProgressCount, required this.rejectedCount});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => Row(
        children: List.generate(3, (i) {
          final labels = [
            '${l.reqTabNew}${pendingCount > 0 ? ' ($pendingCount)' : ''}',
            '${l.reqTabInProgress}${inProgressCount > 0 ? ' ($inProgressCount)' : ''}',
            '${l.reqTabRejected}${rejectedCount > 0 ? ' ($rejectedCount)' : ''}',
          ];
          final sel = controller.index == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => controller.animateTo(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? AppColors.primaryDark : AppColors.surface,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: sel ? AppColors.primaryDark : AppColors.border),
                ),
                child: Text(labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: sel ? Colors.white : AppColors.textSecondary)),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── In-progress state badge helper ───────────────────────────
(String, Color, Color) _inProgressBadge(String state, AppLocalizations l) {
  switch (state) {
    case 'AWAITING_PAYMENT':  return (l.stateBadgeAwaitingPay,  const Color(0xFF5B43D6), const Color(0xFFF0EDFF));
    case 'PAYMENT_SUBMITTED': return (l.stateBadgeSubmitted,    const Color(0xFFC77A1A), const Color(0xFFFEF3E2));
    case 'PAYMENT_CONFIRMED': return (l.stateBadgeConfirmedPay, const Color(0xFF15805F), const Color(0xFFE3F6EF));
    case 'CONFIRMED_BOOKING': return (l.stateBadgeConfirmed,    const Color(0xFF15805F), const Color(0xFFE3F6EF));
    case 'ACTIVE_SESSION':    return (l.stateBadgeActive,       const Color(0xFF1B6B7A), const Color(0xFFE0F4F7));
    default:                  return (state.replaceAll('_', ' '), AppColors.textHint, AppColors.surface);
  }
}

// ── Pending card ─────────────────────────────────────────────
class _PendingCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final String Function(String) fmtDate;
  const _PendingCard({required this.session, required this.fmtDate});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final id = session['id'] as String;
    final studentMap  = session['student'] as Map? ?? {};
    final studentName = (studentMap['full_name'] as String?) ?? l.authStudent;
    final subject     = (session['subject'] as String?) ?? '';
    final scheduledAt = (session['scheduled_at'] as String?) ?? '';
    final duration    = (session['duration_minutes'] as int?) ?? 60;
    final initial     = studentName.isNotEmpty ? studentName[0] : l.authStudent[0];

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(color: AppColors.accentLight,
                  borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: Text(initial,
                  style: const TextStyle(color: AppColors.primary,
                    fontWeight: FontWeight.w700, fontSize: 17)),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(studentName,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                    Text('$subject · ${fmtDate(scheduledAt)} · ${l.dashMinutesShort(duration)}',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFFEF3E2),
                  borderRadius: BorderRadius.circular(6)),
                child: Text(l.dashNewBadge,
                  style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700,
                    color: Color(0xFFC77A1A))),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => context.push('/teacher/request/$id'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(l.dashReviewBtn,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── In-progress card ─────────────────────────────────────────
class _InProgressCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final String Function(String) fmtDate;
  const _InProgressCard({required this.session, required this.fmtDate});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final id          = session['id'] as String;
    final studentMap  = session['student'] as Map? ?? {};
    final studentName = (studentMap['full_name'] as String?) ?? l.authStudent;
    final subject     = (session['subject'] as String?) ?? '';
    final scheduledAt = (session['scheduled_at'] as String?) ?? '';
    final state       = (session['state'] as String?) ?? '';
    final initial     = studentName.isNotEmpty ? studentName[0] : l.authStudent[0];
    final badgeInfo   = _inProgressBadge(state, l);

    return GestureDetector(
      onTap: () => context.push('/teacher/session/$id'),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(color: AppColors.accentLight,
                borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center,
              child: Text(initial,
                style: const TextStyle(color: AppColors.primary,
                  fontWeight: FontWeight.w700, fontSize: 17)),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(studentName,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
                  Text('$subject · ${fmtDate(scheduledAt)}',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(color: badgeInfo.$3,
                borderRadius: BorderRadius.circular(6)),
              child: Text(badgeInfo.$1,
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700,
                  color: badgeInfo.$2)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Rejected card ─────────────────────────────────────────────
class _RejectedCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final String Function(String) fmtDate;
  const _RejectedCard({required this.session, required this.fmtDate});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final studentMap  = session['student'] as Map? ?? {};
    final studentName = (studentMap['full_name'] as String?) ?? l.authStudent;
    final subject     = (session['subject'] as String?) ?? '';
    final scheduledAt = (session['scheduled_at'] as String?) ?? '';
    final reason      = (session['rejection_reason'] as String?);
    final initial     = studentName.isNotEmpty ? studentName[0] : l.authStudent[0];

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(initial,
              style: const TextStyle(color: AppColors.textHint,
                fontWeight: FontWeight.w700, fontSize: 17)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(studentName,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
                Text('$subject · ${fmtDate(scheduledAt)}',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                if (reason != null && reason.isNotEmpty)
                  Text(l.reqRejectedReason(reason),
                    style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFDECEC),
              borderRadius: BorderRadius.circular(6)),
            child: Text(l.reqRejectedBadge,
              style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700,
                color: Color(0xFFE03E3E))),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────
class _EmptyTab extends StatelessWidget {
  final IconData icon;
  final String label;
  const _EmptyTab({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(18)),
            child: Icon(icon, color: AppColors.textHint, size: 30),
          ),
          const SizedBox(height: 14),
          Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
              color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorWidget({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(l.dashLoadError),
          TextButton(onPressed: onRetry, child: Text(l.commonRetry)),
        ],
      ),
    );
  }
}
