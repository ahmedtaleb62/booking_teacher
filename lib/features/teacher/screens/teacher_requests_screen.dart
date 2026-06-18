import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';

class TeacherRequestsScreen extends StatefulWidget {
  const TeacherRequestsScreen({super.key});

  @override
  State<TeacherRequestsScreen> createState() => _TeacherRequestsScreenState();
}

class _TeacherRequestsScreenState extends State<TeacherRequestsScreen> with SingleTickerProviderStateMixin {
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
            padding: EdgeInsets.fromLTRB(22, 16, 22, 14),
            child: Text('الطلبات', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: _TabBar(controller: _tabs),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _PendingTab(),
                _ApprovedTab(),
                _RejectedTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  final TabController controller;
  const _TabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => Row(
        children: List.generate(3, (i) {
          final labels = ['جديدة (3)', 'مقبولة', 'مرفوضة'];
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
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sel ? Colors.white : AppColors.textSecondary),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _PendingTab extends StatelessWidget {
  final _requests = const [
    _Req(id: 'req1', initial: 'س', name: 'سيدنا أحمد',      subject: 'رياضيات', when: 'الإثنين 4:00 م',   duration: '60 د', initBg: Color(0xFFE7F1F2), initFg: Color(0xFF1B6B7A)),
    _Req(id: 'req2', initial: 'خ', name: 'خديجة بنت اعل',  subject: 'إحصاء',   when: 'الثلاثاء 6:30 م', duration: '60 د', initBg: Color(0xFFFEF3E2), initFg: Color(0xFFC77A1A)),
    _Req(id: 'req3', initial: 'م', name: 'محمد محمود',      subject: 'جبر',     when: 'الأربعاء 5:00 م',  duration: '30 د', initBg: Color(0xFFF0EDFF), initFg: Color(0xFF7B61FF)),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      children: [
        ..._requests.map((r) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _RequestCard(req: r),
        )),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _RequestCard extends StatelessWidget {
  final _Req req;
  const _RequestCard({required this.req});

  @override
  Widget build(BuildContext context) {
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
                decoration: BoxDecoration(color: req.initBg, borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: Text(req.initial, style: TextStyle(color: req.initFg, fontWeight: FontWeight.w700, fontSize: 17)),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(req.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text('${req.subject} · ${req.when} · ${req.duration}', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFFEF3E2), borderRadius: BorderRadius.circular(6)),
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
                    side: const BorderSide(color: AppColors.borderStrong),
                    foregroundColor: AppColors.error,
                  ),
                  child: const Text('رفض', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: () => context.push('/teacher/request/${req.id}'),
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

class _ApprovedTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      children: [
        _StatusCard(
          initial: 'س', name: 'سيدنا أحمد', subject: 'رياضيات', when: 'الإثنين 4:00 م',
          badge: 'بانتظار الدفع', badgeBg: const Color(0xFFF0EDFF), badgeFg: const Color(0xFF5B43D6),
          initBg: const Color(0xFFE7F1F2), initFg: const Color(0xFF1B6B7A),
        ),
        const SizedBox(height: 12),
        _StatusCard(
          initial: 'ن', name: 'نور محمد', subject: 'كيمياء', when: 'الثلاثاء 2:00 م',
          badge: 'مؤكّد', badgeBg: const Color(0xFFE3F6EF), badgeFg: const Color(0xFF15805F),
          initBg: const Color(0xFFE3F6EF), initFg: const Color(0xFF1B9E77),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String initial;
  final String name;
  final String subject;
  final String when;
  final String badge;
  final Color badgeBg;
  final Color badgeFg;
  final Color initBg;
  final Color initFg;

  const _StatusCard({
    required this.initial, required this.name, required this.subject, required this.when,
    required this.badge, required this.badgeBg, required this.badgeFg,
    required this.initBg, required this.initFg,
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
            width: 42, height: 42,
            decoration: BoxDecoration(color: initBg, borderRadius: BorderRadius.circular(12)),
            alignment: Alignment.center,
            child: Text(initial, style: TextStyle(color: initFg, fontWeight: FontWeight.w700, fontSize: 17)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                Text('$subject · $when', style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(6)),
            child: Text(badge, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: badgeFg)),
          ),
        ],
      ),
    );
  }
}

class _RejectedTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: AppColors.surfaceAlt, borderRadius: BorderRadius.circular(18)),
            child: const Icon(Icons.do_not_disturb_alt_rounded, color: AppColors.textHint, size: 30),
          ),
          const SizedBox(height: 14),
          const Text('لا توجد طلبات مرفوضة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _Req {
  final String id;
  final String initial;
  final String name;
  final String subject;
  final String when;
  final String duration;
  final Color initBg;
  final Color initFg;
  const _Req({required this.id, required this.initial, required this.name, required this.subject, required this.when, required this.duration, required this.initBg, required this.initFg});
}
