import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/sessions_provider.dart';

class TeacherSessionsScreen extends ConsumerStatefulWidget {
  const TeacherSessionsScreen({super.key});
  @override
  ConsumerState<TeacherSessionsScreen> createState() => _TeacherSessionsScreenState();
}

class _TeacherSessionsScreenState extends ConsumerState<TeacherSessionsScreen>
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

  String _fmtTime(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'م' : 'ص';
    return '$h:${dt.minute.toString().padLeft(2, '0')} $period';
  }

  String _fmtDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    const days = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
    return '${days[dt.weekday % 7]} ${dt.day}/${dt.month}';
  }

  @override
  Widget build(BuildContext context) {
    final todayAsync     = ref.watch(teacherTodaySessionsProvider);
    final upcomingAsync  = ref.watch(teacherUpcomingSessionsProvider);
    final completedAsync = ref.watch(teacherCompletedSessionsProvider);

    final todayCount    = todayAsync.value?.length    ?? 0;
    final upcomingCount = upcomingAsync.value?.length ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            child: Text('جلساتي',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: _TabRow(
              controller: _tabs,
              todayCount: todayCount,
              upcomingCount: upcomingCount,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                // ── Today ────────────────────────────────────────
                _AsyncTab(
                  asyncValue: todayAsync,
                  onRefresh: () => ref.invalidate(teacherTodaySessionsProvider),
                  emptyIcon: Icons.wb_sunny_outlined,
                  emptyLabel: 'لا توجد جلسات اليوم',
                  builder: (list) => _SessionList(
                    sessions: list,
                    showDate: false,
                    fmtTime: _fmtTime,
                    fmtDate: _fmtDate,
                  ),
                ),

                // ── Upcoming ─────────────────────────────────────
                _AsyncTab(
                  asyncValue: upcomingAsync,
                  onRefresh: () => ref.invalidate(teacherUpcomingSessionsProvider),
                  emptyIcon: Icons.event_note_outlined,
                  emptyLabel: 'لا توجد جلسات قادمة',
                  builder: (list) => _SessionList(
                    sessions: list,
                    showDate: true,
                    fmtTime: _fmtTime,
                    fmtDate: _fmtDate,
                  ),
                ),

                // ── Completed ────────────────────────────────────
                _AsyncTab(
                  asyncValue: completedAsync,
                  onRefresh: () => ref.invalidate(teacherCompletedSessionsProvider),
                  emptyIcon: Icons.check_circle_outline_rounded,
                  emptyLabel: 'لا توجد جلسات مكتملة',
                  builder: (list) => _CompletedList(
                    sessions: list,
                    fmtDate: _fmtDate,
                    fmtTime: _fmtTime,
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

// ── Tab bar ───────────────────────────────────────────────────

class _TabRow extends StatelessWidget {
  final TabController controller;
  final int todayCount;
  final int upcomingCount;
  const _TabRow({required this.controller, required this.todayCount, required this.upcomingCount});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final labels = [
          'اليوم${todayCount > 0 ? ' ($todayCount)' : ''}',
          'القادمة${upcomingCount > 0 ? ' ($upcomingCount)' : ''}',
          'المكتملة',
        ];
        return Row(
          children: List.generate(3, (i) {
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
        );
      },
    );
  }
}

// ── Generic async wrapper ─────────────────────────────────────

class _AsyncTab extends StatelessWidget {
  final AsyncValue<List<Map<String, dynamic>>> asyncValue;
  final VoidCallback onRefresh;
  final IconData emptyIcon;
  final String emptyLabel;
  final Widget Function(List<Map<String, dynamic>>) builder;

  const _AsyncTab({
    required this.asyncValue,
    required this.onRefresh,
    required this.emptyIcon,
    required this.emptyLabel,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return asyncValue.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('تعذّر تحميل البيانات'),
            TextButton(onPressed: onRefresh, child: const Text('إعادة المحاولة')),
          ],
        ),
      ),
      data: (list) => list.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(18)),
                    child: Icon(emptyIcon, color: AppColors.textHint, size: 30),
                  ),
                  const SizedBox(height: 14),
                  Text(emptyLabel,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: () async => onRefresh(),
              child: builder(list),
            ),
    );
  }
}

// ── Session list (today + upcoming) ──────────────────────────

const _stateLabels = {
  'AWAITING_PAYMENT':  ('بانتظار الدفع',    Color(0xFF5B43D6), Color(0xFFF0EDFF)),
  'PAYMENT_SUBMITTED': ('بانتظار التأكيد',  Color(0xFFC77A1A), Color(0xFFFEF3E2)),
  'PAYMENT_CONFIRMED': ('دفع مؤكّد',        Color(0xFF15805F), Color(0xFFE3F6EF)),
  'CONFIRMED_BOOKING': ('مؤكّد',            Color(0xFF15805F), Color(0xFFE3F6EF)),
  'ACTIVE_SESSION':    ('جارية الآن',       Color(0xFF1B6B7A), Color(0xFFE0F4F7)),
  'TEACHER_NO_SHOW':   ('غياب الأستاذ',     Color(0xFFE03E3E), Color(0xFFFDECEC)),
  'STUDENT_NO_SHOW':   ('غياب الطالب',      Color(0xFFC77A1A), Color(0xFFFEF3E2)),
};

