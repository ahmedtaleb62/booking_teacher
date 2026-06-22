import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/l10n_extension.dart';
import '../../../core/services/supabase_service.dart';

// ── Provider ─────────────────────────────────────────────────
final _teacherAvailProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final uid = SupabaseService.userId;
  if (uid == null) return [];
  final data = await SupabaseService.client
      .from('teacher_availability')
      .select()
      .eq('teacher_id', uid)
      .order('day_of_week')
      .order('start_time');
  return List<Map<String, dynamic>>.from(data as List);
});

// ── Screen ────────────────────────────────────────────────────
class TeacherAvailabilityScreen extends ConsumerStatefulWidget {
  const TeacherAvailabilityScreen({super.key});
  @override
  ConsumerState<TeacherAvailabilityScreen> createState() => _TeacherAvailabilityScreenState();
}

class _TeacherAvailabilityScreenState extends ConsumerState<TeacherAvailabilityScreen> {
  bool _saving = false;

  List<String> _weekdays(dynamic l) => [
    l.weekdaySun, l.weekdayMon, l.weekdayTue, l.weekdayWed,
    l.weekdayThu, l.weekdayFri, l.weekdaySat,
  ];

  Future<void> _addSlot(int dayOfWeek) async {
    final l = context.l10n;
    TimeOfDay? start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      helpText: l.availStartTime,
    );
    if (start == null || !mounted) return;

    TimeOfDay? end = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: start.hour + 1, minute: start.minute),
      helpText: l.availEndTime,
    );
    if (end == null || !mounted) return;

    if (_toMinutes(end) <= _toMinutes(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.availErrEndBeforeStart)),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final uid = SupabaseService.userId!;
      await SupabaseService.client.from('teacher_availability').insert({
        'teacher_id': uid,
        'day_of_week': dayOfWeek,
        'start_time': '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}:00',
        'end_time':   '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}:00',
        'is_active': true,
      });
      ref.invalidate(_teacherAvailProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.availErrGeneral(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteSlot(String slotId) async {
    final l = context.l10n;
    setState(() => _saving = true);
    try {
      await SupabaseService.client
          .from('teacher_availability')
          .delete()
          .eq('id', slotId);
      ref.invalidate(_teacherAvailProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.availErrGeneral(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  String _formatTime(String t) {
    final l = context.l10n;
    final parts = t.split(':');
    final h = int.parse(parts[0]);
    final m = parts[1];
    final period = h >= 12 ? l.timePmAbbrev : l.timeAmAbbrev;
    final h12 = h > 12 ? h - 12 : (h == 0 ? 12 : h);
    return '$h12:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final availAsync = ref.watch(_teacherAvailProvider);
    final days = _weekdays(l);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(l.availTitle,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: availAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(child: Text(l.availErrGeneral(e.toString()),
            style: const TextStyle(color: AppColors.error))),
        data: (slots) {
          final Map<int, List<Map<String, dynamic>>> byDay = {};
          for (final s in slots) {
            final d = s['day_of_week'] as int;
            (byDay[d] ??= []).add(s);
          }
          return Stack(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppColors.accentLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            l.availInfoText,
                            style: const TextStyle(fontSize: 12, color: AppColors.primary, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...List.generate(7, (i) {
                    final daySlots = byDay[i] ?? [];
                    return _DayCard(
                      day: days[i],
                      slots: daySlots,
                      onAdd: _saving ? null : () => _addSlot(i),
                      onDelete: _saving ? null : (id) => _deleteSlot(id),
                      formatTime: _formatTime,
                      addSlotLabel: l.availAddSlotBtn,
                      noSlotsLabel: l.availNoSlots,
                    );
                  }),
                ],
              ),
              if (_saving)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x44000000),
                    child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final String day;
  final List<Map<String, dynamic>> slots;
  final VoidCallback? onAdd;
  final void Function(String id)? onDelete;
  final String Function(String) formatTime;
  final String addSlotLabel;
  final String noSlotsLabel;

  const _DayCard({
    required this.day,
    required this.slots,
    required this.onAdd,
    required this.onDelete,
    required this.formatTime,
    required this.addSlotLabel,
    required this.noSlotsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final hasSlots = slots.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: hasSlots ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: hasSlots ? AppColors.primary : AppColors.border,
                  ),
                ),
                const SizedBox(width: 8),
                Text(day,
                  style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: hasSlots ? AppColors.textPrimary : AppColors.textSecondary,
                  )),
                const Spacer(),
                TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: Text(addSlotLabel, style: const TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
          if (hasSlots) ...[
            const Divider(height: 1, color: AppColors.border),
            ...slots.map((s) => _SlotTile(
              start: formatTime(s['start_time'] as String),
              end:   formatTime(s['end_time']   as String),
              onDelete: onDelete == null ? null : () => onDelete!(s['id'] as String),
            )),
          ] else
            Padding(
              padding: const EdgeInsets.fromLTRB(30, 4, 14, 12),
              child: Text(noSlotsLabel,
                style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
            ),
        ],
      ),
    );
  }
}

class _SlotTile extends StatelessWidget {
  final String start;
  final String end;
  final VoidCallback? onDelete;

  const _SlotTile({required this.start, required this.end, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 6, 8, 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$start  ←  $end',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ),
          const Spacer(),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.textHint),
            style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          ),
        ],
      ),
    );
  }
}
