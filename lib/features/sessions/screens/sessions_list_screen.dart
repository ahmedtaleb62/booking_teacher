import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/session_states.dart';
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
    final sessionsAsync = ref.watch(studentSessionsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: const Text('جلساتي'),
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textHint,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          tabs: const [
            Tab(text: 'الجارية'),
            Tab(text: 'المعلّقة'),
            Tab(text: 'المنتهية'),
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
              const Text('تعذّر تحميل الجلسات', style: TextStyle(fontSize: 15, color: AppColors.textPrimary)),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => ref.invalidate(studentSessionsProvider),
                child: const Text('إعادة المحاولة'),
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
         SessionState.paymentRejected, SessionState.paymentConfirmed].contains(s.state)).toList();
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
            const Text('لا توجد جلسات هنا',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            const Text('ابحث عن أستاذ وابدأ رحلتك التعليمية',
              style: TextStyle(fontSize: 13, color: AppColors.textHint)),
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

  String _formatDate(DateTime dt) {
    const days = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
    final h = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final period = dt.hour >= 12 ? 'م' : 'ص';
    return '${days[dt.weekday % 7]} $h:${dt.minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    final s = session;
    return GestureDetector(
      onTap: () {
        if (s.state == SessionState.activeSession) {
          context.push('/live/${s.id}');
        } else if (s.state == SessionState.awaitingPayment ||
                   s.state == SessionState.teacherApproved ||
                   s.state == SessionState.paymentRejected) {
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
                  decoration: BoxDecoration(
                    color: AppColors.accentLight,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  alignment: Alignment.center,
                  child: Text(s.teacherInitial,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.teacherName,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      Text(s.subject,
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
                _InfoChip(icon: Icons.calendar_today_rounded, label: _formatDate(s.scheduledAt)),
                const SizedBox(width: 12),
                _InfoChip(icon: Icons.timer_outlined, label: '${s.durationMinutes} دقيقة'),
                const Spacer(),
                Text('${s.amount.toInt()} أوقية',
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
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.videocam_rounded, color: AppColors.statusActive, size: 16),
                    SizedBox(width: 6),
                    Text('ادخل الجلسة الآن',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.statusActive)),
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
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.payment_rounded, color: AppColors.statusApproved, size: 16),
                    SizedBox(width: 6),
                    Text('أكمل الدفع الآن',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.statusApproved)),
                  ],
                ),
              ),
            ],
            if (s.state == SessionState.paymentRejected) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.statusRejectedBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.upload_file_rounded, color: AppColors.error, size: 16),
                    SizedBox(width: 6),
                    Text('رُفض الإثبات — أعد الرفع',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.error)),
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
