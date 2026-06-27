import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/subjects.dart';
import '../../../core/extensions/l10n_extension.dart';
import '../../../core/providers/sessions_provider.dart';
import '../../../core/services/supabase_service.dart';

class TeacherDashboardScreen extends ConsumerStatefulWidget {
  const TeacherDashboardScreen({super.key});
  @override
  ConsumerState<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends ConsumerState<TeacherDashboardScreen> {
  bool _togglingAvailability = false;

  Future<void> _toggleAvailability(bool current) async {
    setState(() => _togglingAvailability = true);
    try {
      await SupabaseService.client
          .from('profiles')
          .update({'is_active': !current})
          .eq('id', SupabaseService.userId!);
      ref.invalidate(teacherDashboardProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.dashToggleError)),
        );
      }
    } finally {
      if (mounted) setState(() => _togglingAvailability = false);
    }
  }

  String _fmtDate(String isoStr, BuildContext context) {
    final l = context.l10n;
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
    final async = ref.watch(teacherDashboardProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.dashLoadError),
              TextButton(
                onPressed: () => ref.invalidate(teacherDashboardProvider),
                child: Text(l.commonRetry),
              ),
            ],
          ),
        ),
        data: (stats) => RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => ref.invalidate(teacherDashboardProvider),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _Header(
                  name: stats.teacherName,
                  initial: stats.teacherInitial,
                  avatarUrl: stats.teacherAvatarUrl,
                  isAvailable: stats.isAvailable,
                  toggling: _togglingAvailability,
                  weekEarnings: stats.weekEarnings,
                  completedSessions: stats.completedSessions,
                  onToggle: () => _toggleAvailability(stats.isAvailable),
                ),
              ),
              SliverToBoxAdapter(
                child: _StatsRow(
                  pendingCount: stats.pendingCount,
                  todayCount: stats.todayCount,
                  attendanceRate: stats.attendanceRate,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 20)),
              if (stats.pendingRequests.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: l.dashNewRequests,
                    badge: l.dashAwaitingBadge('${stats.pendingCount}'),
                    badgeFg: const Color(0xFFC77A1A),
                    badgeBg: const Color(0xFFFEF3E2),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _RequestCard(
                        session: stats.pendingRequests[i],
                        fmtDate: (s) => _fmtDate(s, context)),
                    childCount: stats.pendingRequests.length,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],
              SliverToBoxAdapter(child: _SectionHeader(title: l.dashUpcomingSessions)),
              if (stats.upcomingSessions.isNotEmpty)
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _UpcomingCard(
                        session: stats.upcomingSessions[i],
                        fmtDate: (s) => _fmtDate(s, context)),
                    childCount: stats.upcomingSessions.length,
                  ),
                )
              else
                const SliverToBoxAdapter(child: _EmptyUpcoming()),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Header ───────────────────────────────────────────────────
class _Header extends StatelessWidget {
  final String name;
  final String initial;
  final String? avatarUrl;
  final bool isAvailable;
  final bool toggling;
  final double weekEarnings;
  final int completedSessions;
  final VoidCallback onToggle;

  const _Header({
    required this.name, required this.initial, this.avatarUrl,
    required this.isAvailable, required this.toggling,
    required this.weekEarnings, required this.completedSessions,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF1B6B7A), Color(0xFF11313A)],
        ),
      ),
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(13),
                    image: avatarUrl != null
                        ? DecorationImage(image: NetworkImage(avatarUrl!), fit: BoxFit.cover)
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: avatarUrl == null
                      ? Text(initial,
                          style: const TextStyle(color: Color(0xFF1B6B7A), fontWeight: FontWeight.w700, fontSize: 19))
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.dashWelcome,
                        style: const TextStyle(fontSize: 12, color: Color(0xFFCFE6EA))),
                      Text(
                        name.isNotEmpty ? name : l.dashTeacherFallback,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: toggling ? null : onToggle,
                  child: Column(
                    children: [
                      toggling
                          ? const SizedBox(width: 46, height: 27,
                              child: Center(child: SizedBox(width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))))
                          : AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              width: 46, height: 27,
                              decoration: BoxDecoration(
                                color: isAvailable ? const Color(0xFF7BE0C0) : Colors.white24,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Align(
                                alignment: isAvailable ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.all(3),
                                  width: 21, height: 21,
                                  decoration: const BoxDecoration(color: Color(0xFF11313A), shape: BoxShape.circle),
                                ),
                              ),
                            ),
                      const SizedBox(height: 4),
                      Text(
                        isAvailable ? l.dashAvailableLabel : l.dashUnavailableLabel,
                        style: const TextStyle(fontSize: 9, color: Color(0xFFCFE6EA), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 22).copyWith(bottom: 20),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.dashWeekEarnings,
                  style: const TextStyle(fontSize: 12, color: Color(0xFFCFE6EA))),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      weekEarnings.toInt().toString().replaceAllMapped(
                        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},'),
                      style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text(l.dashOugiya,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF7BE0C0))),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(l.dashCompletedNote(completedSessions),
                  style: const TextStyle(fontSize: 11, color: Color(0xFF9DB2B8))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stats row ────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final int pendingCount;
  final int todayCount;
  final double attendanceRate;
  const _StatsRow({required this.pendingCount, required this.todayCount, required this.attendanceRate});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
      child: Row(
        children: [
          _StatCard(value: '$pendingCount', label: l.dashStatNew, color: const Color(0xFFF2994A)),
          const SizedBox(width: 10),
          _StatCard(value: '$todayCount', label: l.dashStatToday, color: AppColors.textPrimary),
          const SizedBox(width: 10),
          _StatCard(value: '${attendanceRate.toInt()}%', label: l.dashStatAttendance, color: AppColors.success),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _StatCard({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
          ],
        ),
      ),
    );
  }
}

