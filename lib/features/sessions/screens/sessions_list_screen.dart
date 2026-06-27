import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/session_states.dart';
import '../../../core/constants/subjects.dart';
import '../../../core/extensions/l10n_extension.dart';
import '../../../core/models/session.dart';
import '../../../core/providers/sessions_provider.dart';
import '../../../shared/widgets/session_status_badge.dart';

class SessionsListScreen extends ConsumerStatefulWidget {
  const SessionsListScreen({super.key});
  @override
  ConsumerState<SessionsListScreen> createState() => _SessionsListScreenState();
}

class _SessionsListScreenState extends ConsumerState<SessionsListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final sessionsAsync = ref.watch(studentSessionsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(l.sessionsTitle),
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textHint,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          tabs: [
            Tab(text: l.sessionsTabActive),
            Tab(text: l.sessionsTabPending),
            Tab(text: l.sessionsTabEnded),
          ],
        ),
      ),
      body: sessionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textHint),
              const SizedBox(height: 12),
              Text(l.sessionListLoadError, style: const TextStyle(fontSize: 15, color: AppColors.textPrimary)),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => ref.invalidate(studentSessionsProvider),
                child: Text(l.commonRetry),
              ),
            ],
          ),
        ),
        data: (sessions) => RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () => ref.refresh(studentSessionsProvider.future),
          child: _buildTabs(context, sessions),
        ),
      ),
    );
  }

  Widget _buildTabs(BuildContext context, List<Session> sessions) {
    final active = sessions.where((s) =>
        [SessionState.confirmedBooking, SessionState.activeSession].contains(s.state)).toList();
    final pending = sessions.where((s) =>
        [SessionState.requested, SessionState.teacherApproved,
         SessionState.awaitingPayment, SessionState.paymentSubmitted,
         SessionState.paymentConfirmed].contains(s.state)).toList();
    final ended = sessions.where((s) =>
        [SessionState.completed, SessionState.teacherRejected, SessionState.cancelled,
         SessionState.teacherNoShow, SessionState.studentNoShow, SessionState.dispute].contains(s.state)).toList();

    return TabBarView(
      controller: _tabs,
      children: [
        _SessionsList(sessions: active),
        _SessionsList(sessions: pending),
        _SessionsList(sessions: ended),
      ],
    );
  }
}

class _SessionsList extends StatelessWidget {
  final List<Session> sessions;
  const _SessionsList({required this.sessions});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: const BoxDecoration(color: AppColors.surfaceAlt, shape: BoxShape.circle),
              child: const Icon(Icons.calendar_today_outlined, color: AppColors.textHint, size: 30),
            ),
            const SizedBox(height: 16),
            Text(l.sessionsEmpty,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Text(l.sessionsEmptyHint,
              style: const TextStyle(fontSize: 13, color: AppColors.textHint)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 100),
      itemCount: sessions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _SessionCard(session: sessions[i]),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final Session session;
  const _SessionCard({required this.session});

  String _formatDate(DateTime dt, BuildContext context) {
    final l = context.l10n;
    final days = [l.daySun, l.dayMon, l.dayTue, l.dayWed, l.dayThu, l.dayFri, l.daySat];
    final h = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final period = dt.hour >= 12 ? l.timePM : l.timeAM;
    return '${days[dt.weekday % 7]} $h:${dt.minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final s = session;
    return GestureDetector(
      onTap: () {
        if (s.state == SessionState.activeSession) {
          context.push('/live/${s.id}');
        } else if (s.state == SessionState.awaitingPayment ||
                   s.state == SessionState.teacherApproved) {
          context.push('/payment/${s.id}');
        } else {
          context.push('/session/${s.id}');
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.04),
            blurRadius: 4, offset: const Offset(0, 1))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42, height: 42,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppColors.accentLight,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  alignment: Alignment.center,
                  child: s.teacherAvatarUrl != null
                      ? CachedNetworkImage(
                          imageUrl: s.teacherAvatarUrl!,
                          width: 42, height: 42, fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Text(s.teacherInitial,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary)),
                        )
                      : Text(s.teacherInitial,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.teacherName,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      Text(translateSubject(s.subject, Localizations.localeOf(context)),
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                SessionStatusBadge(state: s.state),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                _InfoChip(icon: Icons.calendar_today_rounded, label: _formatDate(s.scheduledAt, context)),
                const SizedBox(width: 12),
                _InfoChip(icon: Icons.timer_outlined, label: l.sessionMinutes(s.durationMinutes)),
                const Spacer(),
                Text(l.sessionOugiya('${s.amount.toInt()}'),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary)),
              ],
            ),
            if (s.state == SessionState.activeSession) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.statusActiveBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.videocam_rounded, color: AppColors.statusActive, size: 16),
                    const SizedBox(width: 6),
                    Text(l.sessionsEnterNow,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.statusActive)),
                  ],
                ),
              ),
            ],
            if (s.state == SessionState.teacherApproved ||
                s.state == SessionState.awaitingPayment) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.statusApprovedBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.payment_rounded, color: AppColors.statusApproved, size: 16),
                    const SizedBox(width: 6),
                    Text(l.sessionsCompletePayment,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.statusApproved)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppColors.textHint),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}
