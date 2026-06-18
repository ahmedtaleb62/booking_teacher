import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session.dart';
import '../services/session_service.dart';
import '../services/supabase_service.dart';
import 'auth_provider.dart';

// ── Student sessions list ───────────────────────────────────
final studentSessionsProvider = FutureProvider.autoDispose<List<Session>>((ref) async {
  ref.watch(currentSessionProvider); // invalidate on auth change
  return SessionService.getStudentSessions();
});

// ── Teacher sessions list ───────────────────────────────────
final teacherSessionsProvider = FutureProvider.autoDispose<List<Session>>((ref) async {
  ref.watch(currentSessionProvider);
  final uid = SupabaseService.userId;
  if (uid == null) return [];

  final data = await SupabaseService.client
      .from('sessions')
      .select('''
        *,
        student:student_id(full_name, avatar_url),
        events:session_events(*)
      ''')
      .eq('teacher_id', uid)
      .order('scheduled_at', ascending: false);

  return (data as List).map((s) {
    final raw = Map<String, dynamic>.from(s as Map);
    final studentMap = raw['student'] as Map<String, dynamic>? ?? {};
    raw['teacher_name'] = studentMap['full_name'] ?? '';
    raw['events'] = raw['events'] ?? [];
    return Session.fromJson(raw);
  }).toList();
});

// ── Single session (with realtime) ─────────────────────────
final sessionProvider = StreamProvider.autoDispose.family<Session?, String>((ref, sessionId) {
  final controller = StreamController<Session?>();

  SessionService.getSession(sessionId).then((s) {
    if (!controller.isClosed) controller.add(s);
  });

  final channel = SessionService.subscribeToSession(sessionId, (s) {
    if (!controller.isClosed) controller.add(s);
  });

  ref.onDispose(() {
    controller.close();
    SupabaseService.client.removeChannel(channel);
  });

  return controller.stream;
});

// ── Teacher pending requests count ─────────────────────────
final pendingRequestsCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final uid = SupabaseService.userId;
  if (uid == null) return 0;
  final data = await SupabaseService.client
      .from('sessions')
      .select('id')
      .eq('teacher_id', uid)
      .eq('state', 'REQUESTED');
  return (data as List).length;
});

// ── Notifications ───────────────────────────────────────────
final notificationsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final uid = SupabaseService.userId;
  if (uid == null) return [];
  final data = await SupabaseService.client
      .from('notifications')
      .select()
      .eq('user_id', uid)
      .order('created_at', ascending: false)
      .limit(50);
  return List<Map<String, dynamic>>.from(data as List);
});

final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final uid = SupabaseService.userId;
  if (uid == null) return 0;
  final data = await SupabaseService.client
      .from('notifications')
      .select('id')
      .eq('user_id', uid)
      .eq('is_read', false);
  return (data as List).length;
});
