import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/levels.dart';
import '../../../core/providers/sessions_provider.dart';
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
  int     _selectedDay      = 0;
  int?    _selectedSlotIdx;
  int     _selectedDuration = 1; // 0=30, 1=60, 2=90
  String? _selectedLevel;
  bool    _loading = false;
  String? _error;

  static const _durations = [30, 60, 90];

  // 7 days starting from today
  List<DateTime> get _days {
    final today = DateTime.now();
    return List.generate(7, (i) =>
      DateTime(today.year, today.month, today.day).add(Duration(days: i)));
  }

  String _dayName(DateTime d) {
    const names = ['الأح', 'الإث', 'الثل', 'الأر', 'الخم', 'الجم', 'السب'];
    return names[d.weekday % 7];
  }

  // Generate hourly slots for a day. bookedTimes marks already-taken slots as unselectable.
  List<Map<String, dynamic>> _slotsForDay(
    DateTime day,
    List<Map<String, dynamic>> availability,
    int durationMinutes,
    List<DateTime> bookedTimes,
  ) {
    final dayOfWeek = day.weekday % 7; // Dart: 1=Mon..7=Sun → 0=Sun..6=Sat
    final now = DateTime.now();
    final isToday = day.year == now.year &&
        day.month == now.month &&
        day.day == now.day;

    final ranges = availability.where((a) => a['day_of_week'] == dayOfWeek).toList();
    if (ranges.isEmpty) return [];

    final slots = <Map<String, dynamic>>[];

    for (final range in ranges) {
      final startStr = range['start_time'] as String;
      final endStr   = range['end_time']   as String;
      final sH = int.parse(startStr.split(':')[0]);
      final sM = int.parse(startStr.split(':')[1]);
      final eH = int.parse(endStr.split(':')[0]);
      final eM = int.parse(endStr.split(':')[1]);

      var h = sH; var m = sM;
      while (true) {
        final slotEndMin = h * 60 + m + durationMinutes;
        if (slotEndMin > eH * 60 + eM) break;

        // skip past slots for today (need at least 30 min buffer)
        if (isToday) {
          final slotDt = DateTime(day.year, day.month, day.day, h, m);
          if (slotDt.isBefore(now.add(const Duration(minutes: 30)))) {
            m += 60; if (m >= 60) { h++; m -= 60; }
            continue;
          }
        }

        // Check if this slot overlaps any existing confirmed/pending session.
        // A slot at (h, m) is blocked if any booked session starts within
        // [slotStart - existingDuration, slotStart + durationMinutes).
        // Simple check: any booked session that starts at the same hour:minute.
        final slotStart = DateTime(day.year, day.month, day.day, h, m);
        final isBooked = bookedTimes.any((bt) {
          final diff = bt.difference(slotStart).inMinutes.abs();
          return diff < durationMinutes;
        });

        final period = h >= 12 ? 'م' : 'ص';
        final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
        slots.add({
          'h':      h,
          'm':      m,
          'label':  '$h12:${m.toString().padLeft(2, '0')} $period',
          'booked': isBooked,
        });

        m += 60;
        if (m >= 60) { h++; m -= 60; }
      }
    }

    return slots;
  }

  @override
  void dispose() { _noteCtrl.dispose(); super.dispose(); }

  Future<void> _pickLevel(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        minChildSize: 0.4,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                width: 40, height: 5,
                margin: const EdgeInsets.only(top: 10, bottom: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFD5DBE0),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(22, 0, 22, 14),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('اختر مستواك الدراسي',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: ctrl,
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                  children: AppLevels.groups.map((group) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8, top: 4),
                          child: Text(group.title,
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textHint,
                                  letterSpacing: 0.4)),
                        ),
                        ...group.levels.map((lvl) {
                          final sel = _selectedLevel == lvl;
                          return GestureDetector(
                            onTap: () {
                              setState(() => _selectedLevel = lvl);
                              Navigator.pop(context);
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 13),
                              decoration: BoxDecoration(
                                color: sel
                                    ? AppColors.accentLight
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: sel
                                      ? AppColors.primary
                                      : AppColors.border,
                                  width: sel ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(lvl,
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: sel
                                                ? AppColors.primary
                                                : AppColors.textPrimary)),
                                  ),
                                  if (sel)
                                    const Icon(Icons.check_rounded,
                                        color: AppColors.primary, size: 18),
                                ],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 8),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _send(double pricePerHour, String subject,
      List<Map<String, dynamic>> slots) async {
    if (_selectedSlotIdx == null || _selectedSlotIdx! >= slots.length) {
      setState(() => _error = 'يرجى اختيار وقت متاح');
      return;
    }
    if (slots[_selectedSlotIdx!]['booked'] == true) {
      setState(() => _error = 'هذا الوقت محجوز مسبقاً، اختر وقتاً آخر');
      return;
    }
    if (_selectedLevel == null) {
      setState(() => _error = 'يرجى تحديد مستواك الدراسي');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final days     = _days;
      final day      = days[_selectedDay];
      final slot     = slots[_selectedSlotIdx!];
      final duration = _durations[_selectedDuration];
      final amount   = pricePerHour * duration / 60;

      final scheduledAt = DateTime(
        day.year, day.month, day.day, slot['h'] as int, slot['m'] as int);

      final sessionId = await SessionService.requestSession(
        teacherId:       widget.teacherId,
        scheduledAt:     scheduledAt,
        durationMinutes: duration,
        amount:          amount,
        subject:         subject,
        studentLevel:    _selectedLevel,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );

      if (mounted) context.push('/request-sent/$sessionId');
    } catch (e) {
      final msg = e.toString();
      setState(() => _error = msg.contains('double-booking') || msg.contains('conflict')
          ? 'هذا الوقت محجوز مسبقاً، اختر وقتاً آخر'
          : 'حدث خطأ أثناء إرسال الطلب، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final teacherAsync     = ref.watch(teacherProvider(widget.teacherId));
    final availabilityAsync = ref.watch(teacherAvailabilityProvider(widget.teacherId));

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
          if (teacher == null) return const Center(child: Text('الأستاذ غير موجود'));

          final days = _days;
          final selectedDay     = days[_selectedDay];
          final allAvailability = availabilityAsync.value ?? [];
          final duration        = _durations[_selectedDuration];
          final bookedTimes     = ref.watch(teacherBookedTimesProvider((
            teacherId: widget.teacherId,
            date: selectedDay,
          ))).valueOrNull ?? [];
          final slots = _slotsForDay(selectedDay, allAvailability, duration, bookedTimes);
          final total = teacher.pricePerHour * duration / 60;

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 12),
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

                      // Teacher card
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
                              decoration: BoxDecoration(
                                color: AppColors.accentLight,
                                borderRadius: BorderRadius.circular(12)),
                              alignment: Alignment.center,
                              child: Text(teacher.initial,
                                style: const TextStyle(fontSize: 18,
                                  fontWeight: FontWeight.w700, color: AppColors.primary)),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(teacher.name,
                                  style: const TextStyle(fontSize: 14,
                                    fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                Text('${teacher.subject} · ${teacher.pricePerHour.toInt()} أوقية/ساعة',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Day picker ──────────────────────────────
                      _sectionTitle('اختر اليوم'),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 66,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: days.length,
                          itemBuilder: (_, i) {
                            final sel = i == _selectedDay;
                            final d   = days[i];
                            final isToday = i == 0;
                            // Check if teacher has any availability this weekday
                            final dowSlots = allAvailability
                                .where((a) => a['day_of_week'] == d.weekday % 7)
                                .toList();
                            final hasAvail = dowSlots.isNotEmpty;

                            return GestureDetector(
                              onTap: hasAvail ? () => setState(() {
                                _selectedDay     = i;
                                _selectedSlotIdx = null;
                              }) : null,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                margin: const EdgeInsets.only(left: 8),
                                width: 58,
                                decoration: BoxDecoration(
                                  color: sel
                                      ? AppColors.primary
                                      : hasAvail
                                          ? AppColors.surface
                                          : AppColors.surfaceAlt,
                                  borderRadius: BorderRadius.circular(13),
                                  border: Border.all(
                                    color: sel
                                        ? AppColors.primary
                                        : hasAvail
                                            ? AppColors.border
                                            : AppColors.border.withValues(alpha: 0.4),
                                    width: sel ? 1.5 : 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(isToday ? 'اليوم' : _dayName(d),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: sel
                                            ? Colors.white70
                                            : hasAvail
                                                ? AppColors.textHint
                                                : AppColors.textHint.withValues(alpha: 0.4),
                                      )),
                                    const SizedBox(height: 2),
                                    Text('${d.day}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: sel
                                            ? Colors.white
                                            : hasAvail
                                                ? AppColors.textPrimary
                                                : AppColors.textHint.withValues(alpha: 0.4),
                                      )),
                                    if (!hasAvail)
                                      Container(
                                        margin: const EdgeInsets.only(top: 2),
                                        width: 16, height: 2,
                                        decoration: BoxDecoration(
                                          color: AppColors.border,
                                          borderRadius: BorderRadius.circular(1)),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('الأيام الباهتة غير متاحة للأستاذ',
                        style: const TextStyle(fontSize: 10.5, color: AppColors.textHint)),
                      const SizedBox(height: 20),

                      // ── Duration (before time so slots recalculate) ──
                      _sectionTitle('المدة'),
                      const SizedBox(height: 10),
                      Row(
                        children: List.generate(_durations.length, (i) {
                          final sel = i == _selectedDuration;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _selectedDuration = i;
                                  _selectedSlotIdx  = null;
                                }),
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
                                    style: TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.w700,
                                      color: sel ? AppColors.primary : AppColors.textPrimary)),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 20),

                      // ── Time slots ──────────────────────────────
                      _sectionTitle('اختر الوقت'),
                      const SizedBox(height: 10),

                      if (availabilityAsync.isLoading)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2),
                          ),
                        )
                      else if (slots.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 22),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceAlt,
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.event_busy_rounded,
                                color: AppColors.textHint, size: 32),
                              const SizedBox(height: 8),
                              Text(
                                allAvailability.any(
                                  (a) => a['day_of_week'] == days[_selectedDay].weekday % 7)
                                  ? 'لا توجد أوقات متاحة لهذا اليوم بعد الآن'
                                  : 'الأستاذ غير متاح هذا اليوم',
                                style: const TextStyle(
                                  fontSize: 13, color: AppColors.textHint)),
                            ],
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8, runSpacing: 8,
                          children: List.generate(slots.length, (i) {
                            final sel      = i == _selectedSlotIdx;
                            final isBooked = slots[i]['booked'] as bool;
                            return GestureDetector(
                              onTap: isBooked ? null : () => setState(() => _selectedSlotIdx = i),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isBooked
                                      ? AppColors.surfaceAlt
                                      : sel ? AppColors.primary : AppColors.surface,
                                  borderRadius: BorderRadius.circular(11),
                                  border: Border.all(
                                    color: isBooked
                                        ? AppColors.border
                                        : sel ? AppColors.primary : AppColors.border,
                                    width: sel ? 1.5 : 1),
                                ),
                                child: Text(slots[i]['label'] as String,
                                  style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w700,
                                    color: isBooked
                                        ? AppColors.textHint
                                        : sel ? Colors.white : AppColors.textPrimary,
                                    decoration: isBooked ? TextDecoration.lineThrough : null,
                                    decorationColor: AppColors.textHint,
                                  )),
                              ),
                            );
                          }),
                        ),
                      const SizedBox(height: 20),

                      // ── Level picker ────────────────────────────
                      _sectionTitle('مستواك الدراسي *'),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => _pickLevel(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                          decoration: BoxDecoration(
                            color: _selectedLevel != null
                                ? AppColors.accentLight
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: _selectedLevel != null
                                  ? AppColors.primary
                                  : AppColors.borderStrong,
                              width: _selectedLevel != null ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.school_rounded,
                                size: 18,
                                color: _selectedLevel != null
                                    ? AppColors.primary
                                    : AppColors.textHint,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _selectedLevel ?? 'اختر مستواك الدراسي…',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: _selectedLevel != null
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: _selectedLevel != null
                                        ? AppColors.textPrimary
                                        : AppColors.textHint,
                                  ),
                                ),
                              ),
                              const Icon(Icons.keyboard_arrow_down_rounded,
                                  size: 20, color: AppColors.textHint),
                            ],
                          ),
                        ),
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
                ),
              ),

              // ── Bottom bar ──────────────────────────────────────
              Container(
                color: AppColors.surface,
                padding: EdgeInsets.only(
                  left: 22, right: 22, top: 14,
                  bottom: MediaQuery.of(context).padding.bottom + 14,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('الإجمالي المتوقع',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        Text('${total.toInt()} أوقية',
                          style: const TextStyle(fontSize: 15,
                            fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const InfoBanner(
                      text: 'الدفع يبدأ بعد موافقة الأستاذ. لن يُطلب منك الدفع الآن.'),
                    const SizedBox(height: 12),
                    AppButton(
                      label: 'إرسال الطلب',
                      isLoading: _loading,
                      onTap: slots.isNotEmpty
                          ? () => _send(teacher.pricePerHour, teacher.subject, slots)
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(t,
    style: const TextStyle(
      fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary));
}
