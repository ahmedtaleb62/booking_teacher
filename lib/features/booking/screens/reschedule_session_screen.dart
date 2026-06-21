import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/session_states.dart';
import '../../../core/providers/sessions_provider.dart';
import '../../../core/services/session_service.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/info_banner.dart';

class RescheduleSessionScreen extends ConsumerStatefulWidget {
  final String parentSessionId;
  const RescheduleSessionScreen({super.key, required this.parentSessionId});
  @override
  ConsumerState<RescheduleSessionScreen> createState() => _RescheduleSessionScreenState();
}

class _RescheduleSessionScreenState extends ConsumerState<RescheduleSessionScreen> {
  DateTime? _selectedDay;
  int? _selectedHour;
  int _duration = 60;
  bool _loading = false;
  String? _error;

  static const _durations = [30, 60, 90];
  static const _hours = [8, 10, 14, 16, 18, 20];

  List<DateTime> get _availableDays {
    final now = DateTime.now();
    return List.generate(7, (i) => DateTime(now.year, now.month, now.day + i + 1));
  }

  String _dayLabel(DateTime dt) {
    const days = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
    return '${days[dt.weekday % 7]}\n${dt.day}/${dt.month}';
  }

  String _hourLabel(int h) {
    final period = h >= 12 ? 'م' : 'ص';
    final h12 = h > 12 ? h - 12 : h;
    return '$h12:00 $period';
  }

  Future<void> _submit() async {
    if (_selectedDay == null || _selectedHour == null) {
      setState(() => _error = 'اختر اليوم والوقت');
      return;
    }
    setState(() { _loading = true; _error = null; });

    try {
      final scheduledAt = DateTime(
        _selectedDay!.year, _selectedDay!.month, _selectedDay!.day, _selectedHour!,
      );
      final newId = await SessionService.rescheduleSession(
        parentSessionId: widget.parentSessionId,
        newScheduledAt: scheduledAt,
        durationMinutes: _duration,
      );
      ref.invalidate(studentSessionsProvider);
      if (!mounted) return;
      context.go('/session/$newId');
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString().contains('double-booking')
            ? 'هذا الوقت محجوز مسبقاً، اختر وقتاً آخر'
            : 'حدث خطأ، حاول مرة أخرى';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionProvider(widget.parentSessionId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.textPrimary),
          ),
          onPressed: () => context.pop(),
        ),
        title: const Text('إعادة الجدولة'),
      ),
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('خطأ: $e')),
        data: (session) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (session?.state == SessionState.teacherNoShow)
                const InfoBanner(
                  text: 'الأستاذ لم يحضر — سيتم إنشاء جلسة جديدة مؤكّدة مباشرةً بدون دفع إضافي.',
                  type: BannerType.info,
                )
              else
                InfoBanner(
                  text: 'سيتم إنشاء جلسة جديدة بنفس المبلغ (${session?.amount.toInt() ?? 0} أوقية) وتحتاج موافقة الأستاذ.',
                  type: BannerType.info,
                ),
              const SizedBox(height: 20),

              // Teacher card
              if (session != null)
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.accentLight, borderRadius: BorderRadius.circular(12)),
                        alignment: Alignment.center,
                        child: Text(session.teacherInitial,
                          style: const TextStyle(color: AppColors.primary,
                            fontWeight: FontWeight.w700, fontSize: 18)),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(session.teacherName,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                          Text(session.subject,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),

              // Day picker
              const Text('اختر يوماً جديداً',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              SizedBox(
                height: 76,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _availableDays.map((d) {
                    final sel = _selectedDay != null &&
                        _selectedDay!.year == d.year &&
                        _selectedDay!.month == d.month &&
                        _selectedDay!.day == d.day;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedDay = d),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.only(left: 10),
                        width: 66,
                        decoration: BoxDecoration(
                          color: sel ? AppColors.primary : AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: sel ? AppColors.primary : AppColors.border),
                        ),
                        child: Center(
                          child: Text(_dayLabel(d),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700, height: 1.6,
                              color: sel ? Colors.white : AppColors.textPrimary)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 22),

              // Time picker
              const Text('اختر وقتاً',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10, runSpacing: 10,
                children: _hours.map((h) {
                  final sel = _selectedHour == h;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedHour = h),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                      decoration: BoxDecoration(
                        color: sel ? AppColors.primary : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: sel ? AppColors.primary : AppColors.border),
                      ),
                      child: Text(_hourLabel(h),
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                          color: sel ? Colors.white : AppColors.textPrimary)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 22),

              // Duration
              const Text('المدة',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              Row(
                children: _durations.map((d) {
                  final sel = _duration == d;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: GestureDetector(
                        onTap: () => setState(() => _duration = d),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: sel ? AppColors.primary : AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: sel ? AppColors.primary : AppColors.border),
                          ),
                          child: Text('$d د',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                              color: sel ? Colors.white : AppColors.textPrimary)),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDECEC),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(_error!,
                    style: const TextStyle(fontSize: 13, color: Color(0xFFC0392B))),
                ),
              ],
              const SizedBox(height: 28),
              AppButton(
                label: 'إرسال طلب إعادة الجدولة',
                isLoading: _loading,
                onTap: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