// ── Section header ───────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final String? badge;
  final Color? badgeFg;
  final Color? badgeBg;
  const _SectionHeader({required this.title, this.badge, this.badgeFg, this.badgeBg});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      child: Row(
        children: [
          Text(title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          if (badge != null) ...[
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: badgeBg ?? AppColors.accentLight,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(badge!,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: badgeFg ?? AppColors.primary)),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Request card ─────────────────────────────────────────────
class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final String Function(String) fmtDate;
  const _RequestCard({required this.session, required this.fmtDate});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final id = session['id'] as String;
    final studentMap = session['student'] as Map? ?? {};
    final studentName = (studentMap['full_name'] as String?) ?? l.authStudent;
    final subject = (session['subject'] as String?) ?? '';
    final scheduledAt = (session['scheduled_at'] as String?) ?? '';
    final duration = (session['duration_minutes'] as int?) ?? 60;
    final initial = studentName.isNotEmpty ? studentName[0] : l.authStudent[0];
    final studentAvatarUrl = studentMap['avatar_url'] as String?;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 22, vertical: 5),
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
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(color: AppColors.accentLight,
                  borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: studentAvatarUrl != null
                    ? CachedNetworkImage(
                        imageUrl: studentAvatarUrl,
                        width: 42, height: 42, fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Text(initial,
                            style: const TextStyle(color: AppColors.primary,
                                fontWeight: FontWeight.w700, fontSize: 17)),
                      )
                    : Text(initial,
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
                    Text('${translateSubject(subject, Localizations.localeOf(context))} · ${fmtDate(scheduledAt)} · ${l.dashMinutesShort(duration)}',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3E2),
                  borderRadius: BorderRadius.circular(6),
                ),
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

// ── Upcoming card ────────────────────────────────────────────
class _UpcomingCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final String Function(String) fmtDate;
  const _UpcomingCard({required this.session, required this.fmtDate});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final id = session['id'] as String;
    final studentMap = session['student'] as Map? ?? {};
    final studentName = (studentMap['full_name'] as String?) ?? l.authStudent;
    final subject = (session['subject'] as String?) ?? '';
    final scheduledAt = (session['scheduled_at'] as String?) ?? '';
    final duration = (session['duration_minutes'] as int?) ?? 60;

    final dt = DateTime.tryParse(scheduledAt);
    final diffMin = dt != null ? dt.difference(DateTime.now()).inMinutes : 0;
    final timeLabel = diffMin <= 0
        ? fmtDate(scheduledAt)          // past/now: show absolute time, not negative countdown
        : diffMin < 60
            ? l.dashInMinutes(diffMin)
            : diffMin < 1440
                ? l.dashInHours(diffMin ~/ 60)
                : fmtDate(scheduledAt);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 22, vertical: 5),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(color: AppColors.accentLight,
              borderRadius: BorderRadius.circular(11)),
            child: Column(
              children: [
                Text(
                  dt != null
                      ? '${dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour)}:${dt.minute.toString().padLeft(2, '0')}'
                      : '--',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                    color: AppColors.primary),
                ),
                Text(dt != null && dt.hour >= 12 ? l.dashEveningLabel : l.dashMorningLabel,
                  style: const TextStyle(fontSize: 9, color: AppColors.primary)),
              ],
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$studentName · ${translateSubject(subject, Localizations.localeOf(context))}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
                Text('${l.sessionMinutes(duration)} · $timeLabel',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => context.push('/teacher/session/$id'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F6EF),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(l.dashConfirmedBadge,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  color: Color(0xFF15805F))),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyUpcoming extends StatelessWidget {
  const _EmptyUpcoming();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 22),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Text(context.l10n.dashNoUpcoming,
          style: const TextStyle(fontSize: 13, color: AppColors.textHint)),
      ),
    );
  }
}
