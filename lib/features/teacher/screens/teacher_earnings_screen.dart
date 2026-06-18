import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class TeacherEarningsScreen extends StatelessWidget {
  const TeacherEarningsScreen({super.key});

  static const _ledger = [
    _LedgerEntry(glyph: '+', title: 'جلسة رياضيات · سيدنا أحمد',  date: 'اليوم 3:05 م',  amount: '+425', positive: true),
    _LedgerEntry(glyph: '+', title: 'جلسة فيزياء · خديجة',          date: 'أمس 7:30 م',    amount: '+382', positive: true),
    _LedgerEntry(glyph: '↓', title: 'سحب إلى بنكيلي',               date: '14 يونيو',       amount: '−5,000', positive: false),
    _LedgerEntry(glyph: '+', title: 'جلسة كيمياء · محمد محمود',      date: '13 يونيو',       amount: '+467', positive: true),
    _LedgerEntry(glyph: '+', title: 'جلسة إحصاء · خديجة',            date: '12 يونيو',       amount: '+382', positive: true),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          children: [
            const SizedBox(height: 16),
            const Text('الأرباح', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 16),
            _BalanceCard(),
            const SizedBox(height: 16),
            _StatsRow(),
            const SizedBox(height: 14),
            _CommissionBanner(),
            const SizedBox(height: 20),
            const Text('السجل (Ledger)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            ..._ledger.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _LedgerRow(entry: e),
            )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('الرصيد القابل للسحب', style: TextStyle(fontSize: 12, color: Color(0xFF9DB2B8))),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: const [
              Text('12,840', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white)),
              SizedBox(width: 6),
              Padding(
                padding: EdgeInsets.only(bottom: 5),
                child: Text('أوقية', style: TextStyle(fontSize: 13, color: Color(0xFF7BE0C0))),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _WithdrawBtn(),
        ],
      ),
    );
  }
}

class _WithdrawBtn extends StatefulWidget {
  @override
  State<_WithdrawBtn> createState() => _WithdrawBtnState();
}

class _WithdrawBtnState extends State<_WithdrawBtn> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _loading ? null : () async {
        setState(() => _loading = true);
        final messenger = ScaffoldMessenger.of(context);
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        setState(() => _loading = false);
        messenger.showSnackBar(
          const SnackBar(content: Text('تم إرسال طلب السحب إلى الإدارة'), backgroundColor: Color(0xFF1B9E77)),
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
        child: _loading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF11313A)))
            : const Text('سحب إلى بنكيلي', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF11313A))),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatBox(label: 'هذا الأسبوع', value: '6,375'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatBox(label: 'هذا الشهر', value: '28,500'),
        ),
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
          Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
        ],
      ),
    );
  }
}

class _CommissionBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3E2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: const [
          Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFC77A1A)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'تخصم المنصة عمولة 15% من كل جلسة مؤكّدة تلقائياً.',
              style: TextStyle(fontSize: 11, color: Color(0xFF8A5A14), height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  final _LedgerEntry entry;
  const _LedgerRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: entry.positive ? const Color(0xFFE3F6EF) : const Color(0xFFEEF0F2),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Text(
              entry.glyph,
              style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700,
                color: entry.positive ? const Color(0xFF1B9E77) : AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                Text(entry.date, style: const TextStyle(fontSize: 10.5, color: AppColors.textHint)),
              ],
            ),
          ),
          Text(
            entry.amount,
            style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700,
              color: entry.positive ? const Color(0xFF1B9E77) : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerEntry {
  final String glyph;
  final String title;
  final String date;
  final String amount;
  final bool positive;
  const _LedgerEntry({required this.glyph, required this.title, required this.date, required this.amount, required this.positive});
}
