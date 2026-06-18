import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/teacher.dart';
import '../services/supabase_service.dart';

// ── Filter state ────────────────────────────────────────────
final teacherSubjectFilterProvider = StateProvider<String?>((ref) => null);
final teacherSearchQueryProvider   = StateProvider<String>((ref) => '');

// ── Teachers list from Supabase ─────────────────────────────
final teachersProvider = FutureProvider.autoDispose<List<Teacher>>((ref) async {
  final subject = ref.watch(teacherSubjectFilterProvider);
  final query   = ref.watch(teacherSearchQueryProvider);

  var req = SupabaseService.client
      .from('teachers_view')
      .select()
      .eq('is_approved', true);

  if (subject != null && subject.isNotEmpty) {
    req = req.contains('subjects', [subject]);
  }

  final data = await req.order('rating', ascending: false);

  var teachers = (data as List).map((t) => Teacher.fromJson(t as Map<String, dynamic>)).toList();

  if (query.isNotEmpty) {
    teachers = teachers.where((t) =>
      t.name.contains(query) ||
      t.subjects.any((s) => s.contains(query))
    ).toList();
  }

  return teachers;
});

// ── Single teacher ──────────────────────────────────────────
final teacherProvider = FutureProvider.autoDispose.family<Teacher?, String>((ref, id) async {
  final data = await SupabaseService.client
      .from('teachers_view')
      .select()
      .eq('id', id)
      .maybeSingle();
  if (data == null) return null;
  return Teacher.fromJson(data);
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
