import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';

class TeacherDashboardScreen extends StatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  State<TeacherDashboardScreen> createState() => _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState extends State<TeacherDashboardScreen> {
  bool _isAvailable = true;

  final List<_PendingRequest> _requests = const [
    _PendingRequest(id: 'req1', initial: 'س', name: 'سيدنا أحمد',      subject: 'رياضيات', when: 'الإثنين 4:00 م', initBg: Color(0xFFE7F1F2), initFg: Color(0xFF1B6B7A)),
    _PendingRequest(id: 'req2', initial: 'خ', name: 'خديجة بنت اعل',  subject: 'إحصاء',  when: 'الثلاثاء 6:30 م', initBg: Color(0xFFFEF3E2), initFg: Color(0xFFC77A1A)),
    _PendingRequest(id: 'req3', initial: 'م', name: 'محمد محمود',      subject: 'جبر',    when: 'الأربعاء 5:00 م', initBg: Color(0xFFF0EDFF), initFg: Color(0xFF7B61FF)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _Header(isAvailable: _isAvailable, onToggle: (v) => setState(() => _isAvailable = v))),
          SliverToBoxAdapter(child: _StatsRow()),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverToBoxAdapter(child: _SectionHeader(title: 'طلبات جديدة', badge: '${_requests.length} بانتظارك', badgeFg: const Color(0xFFC77A1A), badgeBg: const Color(0xFFFEF3E2))),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _RequestCard(request: _requests[i]),
              childCount: _requests.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          const SliverToBoxAdapter(child: _SectionHeader(title: 'الجلسات القادمة')),
          SliverToBoxAdapter(child: _UpcomingCard()),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final bool isAvailable;
  final ValueChanged<bool> onToggle;
  const _Header({required this.isAvailable, required this.onToggle});

  @override
  Widget build(BuildContext context) {
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
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(13)),
                  alignment: Alignment.center,
                  child: const Text('م', style: TextStyle(color: Color(0xFF1B6B7A), fontWeight: FontWeight.w700, fontSize: 19)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('أهلاً،', style: TextStyle(fontSize: 12, color: Color(0xFFCFE6EA))),
                      const Text('د. محمد الأمين', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => onToggle(!isAvailable),
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 46, height: 27,
                        decoration: BoxDecoration(
                          color: isAvailable ? const Color(0xFF7BE0C0) : Colors.white24,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Align(
                          alignment: isAvailable ? Alignment.centerLeft : Alignment.centerRight,
                          child: Container(
                            margin: const EdgeInsets.all(3),
                            width: 21, height: 21,
                            decoration: const BoxDecoration(color: Color(0xFF11313A), shape: BoxShape.circle),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isAvailable ? 'متاح للحجز' : 'غير متاح',
                        style: const TextStyle(fontSize: 9, color: Color(0xFFCFE6EA), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Earnings card
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
                const Text('أرباح هذا الأسبوع', style: TextStyle(fontSize: 12, color: Color(0xFFCFE6EA))),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('6,375', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(width: 6),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 5),
                      child: Text('أوقية', style: TextStyle(fontSize: 13, color: Color(0xFF7BE0C0))),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('15 جلسة مكتملة · بعد عمولة 15%',
                    style: TextStyle(fontSize: 11, color: Color(0xFF9DB2B8))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
      child: Row(
        children: [
          _StatCard(value: '3',   label: 'طلب جديد',  color: const Color(0xFFF2994A)),
          const SizedBox(width: 10),
          _StatCard(value: '2',   label: 'جلسات اليوم', color: AppColors.textPrimary),
          const SizedBox(width: 10),
          _StatCard(value: '98%', label: 'الحضور',     color: AppColors.success),
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
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          if (badge != null) ...[
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: badgeBg ?? AppColors.accentLight,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(badge!, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: badgeFg ?? AppColors.primary)),
            ),
          ],
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final _PendingRequest request;
  const _RequestCard({required this.request});

  @override
  Widget build(BuildContext context) {
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
                decoration: BoxDecoration(
                  color: request.initBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(request.initial, style: TextStyle(color: request.initFg, fontWeight: FontWeight.w700, fontSize: 17)),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text('${request.subject} · ${request.when}', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3E2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('REQUESTED', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFFC77A1A))),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    side: const BorderSide(color: Color(0xFFE6E9ED)),
                    foregroundColor: AppColors.textSecondary,
                  ),
                  child: const Text('رفض', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => context.push('/teacher/request/${request.id}'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('مراجعة وقبول', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UpcomingCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 22),
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
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Column(
              children: const [
                Text('4:00', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary)),
                Text('مساءً', style: TextStyle(fontSize: 9, color: AppColors.primary)),
              ],
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('سيدنا أحمد · رياضيات', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                Text('60 دقيقة · بعد 25 دقيقة', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE3F6EF),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('مؤكّد', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF15805F))),
          ),
        ],
      ),
    );
  }
}

class _PendingRequest {
  final String id;
  final String initial;
  final String name;
  final String subject;
  final String when;
  final Color initBg;
  final Color initFg;
  const _PendingRequest({
    required this.id,
    required this.initial,
    required this.name,
    required this.subject,
    required this.when,
    required this.initBg,
    required this.initFg,
  });
}