class _SessionList extends StatelessWidget {
  final List<Map<String, dynamic>> sessions;
  final bool showDate;
  final String Function(String) fmtTime;
  final String Function(String) fmtDate;

  const _SessionList({
    required this.sessions,
    required this.showDate,
    required this.fmtTime,
    required this.fmtDate,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
      itemCount: sessions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final s = sessions[i];
        final id = s['id'] as String;
        final studentMap = s['student'] as Map? ?? {};
        final studentName = (studentMap['full_name'] as String?) ?? 'طالب';
        final subject     = (s['subject'] as String?) ?? '';
        final scheduled   = (s['scheduled_at'] as String?) ?? '';
        final duration    = (s['duration_minutes'] as int?) ?? 60;
        final state       = (s['state'] as String?) ?? '';
        final isActive    = state == 'ACTIVE_SESSION';
        final stateInfo   = _stateLabels[state]
            ?? (state, AppColors.textHint, AppColors.surfaceAlt);

        if (isActive) {
          return _ActiveCard(
            studentName: studentName,
            subject: subject,
            sessionId: id,
          );
        }

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
                // Time block
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.accentLight,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showDate)
                        Text(fmtDate(scheduled),
                          style: const TextStyle(fontSize: 9, color: AppColors.primary,
                            fontWeight: FontWeight.w600))
                      else
                        const SizedBox.shrink(),
                      Text(fmtTime(scheduled),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                    ],
                  ),
                ),
                const SizedBox(width: 11),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(studentName,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                      Text('$subject · $duration د',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: stateInfo.$3, borderRadius: BorderRadius.circular(6)),
                  child: Text(stateInfo.$1,
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700,
                      color: stateInfo.$2)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ActiveCard extends StatelessWidget {
  final String studentName;
  final String subject;
  final String sessionId;
  const _ActiveCard({required this.studentName, required this.subject, required this.sessionId});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/teacher/session/$sessionId'),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF16A34A), Color(0xFF0F7C38)],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 7, height: 7,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    const Text('جلسة نشطة الآن',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                  ],
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14),
              ],
            ),
            const SizedBox(height: 9),
            Align(
              alignment: Alignment.centerRight,
              child: Text('$studentName · $subject',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
            const SizedBox(height: 11),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(11)),
              alignment: Alignment.center,
              child: const Text('العودة إلى الجلسة',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F7C38))),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Completed list ────────────────────────────────────────────

const _completedStateLabels = {
  'COMPLETED':        ('مكتملة',   Color(0xFF15805F), Color(0xFFE3F6EF)),
  'CANCELLED':        ('ملغاة',    Color(0xFFE03E3E), Color(0xFFFDECEC)),
  'TEACHER_REJECTED': ('مرفوضة',   Color(0xFFC77A1A), Color(0xFFFEF3E2)),
  'STUDENT_NO_SHOW':  ('غياب طالب',Color(0xFF5B43D6), Color(0xFFF0EDFF)),
};

class _CompletedList extends StatelessWidget {
  final List<Map<String, dynamic>> sessions;
  final String Function(String) fmtDate;
  final String Function(String) fmtTime;

  const _CompletedList({
    required this.sessions,
    required this.fmtDate,
    required this.fmtTime,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
      itemCount: sessions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final s = sessions[i];
        final id         = s['id'] as String;
        final studentMap = s['student'] as Map? ?? {};
        final studentName = (studentMap['full_name'] as String?) ?? 'طالب';
        final subject     = (s['subject'] as String?) ?? '';
        final scheduled   = (s['scheduled_at'] as String?) ?? '';
        final state       = (s['state'] as String?) ?? '';
        final amount      = (s['amount'] as num?)?.toDouble() ?? 0;
        final stateInfo   = _completedStateLabels[state]
            ?? (state, AppColors.textHint, AppColors.surfaceAlt);

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
                  decoration: BoxDecoration(
                    color: AppColors.accentLight, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.check_circle_outline_rounded,
                    color: AppColors.primary, size: 22),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(studentName,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                      Text('$subject · ${fmtDate(scheduled)} ${fmtTime(scheduled)}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (state == 'COMPLETED')
                      Text('+${amount.toInt()} أوقية',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                          color: Color(0xFF1B9E77))),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: stateInfo.$3, borderRadius: BorderRadius.circular(5)),
                      child: Text(stateInfo.$1,
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                          color: stateInfo.$2)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
