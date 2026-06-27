import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/session_states.dart';
import '../../../core/constants/subjects.dart';
import '../../../core/extensions/l10n_extension.dart';
import '../../../core/providers/sessions_provider.dart';
import '../../../core/providers/teachers_provider.dart';
import '../../../core/services/session_service.dart';
import '../../../l10n/app_localizations.dart';
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
  int? _selectedMinute;
  int _duration = 60;
  bool _loading = false;
  String? _error;

  static const _durations = [5, 30, 60, 90];

  List<DateTime> get _availableDays {
    final now = DateTime.now();
    return List.generate(7, (i) => DateTime(now.year, now.month, now.day + i + 1));
  }

  String _dayLabel(DateTime dt, AppLocalizations l) {
    final days = [l.daySun, l.dayMon, l.dayTue, l.dayWed, l.dayThu, l.dayFri, l.daySat];
    return '${days[dt.weekday % 7]}\n${dt.day}/${dt.month}';
  }

  // Same slot-computation logic as request_session_screen
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
            m += 60; if (m >= 60) { h++; m -= 60; }
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

        m += 60;
        if (m >= 60) { h++; m -= 60; }
      }
    }

    return slots;
  }

  Future<void> _submit() async {
    final l = context.l10n;
    if (_selectedDay == null || _selectedHour == null) {
      setState(() => _error = l.rescheduleErrSelectTime);
      return;
    }
    setState(() { _loading = true; _error = null; });

    try {
      final scheduledAt = DateTime(
        _selectedDay!.year, _selectedDay!.month, _selectedDay!.day,
        _selectedHour!, _selectedMinute ?? 0,
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
      if (mounted) {
        setState(() {
          _error = e.toString().contains('double-booking')
              ? l.rescheduleErrDoubleBooked
              : l.authErrGeneral;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
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
        title: Text(l.rescheduleTitle),
      ),
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text('${l.commonError}: $e')),
        data: (session) {
          if (session == null) return Center(child: Text(l.sessionNotFound));

          final availabilityAsync = ref.watch(teacherAvailabilityProvider(session.teacherId));
          final bookedAsync = _selectedDay == null
              ? null
              : ref.watch(teacherBookedTimesProvider((
                  teacherId: session.teacherId,
                  date: _selectedDay!,
                )));

          final allAvailability = availabilityAsync.value ?? [];
          final bookedTimes     = bookedAsync?.value ?? [];
          final slots = _selectedDay != null
              ? _slotsForDay(_selectedDay!, allAvailability, _duration, bookedTimes)
              : <Map<String, dynamic>>[];

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (session.state == SessionState.teacherNoShow)
                  InfoBanner(text: l.rescheduleNoShowBanner, type: BannerType.info)
                else
                  InfoBanner(
                    text: l.rescheduleSamePriceBanner('${session.amount.toInt()}'),
                    type: BannerType.info,
                  ),
                const SizedBox(height: 20),

                // Teacher card
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
                          color: AppColors.accentLight,
                          borderRadius: BorderRadius.circular(12)),
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
                          Text(translateSubject(session.subject, Localizations.localeOf(context)),
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Day picker
                Text(l.reschedulePickDay,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
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
                        onTap: () => setState(() {
                          _selectedDay = d;
                          _selectedHour = null;
                          _selectedMinute = null;
                        }),
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
                            child: Text(_dayLabel(d, l),
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

                // Duration (affects which slots are available — pick before time)
                Text(l.teacherDurationLabel,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                Row(
                  children: _durations.map((d) {
                    final sel = _duration == d;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10),
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _duration = d;
                            _selectedHour = null;
                            _selectedMinute = null;
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: sel ? AppColors.primary : AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: sel ? AppColors.primary : AppColors.border),
                            ),
                            child: Text(l.dashMinutesShort(d),
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                                color: sel ? Colors.white : AppColors.textPrimary)),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 22),

                // Time slots
                Text(l.reschedulePickTime,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
                const SizedBox(height: 12),
                if (_selectedDay == null)
                  Text(l.reschedulePickDay,
                    style: const TextStyle(fontSize: 12, color: AppColors.textHint))
                else if (availabilityAsync.isLoading || bookedAsync?.isLoading == true)
                  const Center(child: CircularProgressIndicator(color: AppColors.primary))
                else if (slots.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(l.reqSessionTeacherUnavailable,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: AppColors.textHint)),
                  )
                else
                  Wrap(
                    spacing: 10, runSpacing: 10,
                    children: slots.map((slot) {
                      final h = slot['h'] as int;
                      final m = slot['m'] as int;
                      final booked = slot['booked'] as bool;
                      final sel = _selectedHour == h && _selectedMinute == m;
                      return GestureDetector(
                        onTap: booked ? null : () => setState(() {
                          _selectedHour   = h;
                          _selectedMinute = m;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                          decoration: BoxDecoration(
                            color: booked
                                ? AppColors.surfaceAlt
                                : sel ? AppColors.primary : AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: booked
                                  ? AppColors.border
                                  : sel ? AppColors.primary : AppColors.border),
                          ),
                          child: Text(slot['label'] as String,
                            style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700,
                              color: booked
                                  ? AppColors.textHint
                                  : sel ? Colors.white : AppColors.textPrimary,
                              decoration: booked ? TextDecoration.lineThrough : null,
                            )),
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
                  label: l.rescheduleSubmitBtn,
                  isLoading: _loading,
                  onTap: _submit,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
