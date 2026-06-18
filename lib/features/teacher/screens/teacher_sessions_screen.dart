import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';

class TeacherSessionsScreen extends StatefulWidget {
  const TeacherSessionsScreen({super.key});

  @override
  State<TeacherSessionsScreen> createState() => _TeacherSessionsScreenState();
}

class _TeacherSessionsScreenState extends State<TeacherSessionsScreen> with SingleTickerProviderStateMixin {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: MediaQuery.of(context).padding.top),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            child: Text('جلساتي', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: _TabRow(controller: _tabs),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _TodayTab(),
                _UpcomingTab(),
                _CompletedTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabRow extends StatelessWidget {
  final TabController controller;
  const _TabRow({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => Row(
        children: List.generate(3, (i) {
          final labels = ['اليوم', 'القادمة', 'المكتملة'];
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
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: sel ? Colors.white : AppColors.textSecondary),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Today Tab ───────────────────────────────────────────────────────────────

class _TodayTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      children: [
        // Active session card
        _ActiveNowCard(onReturn: () => context.push('/teacher/live/sess-active')),
        const SizedBox(height: 12),
        _ScheduledCard(time: '6:30', ampm: 'مساءً', name: 'خديجة بنت اعل · إحصاء',  meta: '60 دقيقة · بعد القبول', badge: 'مؤكّد',              badgeBg: const Color(0xFFE3F6EF), badgeFg: const Color(0xFF15805F)),
        const SizedBox(height: 10),
        _ScheduledCard(time: '8:00', ampm: 'مساءً', name: 'محمد محمود · جبر',          meta: '30 دقيقة',              badge: 'بانتظار الدفع',     badgeBg: const Color(0xFFF0EDFF), badgeFg: const Color(0xFF5B43D6)),
        const SizedBox(height: 10),
        _ScheduledCard(time: '9:15', ampm: 'مساءً', name: 'أمينة سالم · هندسة',         meta: '60 دقيقة',              badge: 'بانتظار موافقتك', badgeBg: const Color(0xFFFEF3E2), badgeFg: const Color(0xFFC77A1A)),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _ActiveNowCard extends StatelessWidget {
  final VoidCallback onReturn;
  const _ActiveNowCard({required this.onReturn});

  @override
  Widget build(BuildContext context) {
    return Container(
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
                  const Text('جلسة نشطة الآن', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                ],
              ),
              const Text('24:31', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 9),
          const Align(
            alignment: Alignment.centerRight,
            child: Text('سيدنا أحمد · رياضيات', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
          const SizedBox(height: 11),
          GestureDetector(
            onTap: onReturn,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(11),
              ),
              alignment: Alignment.center,
              child: const Text('العودة إلى الجلسة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F7C38))),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduledCard extends StatelessWidget {
  final String time;
  final String ampm;
  final String name;
  final String meta;
  final String badge;
  final Color badgeBg;
  final Color badgeFg;

  const _ScheduledCard({
    required this.time,
    required this.ampm,
    required this.name,
    required this.meta,
    required this.badge,
    required this.badgeBg,
    required this.badgeFg,
  });

  @override
  Widget build(BuildContext context) {
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Column(
              children: [
                Text(time, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary)),
                Text(ampm, style: const TextStyle(fontSize: 9, color: AppColors.primary)),
              ],
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                Text(meta, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(7)),
            child: Text(badge, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: badgeFg)),
          ),
        ],
      ),
    );
  }
}

// ─── Upcoming Tab ─────────────────────────────────────────────────────────────

class _UpcomingTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      children: [
        _ScheduledCard(time: 'غد\n2:00',  ampm: 'م',    name: 'نور محمد · كيمياء',        meta: '60 دقيقة · مؤكّد',     badge: 'مؤكّد',         badgeBg: const Color(0xFFE3F6EF), badgeFg: const Color(0xFF15805F)),
        const SizedBox(height: 10),
        _ScheduledCard(time: 'الأربعاء\n5:00', ampm: 'م', name: 'علي سالم · فيزياء', meta: '90 دقيقة · بانتظار الدفع', badge: 'بانتظار الدفع', badgeBg: const Color(0xFFF0EDFF), badgeFg: const Color(0xFF5B43D6)),
        const SizedBox(height: 20),
      ],
    );
  }
}

// ─── Completed Tab ────────────────────────────────────────────────────────────

class _CompletedTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      children: [
        _CompletedCard(name: 'سيدنا أحمد · رياضيات', date: 'اليوم 4:00 م',    amount: '+425', rating: 5),
        const SizedBox(height: 10),
        _CompletedCard(name: 'خديجة · إحصاء',         date: 'أمس 7:30 م',       amount: '+382', rating: 4),
        const SizedBox(height: 10),
        _CompletedCard(name: 'محمد · كيمياء',           date: '13 يونيو 5:00 م',  amount: '+467', rating: 5),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _CompletedCard extends StatelessWidget {
  final String name;
  final String date;
  final String amount;
  final int rating;
  const _CompletedCard({required this.name, required this.date, required this.amount, required this.rating});

  @override
  Widget build(BuildContext context) {
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
            decoration: BoxDecoration(color: AppColors.accentLight, borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                Text(date, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                const SizedBox(height: 3),
                Row(
                  children: List.generate(5, (i) => Icon(Icons.star_rounded, size: 11, color: i < rating ? const Color(0xFFF2A93B) : AppColors.border)),
                ),
              ],
            ),
          ),
          Text(amount, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1B9E77))),
        ],
      ),
    );
  }
}
