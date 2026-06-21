import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/sessions_provider.dart';

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

  String _fmtDate(String isoStr) {
    final dt = DateTime.tryParse(isoStr);
    if (dt == null) return '';
    const days = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final period = dt.hour >= 12 ? 'م' : 'ص';
    return '${days[dt.weekday % 7]} $h:${dt.minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    final pendingAsync = ref.watch(teacherPendingRequestsProvider);
    final inProgressAsync = ref.watch(teacherInProgressSessionsProvider);
    final rejectedAsync = ref.watch(teacherRejectedSessionsProvider);

    final pendingCount = pendingAsync.value?.length ?? 0;
    final inProgressCount = inProgressAsync.value?.length ?? 0;
    final rejectedCount = rejectedAsync.value?.length ?? 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top),
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 16, 22, 14),
            child: Text('الطلبات',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
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
                // Tab 1 — Pending
                pendingAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  error: (e, _) => _ErrorWidget(onRetry: () => ref.invalidate(teacherPendingRequestsProvider)),
                  data: (list) => list.isEmpty
                      ? const _EmptyTab(icon: Icons.inbox_outlined, label: 'لا توجد طلبات جديدة')
                      : RefreshIndicator(
                          onRefresh: () async => ref.invalidate(teacherPendingRequestsProvider),
                          child: ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                            children: list.map((s) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _PendingCard(session: s, fmtDate: _fmtDate),
                            )).toList(),
                          ),
                        ),
                ),

                // Tab 2 — In Progress
                inProgressAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  error: (e, _) => _ErrorWidget(onRetry: () => ref.invalidate(teacherInProgressSessionsProvider)),
                  data: (list) => list.isEmpty
                      ? const _EmptyTab(icon: Icons.event_note_outlined, label: 'لا توجد جلسات نشطة')
                      : RefreshIndicator(
                          onRefresh: () async => ref.invalidate(teacherInProgressSessionsProvider),
                          child: ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                            children: list.map((s) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _InProgressCard(session: s, fmtDate: _fmtDate),
                            )).toList(),
                          ),
                        ),
                ),

                // Tab 3 — Rejected
                rejectedAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  error: (e, _) => _ErrorWidget(onRetry: () => ref.invalidate(teacherRejectedSessionsProvider)),
                  data: (list) => list.isEmpty
                      ? const _EmptyTab(icon: Icons.do_not_disturb_alt_rounded, label: 'لا توجد طلبات مرفوضة')
                      : RefreshIndicator(
                          onRefresh: () async => ref.invalidate(teacherRejectedSessionsProvider),
                          child: ListView(
                            padding: const EdgeInsets.symmetric(horizontal: 22),
                            children: list.map((s) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _RejectedCard(session: s, fmtDate: _fmtDate),
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
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => Row(
        children: List.generate(3, (i) {
          final labels = [
            'جديدة${pendingCount > 0 ? ' ($pendingCount)' : ''}',
            'جارية${inProgressCount > 0 ? ' ($inProgressCount)' : ''}',
            'مرفوضة${rejectedCount > 0 ? ' ($rejectedCount)' : ''}',
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

// ── Pending card (REQUESTED state) ───────────────────────────
class _PendingCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final String Function(String) fmtDate;
  const _PendingCard({required this.session, required this.fmtDate});

  @override
  Widget build(BuildContext context) {
    final id = session['id'] as String;
    final studentMap = session['student'] as Map? ?? {};
    final studentName = (studentMap['full_name'] as String?) ?? 'طالب';
    final subject = (session['subject'] as String?) ?? '';
    final scheduledAt = (session['scheduled_at'] as String?) ?? '';
    final duration = (session['duration_minutes'] as int?) ?? 60;
    final initial = studentName.isNotEmpty ? studentName[0] : 'ط';

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
                decoration: BoxDecoration(color: AppColors.accentLight, borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: Text(initial,
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 17)),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(studentName,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text('$subject · ${fmtDate(scheduledAt)} · $duration د',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFFEF3E2), borderRadius: BorderRadius.circular(6)),
                child: const Text('جديد',
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFFC77A1A))),
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
                  child: const Text('مراجعة وقبول',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
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
const _stateLabels = {
  'AWAITING_PAYMENT':   ('بانتظار الدفع',  Color(0xFF5B43D6), Color(0xFFF0EDFF)),
  'PAYMENT_SUBMITTED':  ('بانتظار تأكيد',  Color(0xFFC77A1A), Color(0xFFFEF3E2)),
  'PAYMENT_CONFIRMED':  ('دفع مؤكّد',      Color(0xFF15805F), Color(0xFFE3F6EF)),
  'CONFIRMED_BOOKING':  ('مؤكّد',          Color(0xFF15805F), Color(0xFFE3F6EF)),
  'ACTIVE_SESSION':     ('جارية الآن',     Color(0xFF1B6B7A), Color(0xFFE0F4F7)),
};

class _InProgressCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final String Function(String) fmtDate;
  const _InProgressCard({required this.session, required this.fmtDate});

  @override
  Widget build(BuildContext context) {
    final id = session['id'] as String;
    final studentMap = session['student'] as Map? ?? {};
    final studentName = (studentMap['full_name'] as String?) ?? 'طالب';
    final subject = (session['subject'] as String?) ?? '';
    final scheduledAt = (session['scheduled_at'] as String?) ?? '';
    final state = (session['state'] as String?) ?? '';
    final initial = studentName.isNotEmpty ? studentName[0] : 'ط';

    final stateInfo = _stateLabels[state] ?? (state.replaceAll('_', ' '), AppColors.textHint, AppColors.surface);

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
              decoration: BoxDecoration(color: AppColors.accentLight, borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center,
              child: Text(initial,
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 17)),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(studentName,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  Text('$subject · ${fmtDate(scheduledAt)}',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(color: stateInfo.$3, borderRadius: BorderRadius.circular(6)),
              child: Text(stateInfo.$1,
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: stateInfo.$2)),
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
    final studentMap = session['student'] as Map? ?? {};
    final studentName = (studentMap['full_name'] as String?) ?? 'طالب';
    final subject = (session['subject'] as String?) ?? '';
    final scheduledAt = (session['scheduled_at'] as String?) ?? '';
    final reason = (session['rejection_reason'] as String?);
    final initial = studentName.isNotEmpty ? studentName[0] : 'ط';

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
              style: const TextStyle(color: AppColors.textHint, fontWeight: FontWeight.w700, fontSize: 17),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(studentName,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                Text('$subject · ${fmtDate(scheduledAt)}',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                if (reason != null && reason.isNotEmpty)
                  Text('السبب: $reason',
                    style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFDECEC), borderRadius: BorderRadius.circular(6)),
            child: const Text('مرفوض',
              style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFFE03E3E))),
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
            decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(18)),
            child: Icon(icon, color: AppColors.textHint, size: 30),
          ),
          const SizedBox(height: 14),
          Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('تعذّر تحميل البيانات'),
          TextButton(onPressed: onRetry, child: const Text('إعادة المحاولة')),
        ],
      ),
    );
  }
}
