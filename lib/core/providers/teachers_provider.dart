import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/teacher.dart';
import '../services/supabase_service.dart';

// ── Filter state ────────────────────────────────────────────
final teacherSubjectFilterProvider = StateProvider<String?>((ref) => null);
final teacherLevelFilterProvider   = StateProvider<String?>((ref) => null);
final teacherSearchQueryProvider   = StateProvider<String>((ref) => '');
final teacherMinPriceProvider      = StateProvider<double>((ref) => 0);
final teacherMaxPriceProvider      = StateProvider<double>((ref) => 2000);
final teacherOnlineOnlyProvider    = StateProvider<bool>((ref) => false);

// ── Teachers list from Supabase ─────────────────────────────
final teachersProvider = FutureProvider.autoDispose<List<Teacher>>((ref) async {
  final subject    = ref.watch(teacherSubjectFilterProvider);
  final level      = ref.watch(teacherLevelFilterProvider);
  final query      = ref.watch(teacherSearchQueryProvider);
  final minPrice   = ref.watch(teacherMinPriceProvider);
  final maxPrice   = ref.watch(teacherMaxPriceProvider);
  final onlineOnly = ref.watch(teacherOnlineOnlyProvider);

  var req = SupabaseService.client
      .from('teachers_view')
      .select()
      .eq('is_approved', true);

  if (subject != null && subject.isNotEmpty) {
    req = req.contains('subjects', [subject]);
  }
  if (level != null && level.isNotEmpty) {
    req = req.contains('teaching_levels', [level]);
  }

  final data = await req.order('rating', ascending: false);

  var teachers = (data as List).map((t) => Teacher.fromJson(t as Map<String, dynamic>)).toList();

  // Client-side filters (price, search, online)
  if (query.isNotEmpty) {
    teachers = teachers.where((t) =>
      t.name.contains(query) ||
      t.subjects.any((s) => s.contains(query))
    ).toList();
  }
  if (minPrice > 0) {
    teachers = teachers.where((t) => t.pricePerHour >= minPrice).toList();
  }
  if (maxPrice < 2000) {
    teachers = teachers.where((t) => t.pricePerHour <= maxPrice).toList();
  }
  if (onlineOnly) {
    teachers = teachers.where((t) => t.isOnline).toList();
  }

  return teachers;
});

// ── Single teacher (with today's available slots) ────────────
final teacherProvider = FutureProvider.autoDispose.family<Teacher?, String>((ref, id) async {
  final now = DateTime.now();
  // Dart weekday: 1=Mon…7=Sun → convert to 0=Sun,1=Mon…6=Sat
  final dayOfWeek = now.weekday % 7;

  final results = await Future.wait([
    SupabaseService.client.from('teachers_view').select().eq('id', id).maybeSingle(),
    SupabaseService.client
        .from('teacher_availability')
        .select()
        .eq('teacher_id', id)
        .eq('day_of_week', dayOfWeek)
        .eq('is_active', true)
        .order('start_time'),
  ]);

  final data = results[0] as Map?;
  if (data == null) return null;

  final availRaw = results[1] as List;
  // Generate hourly TimeSlot entries from each availability range
  final slots = availRaw.expand<Map<String, dynamic>>((slot) {
    final start = (slot['start_time'] as String).split(':');
    final end   = (slot['end_time']   as String).split(':');
    final startH = int.parse(start[0]);
    final startM = int.parse(start[1]);
    final endH   = int.parse(end[0]);
    final endM   = int.parse(end[1]);
    final generated = <Map<String, dynamic>>[];
    var h = startH; var m = startM;
    while (h < endH || (h == endH && m < endM)) {
      generated.add({
        'date_time': DateTime(now.year, now.month, now.day, h, m).toIso8601String(),
        'is_booked': false,
        'duration_minutes': 60,
      });
      h += 1;
      if (h > endH || (h == endH && m >= endM)) break;
    }
    return generated;
  }).toList();

  final map = Map<String, dynamic>.from(data);
  map['available_slots'] = slots;
  return Teacher.fromJson(map);
});

// ── Teacher availability ────────────────────────────────────
final teacherAvailabilityProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, teacherId) async {
  final data = await SupabaseService.client
      .from('teacher_availability')
      .select()
      .eq('teacher_id', teacherId)
      .eq('is_active', true)
      .order('day_of_week');
  return List<Map<String, dynamic>>.from(data as List);
});
