import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/levels.dart';
import '../../../core/constants/subjects.dart';
import '../../../core/extensions/l10n_extension.dart';
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
  int     _selectedDuration = 0; // 0=5(test), 1=30, 2=60, 3=90
  String? _selectedLevel;
  bool    _loading = false;
  String? _error;

  static const _durations = [5, 30, 60, 90];

  List<DateTime> get _days {
    final today = DateTime.now();
    return List.generate(7, (i) =>
      DateTime(today.year, today.month, today.day).add(Duration(days: i)));
  }

  String _dayName(DateTime d) {
    final l = context.l10n;
    final idx = d.weekday % 7;
    return [
      l.weekdayShortSun, l.weekdayShortMon, l.weekdayShortTue, l.weekdayShortWed,
      l.weekdayShortThu, l.weekdayShortFri, l.weekdayShortSat,
    ][idx];
  }

  List<Map<String, dynamic>> _slotsForDay(
    DateTime day,
    List<Map<String, dynamic>> availability,
    int durationMinutes,
    List<DateTime> bookedTimes,
  ) {
    final l = context.l10n;
    final dayOfWeek = day.weekday % 7;
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

        if (isToday) {
          final slotDt = DateTime(day.year, day.month, day.day, h, m);
          if (slotDt.isBefore(now.add(const Duration(minutes: 30)))) {
            m += durationMinutes; h += m ~/ 60; m = m % 60;
            continue;
          }
        }

        final slotStart = DateTime(day.year, day.month, day.day, h, m);
        final isBooked = bookedTimes.any((bt) {
          final diff = bt.difference(slotStart).inMinutes.abs();
          return diff < durationMinutes;
        });

        final period = h >= 12 ? l.timePmAbbrev : l.timeAmAbbrev;
        final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
        slots.add({
          'h':      h,
          'm':      m,
          'label':  '$h12:${m.toString().padLeft(2, '0')} $period',
          'booked': isBooked,
        });

        m += durationMinutes; h += m ~/ 60; m = m % 60;
      }
    }

    return slots;
  }

  @override
  void dispose() { _noteCtrl.dispose(); super.dispose(); }

  Future<void> _pickLevel(BuildContext context) async {
    final l = context.l10n;
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
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(l.reqSessionChooseLevel,
                      style: const TextStyle(
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
                          child: Text(translateLevelGroup(group.title, Localizations.localeOf(context)),
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
                                    child: Text(translateLevel(lvl, Localizations.localeOf(context)),
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
    final l = context.l10n;
    if (_selectedSlotIdx == null || _selectedSlotIdx! >= slots.length) {
      setState(() => _error = l.reqSessionErrNoSlot);
      return;
    }
    if (slots[_selectedSlotIdx!]['booked'] == true) {
      setState(() => _error = l.reqSessionErrBooked);
      return;
    }
    if (_selectedLevel == null) {
      setState(() => _error = l.reqSessionErrNoLevel);
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
          ? context.l10n.reqSessionErrBooked
          : context.l10n.reqSessionErrGeneral);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
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
        title: Text(l.reqSessionTitle),
      ),
      body: teacherAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.reqSessionErrLoadTeacher),
              TextButton(
                onPressed: () => ref.invalidate(teacherProvider(widget.teacherId)),
                child: Text(l.commonRetry),
              ),
            ],
          ),
        ),
        data: (teacher) {
          if (teacher == null) return Center(child: Text(l.reqSessionTeacherNotFound));

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
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: teacher.avatarUrl != null && teacher.avatarUrl!.isNotEmpty
                                  ? Image.network(
                                      teacher.avatarUrl!,
                                      width: 44, height: 44,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => _initialAvatar(teacher.initial),
                                    )
                                  : _initialAvatar(teacher.initial),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(teacher.name,
                                  style: const TextStyle(fontSize: 14,
                                    fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                                Text('${translateSubject(teacher.subject, Localizations.localeOf(context))} · ${teacher.pricePerHour.toInt()} ${l.unitOugiyaPerHour}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Day picker ──────────────────────────────
                      _sectionTitle(l.reqSessionSelectDay),
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
                                    Text(isToday ? l.reqSessionToday : _dayName(d),
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
                      Text(l.reqSessionUnavailableHint,
                        style: const TextStyle(fontSize: 10.5, color: AppColors.textHint)),
                      const SizedBox(height: 20),

                      // ── Duration ────────────────────────────────
                      _sectionTitle(l.reqSessionDuration),
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
                                  child: Text('${_durations[i]} ${l.unitMinAbbrev}',
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
                      _sectionTitle(l.reqSessionSelectTime),
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
                                  ? l.reqSessionNoSlotsLeft
                                  : l.reqSessionTeacherUnavailable,
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
                      _sectionTitle(l.reqSessionYourLevel),
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
                                  _selectedLevel ?? l.reqSessionChooseLevelHint,
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
                      _sectionTitle(l.reqSessionNoteLabel),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _noteCtrl,
                        maxLines: 3,
                        decoration: InputDecoration(hintText: l.reqSessionNoteHint),
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
                        Text(l.reqSessionTotal,
                          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        Text('${total.toInt()} ${l.dashOugiya}',
                          style: const TextStyle(fontSize: 15,
                            fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    InfoBanner(text: l.reqSessionPaymentNote),
                    const SizedBox(height: 12),
                    AppButton(
                      label: l.reqSessionSubmit,
                      isLoading: _loading,
                      onTap: slots.isNotEmpty
                          ? () => _send(teacher.pricePerHour, teacher.subject, slots)
                          : () => setState(() => _error = allAvailability.isEmpty
                              ? l.reqSessionTeacherUnavailable
                              : l.reqSessionNoSlotsLeft),
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

  Widget _initialAvatar(String initial) => Container(
    width: 44, height: 44,
    color: AppColors.accentLight,
    alignment: Alignment.center,
    child: Text(initial,
      style: const TextStyle(
          fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.primary)),
  );

  Widget _sectionTitle(String t) => Text(t,
    style: const TextStyle(
      fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary));
}
