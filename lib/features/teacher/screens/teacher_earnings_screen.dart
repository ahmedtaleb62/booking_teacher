import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/sessions_provider.dart';
import '../../../core/services/supabase_service.dart';

class TeacherEarningsScreen extends ConsumerWidget {
  const TeacherEarningsScreen({super.key});

  String _fmtDate(String isoStr) {
    final dt = DateTime.tryParse(isoStr);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'اليوم ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  String _fmtAmount(num amt) {
    return amt.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(teacherEarningsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('تعذّر تحميل الأرباح'),
              TextButton(
                onPressed: () => ref.invalidate(teacherEarningsProvider),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
        data: (data) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(teacherEarningsProvider),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            children: [
              SizedBox(height: MediaQuery.of(context).padding.top + 16),
              const Text('الأرباح',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              _BalanceCard(balance: data.totalBalance, fmtAmount: _fmtAmount),
              const SizedBox(height: 16),
              _StatsRow(
                weekEarnings: data.weekEarnings,
                monthEarnings: data.monthEarnings,
                fmtAmount: _fmtAmount,
              ),
              const SizedBox(height: 10),
              _SourcesRow(
                sessionEarnings: data.sessionEarnings,
                courseEarnings: data.courseEarnings,
                fmtAmount: _fmtAmount,
              ),
              const SizedBox(height: 14),
              _CommissionBanner(),
              const SizedBox(height: 20),
              const Text('سجل المعاملات',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              if (data.entries.isEmpty)
                _EmptyLedger()
              else
                ...data.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: _LedgerRow(entry: e, fmtDate: _fmtDate, fmtAmount: _fmtAmount),
                )),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceCard extends StatefulWidget {
  final double balance;
  final String Function(num) fmtAmount;
  const _BalanceCard({required this.balance, required this.fmtAmount});

  @override
  State<_BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<_BalanceCard> {
  bool _loading = false;

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
          const Text('الرصيد الإجمالي المكتسب', style: TextStyle(fontSize: 12, color: Color(0xFF9DB2B8))),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(widget.fmtAmount(widget.balance),
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(width: 6),
              const Padding(
                padding: EdgeInsets.only(bottom: 5),
                child: Text('أوقية', style: TextStyle(fontSize: 13, color: Color(0xFF7BE0C0))),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: _loading ? null : () async {
              final messenger = ScaffoldMessenger.of(context);
              setState(() => _loading = true);
              try {
                await SupabaseService.client.from('session_events').insert({
                  'session_id': null,
                  'event_type': 'WITHDRAWAL_REQUESTED',
                  'actor': 'teacher',
                  'actor_id': SupabaseService.userId,
                  'note': 'طلب سحب من الأستاذ',
                });
              } catch (_) {}
              if (!mounted) return;
              setState(() => _loading = false);
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('تم إرسال طلب السحب إلى الإدارة'),
                  backgroundColor: Color(0xFF1B9E77),
                ),
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
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF11313A)))
                  : const Text('طلب سحب الأرباح',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF11313A))),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final double weekEarnings;
  final double monthEarnings;
  final String Function(num) fmtAmount;
  const _StatsRow({required this.weekEarnings, required this.monthEarnings, required this.fmtAmount});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _StatBox(label: 'هذا الأسبوع', value: fmtAmount(weekEarnings))),
        const SizedBox(width: 10),
        Expanded(child: _StatBox(label: 'هذا الشهر', value: fmtAmount(monthEarnings))),
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
          Text(value,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
        ],
      ),
    );
  }
}

class _SourcesRow extends StatelessWidget {
  final double sessionEarnings;
  final double courseEarnings;
  final String Function(num) fmtAmount;
  const _SourcesRow({
    required this.sessionEarnings,
    required this.courseEarnings,
    required this.fmtAmount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SourceBox(
            icon: Icons.video_call_outlined,
            label: 'من الجلسات',
            value: fmtAmount(sessionEarnings),
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SourceBox(
            icon: Icons.menu_book_outlined,
            label: 'من الدروس',
            value: fmtAmount(courseEarnings),
            color: const Color(0xFF7B61FF),
          ),
        ),
      ],
    );
  }
}

class _SourceBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _SourceBox({
    required this.icon, required this.label,
    required this.value, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 17, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700, color: color)),
                Text(label,
                    style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
              ],
            ),
          ),
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
      child: const Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFC77A1A)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'تخصم المنصة عمولة 15% من كل جلسة ودرس مؤكّد تلقائياً.',
              style: TextStyle(fontSize: 11, color: Color(0xFF8A5A14), height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerRow extends StatelessWidget {
  final Map<String, dynamic> entry;
  final String Function(String) fmtDate;
  final String Function(num) fmtAmount;
  const _LedgerRow({required this.entry, required this.fmtDate, required this.fmtAmount});

  @override
  Widget build(BuildContext context) {
    final amt       = (entry['net_amount'] as num?) ?? 0;
    final createdAt = (entry['created_at'] as String?) ?? '';
    final type      = (entry['type'] as String?) ?? '';

    final isCourse  = type == 'course_subscription';
    final isSession = type == 'session_payment';

    final sessionMap  = entry['session'] as Map?;
    final subject     = (sessionMap?['subject'] as String?) ?? '';
    final studentMap  = sessionMap?['student'] as Map?;
    final studentName = (studentMap?['full_name'] as String?) ?? '';

    final title = isCourse
        ? (entry['description'] as String? ?? 'اشتراك في دورة')
        : isSession
            ? 'جلسة $subject${studentName.isNotEmpty ? ' · $studentName' : ''}'
            : type.replaceAll('_', ' ');

    final iconColor = isCourse
        ? const Color(0xFF7B61FF)
        : isSession
            ? const Color(0xFF1B9E77)
            : AppColors.textSecondary;
    final iconBg = isCourse
        ? const Color(0xFFF0EDFF)
        : isSession
            ? const Color(0xFFE3F6EF)
            : const Color(0xFFEEF0F2);

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
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(
              isCourse
                  ? Icons.menu_book_outlined
                  : isSession
                      ? Icons.video_call_outlined
                      : Icons.swap_horiz_rounded,
              size: 18,
              color: iconColor,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(fmtDate(createdAt),
                  style: const TextStyle(fontSize: 10.5, color: AppColors.textHint)),
              ],
            ),
          ),
          Text(
            '+${fmtAmount(amt)}',
            style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyLedger extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(Icons.receipt_long_outlined, size: 32, color: AppColors.textHint),
          SizedBox(height: 8),
          Text('لا توجد معاملات بعد',
            style: TextStyle(fontSize: 13, color: AppColors.textHint)),
        ],
      ),
    );
  }
}
