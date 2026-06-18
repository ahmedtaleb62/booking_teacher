import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/teachers_provider.dart';
import '../../../core/services/session_service.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/info_banner.dart';

class RequestSessionScreen extends ConsumerStatefulWidget {
  final String teacherId;
  const RequestSessionScreen({super.key, required this.teacherId});
  @override
  ConsumerState<RequestSessionScreen> createState() => _RequestSessionScreenState();
}

class _RequestSessionScreenState extends ConsumerState<RequestSessionScreen> {
  final _noteCtrl = TextEditingController();
  int _selectedDay   = 0;
  int _selectedTime  = 0;
  int _selectedDuration = 1; // 0=30, 1=60, 2=90
  bool _loading = false;
  String? _error;

  static const _durations = [30, 60, 90];

  // Structured times: {hour, minute, label}
  static const _times = [
    {'h': 8,  'm': 0,  'label': '8:00 ص'},
    {'h': 10, 'm': 0,  'label': '10:00 ص'},
    {'h': 14, 'm': 0,  'label': '2:00 م'},
    {'h': 16, 'm': 0,  'label': '4:00 م'},
    {'h': 18, 'm': 0,  'label': '6:00 م'},
    {'h': 20, 'm': 0,  'label': '8:00 م'},
  ];

  List<Map<String, dynamic>> get _days {
    final now = DateTime.now();
    final dayNames = ['الأح', 'الإث', 'الثل', 'الأر', 'الخم', 'الجم', 'السب'];
    return List.generate(5, (i) {
      final d = now.add(Duration(days: i + 1));
      return {'dow': dayNames[d.weekday % 7], 'num': '${d.day}', 'date': d};
    });
  }

  @override
  void dispose() { _noteCtrl.dispose(); super.dispose(); }

  DateTime get _scheduledAt {
    final day = (_days[_selectedDay]['date'] as DateTime);
    final t = _times[_selectedTime];
    return DateTime(day.year, day.month, day.day, t['h'] as int, t['m'] as int);
  }

  Future<void> _send(double pricePerHour, String subject) async {
    setState(() { _loading = true; _error = null; });
    try {
      final duration = _durations[_selectedDuration];
      final amount = pricePerHour * duration / 60;

      final sessionId = await SessionService.requestSession(
        teacherId: widget.teacherId,
        scheduledAt: _scheduledAt,
        durationMinutes: duration,
        amount: amount,
        subject: subject,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );

      if (mounted) context.push('/request-sent/$sessionId');
    } catch (e) {
      setState(() => _error = 'حدث خطأ أثناء إرسال الطلب، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final teacherAsync = ref.watch(teacherProvider(widget.teacherId));

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
        title: const Text('طلب جلسة'),
      ),
      body: teacherAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('تعذّر تحميل بيانات الأستاذ'),
              TextButton(
                onPressed: () => ref.invalidate(teacherProvider(widget.teacherId)),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
        data: (teacher) {
          if (teacher == null) {
            return const Center(child: Text('الأستاذ غير موجود'));
          }

          final days = _days;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDECEC),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(_error!,
                      style: const TextStyle(fontSize: 13, color: Color(0xFFC0392B))),
                  ),

                // Teacher mini card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(color: AppColors.accentLight, borderRadius: BorderRadius.circular(12)),
                        alignment: Alignment.center,
                        child: Text(teacher.initial,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary)),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(teacher.name,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                          Text('${teacher.subject} · ${teacher.pricePerHour.toInt()} أوقية/ساعة',
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Day picker
                _sectionTitle('اختر اليوم'),
                const SizedBox(height: 10),
                Row(
                  children: List.generate(days.length, (i) {
                    final sel = i == _selectedDay;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedDay = i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            decoration: BoxDecoration(
                              color: sel ? AppColors.primary : AppColors.surface,
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(
                                color: sel ? AppColors.primary : AppColors.border,
                                width: sel ? 1.5 : 1),
                            ),
                            child: Column(
                              children: [
                                Text(days[i]['dow'] as String,
                                  style: TextStyle(fontSize: 11,
                                    color: sel ? Colors.white.withValues(alpha: 0.7) : AppColors.textHint)),
                                const SizedBox(height: 2),
                                Text(days[i]['num'] as String,
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                                    color: sel ? Colors.white : AppColors.textPrimary)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),

                // Time picker
                _sectionTitle('اختر الوقت'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: List.generate(_times.length, (i) {
                    final sel = i == _selectedTime;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedTime = i),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: sel ? AppColors.primary : AppColors.surface,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: sel ? AppColors.primary : AppColors.border, width: sel ? 1.5 : 1),
                        ),
                        child: Text(_times[i]['label'] as String,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                            color: sel ? Colors.white : AppColors.textPrimary)),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),

                // Duration
                _sectionTitle('المدة'),
                const SizedBox(height: 10),
                Row(
                  children: List.generate(_durations.length, (i) {
                    final sel = i == _selectedDuration;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedDuration = i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            decoration: BoxDecoration(
                              color: sel ? AppColors.surface : AppColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(
                                color: sel ? AppColors.primary : AppColors.border,
                                width: sel ? 1.5 : 1),
                            ),
                            child: Text('${_durations[i]} د',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                                color: sel ? AppColors.primary : AppColors.textPrimary)),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),

                // Note
                _sectionTitle('وصف الطلب (اختياري)'),
                const SizedBox(height: 10),
                TextField(
                  controller: _noteCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: 'صف ما تحتاج الاستعانة به…'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: teacherAsync.when(
        loading: () => const SizedBox.shrink(),
        error: (_, __) => const SizedBox.shrink(),
        data: (teacher) {
          if (teacher == null) return const SizedBox.shrink();
          final total = teacher.pricePerHour * _durations[_selectedDuration] / 60;
          return Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('الإجمالي المتوقع',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    Text('${total.toInt()} أوقية',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  ],
                ),
                const SizedBox(height: 10),
                const InfoBanner(text: 'الدفع يبدأ بعد موافقة الأستاذ. لن يُطلب منك الدفع الآن.'),
                const SizedBox(height: 12),
                AppButton(
                  label: 'إرسال الطلب',
                  isLoading: _loading,
                  onTap: () => _send(teacher.pricePerHour, teacher.subject),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(t,
    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary));
}
