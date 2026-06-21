import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/session_states.dart';
import '../models/session.dart';
import '../services/session_service.dart';
import '../services/supabase_service.dart';
import 'auth_provider.dart';

// ── Teacher dashboard stats ──────────────────────────────────
class TeacherDashboardStats {
  final String teacherName;
  final String teacherInitial;
  final bool isAvailable;
  final int pendingCount;
  final int todayCount;
  final double attendanceRate;
  final double weekEarnings;
  final int completedSessions;
  final List<Map<String, dynamic>> pendingRequests;
  final List<Map<String, dynamic>> upcomingSessions;

  const TeacherDashboardStats({
    required this.teacherName,
    required this.teacherInitial,
    required this.isAvailable,
    required this.pendingCount,
    required this.todayCount,
    required this.attendanceRate,
    required this.weekEarnings,
    required this.completedSessions,
    required this.pendingRequests,
    required this.upcomingSessions,
  });
}

// ── Student sessions list ───────────────────────────────────
final studentSessionsProvider = FutureProvider.autoDispose<List<Session>>((ref) async {
  final session = ref.watch(currentSessionProvider);
  if (session == null) return [];
  return SessionService.getStudentSessions();
});

// ── Teacher sessions list ───────────────────────────────────
final teacherSessionsProvider = FutureProvider.autoDispose<List<Session>>((ref) async {
  final session = ref.watch(currentSessionProvider);
  if (session == null) return [];
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
    raw['teacher_name'] = '';
    raw['student_name'] = studentMap['full_name'] ?? '';
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
  final session = ref.watch(currentSessionProvider);
  if (session == null) return 0;
  final uid = SupabaseService.userId;
  if (uid == null) return 0;
  final data = await SupabaseService.client
      .from('sessions')
      .select('id')
      .eq('teacher_id', uid)
      .eq('state', SessionState.requested.englishKey);
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

// ── Teacher profile ─────────────────────────────────────────
final teacherProfileProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final session = ref.watch(currentSessionProvider);
  if (session == null) return null;
  final uid = SupabaseService.userId;
  if (uid == null) return null;
  final data = await SupabaseService.client
      .from('teacher_profiles')
      .select('*, profile:profiles(full_name, is_active)')
      .eq('id', uid)
      .maybeSingle();
  return data != null ? Map<String, dynamic>.from(data as Map) : null;
});

// ── Teacher dashboard aggregated stats ────────────────────────
final teacherDashboardProvider = FutureProvider.autoDispose<TeacherDashboardStats>((ref) async {
  final session = ref.watch(currentSessionProvider);
  if (session == null) {
    return const TeacherDashboardStats(
      teacherName: '', teacherInitial: '؟', isAvailable: false,
      pendingCount: 0, todayCount: 0, attendanceRate: 0,
      weekEarnings: 0, completedSessions: 0,
      pendingRequests: [], upcomingSessions: [],
    );
  }
  final uid = SupabaseService.userId;
  if (uid == null) {
    return const TeacherDashboardStats(
      teacherName: '', teacherInitial: '؟', isAvailable: false,
      pendingCount: 0, todayCount: 0, attendanceRate: 0,
      weekEarnings: 0, completedSessions: 0,
      pendingRequests: [], upcomingSessions: [],
    );
  }

  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
  final todayEnd = DateTime(now.year, now.month, now.day + 1).toIso8601String();
  final weekStart = DateTime(now.year, now.month, now.day - now.weekday).toIso8601String();

  final results = await Future.wait([
    SupabaseService.client
        .from('teacher_profiles')
        .select('attendance_rate, profile:profiles(full_name, is_active)')
        .eq('id', uid)
        .maybeSingle(),
    SupabaseService.client
        .from('sessions')
        .select('id, state, scheduled_at, duration_minutes, subject, student:student_id(full_name), student_note')
        .eq('teacher_id', uid)
        .eq('state', SessionState.requested.englishKey)
        .order('scheduled_at'),
    SupabaseService.client
        .from('sessions')
        .select('id, scheduled_at, duration_minutes, subject, state, student:student_id(full_name)')
        .eq('teacher_id', uid)
        .eq('state', SessionState.confirmedBooking.englishKey)
        .gte('scheduled_at', now.toIso8601String())
        .order('scheduled_at')
        .limit(5),
    SupabaseService.client
        .from('sessions')
        .select('id')
        .eq('teacher_id', uid)
        .inFilter('state', [SessionState.confirmedBooking.englishKey, SessionState.activeSession.englishKey])
        .gte('scheduled_at', todayStart)
        .lt('scheduled_at', todayEnd),
    SupabaseService.client
        .from('ledger_entries')
        .select('net_amount')
        .eq('teacher_id', uid)
        .gte('created_at', weekStart),
    SupabaseService.client
        .from('sessions')
        .select('id')
        .eq('teacher_id', uid)
        .eq('state', 'COMPLETED'),
  ]);

  final profileRaw = results[0] as Map?;
  final profileMap = profileRaw != null ? Map<String, dynamic>.from(profileRaw) : <String, dynamic>{};
  final profileInner = profileMap['profile'] as Map? ?? {};
  final fullName = (profileInner['full_name'] as String?) ?? '';
  final isAvailable = (profileInner['is_active'] as bool?) ?? false;
  final attendanceRate = (profileMap['attendance_rate'] as num?)?.toDouble() ?? 100.0;

  final pendingList = (results[1] as List).cast<Map<String, dynamic>>();
  final upcomingList = (results[2] as List).cast<Map<String, dynamic>>();
  final todayList = (results[3] as List);
  final weekLedger = (results[4] as List);
  final completedList = (results[5] as List);

  final weekEarnings = weekLedger.fold<double>(
    0, (sum, e) => sum + ((e as Map)['net_amount'] as num? ?? 0).toDouble());

  return TeacherDashboardStats(
    teacherName: fullName,
    teacherInitial: fullName.isNotEmpty ? fullName[0] : '؟',
    isAvailable: isAvailable,
    pendingCount: pendingList.length,
    todayCount: todayList.length,
    attendanceRate: attendanceRate,
    weekEarnings: weekEarnings,
    completedSessions: completedList.length,
    pendingRequests: pendingList,
    upcomingSessions: upcomingList,
  );
});

// ── Teacher sessions by state ────────────────────────────────
final teacherPendingRequestsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final session = ref.watch(currentSessionProvider);
  if (session == null) return [];
  final uid = SupabaseService.userId;
  if (uid == null) return [];
  final data = await SupabaseService.client
      .from('sessions')
      .select('id, scheduled_at, duration_minutes, subject, student_note, student:student_id(full_name)')
      .eq('teacher_id', uid)
      .eq('state', SessionState.requested.englishKey)
      .order('scheduled_at');
  return List<Map<String, dynamic>>.from(data as List);
});

final teacherInProgressSessionsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final session = ref.watch(currentSessionProvider);
  if (session == null) return [];
  final uid = SupabaseService.userId;
  if (uid == null) return [];
  final data = await SupabaseService.client
      .from('sessions')
      .select('id, scheduled_at, duration_minutes, subject, state, student:student_id(full_name)')
      .eq('teacher_id', uid)
      .inFilter('state', [
        SessionState.teacherApproved.englishKey,
        SessionState.awaitingPayment.englishKey,
        SessionState.paymentSubmitted.englishKey,
        SessionState.paymentRejected.englishKey,
        SessionState.paymentConfirmed.englishKey,
        SessionState.confirmedBooking.englishKey,
        SessionState.activeSession.englishKey,
      ])
      .order('scheduled_at');
  return List<Map<String, dynamic>>.from(data as List);
});

final teacherRejectedSessionsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final session = ref.watch(currentSessionProvider);
  if (session == null) return [];
  final uid = SupabaseService.userId;
  if (uid == null) return [];
  final data = await SupabaseService.client
      .from('sessions')
      .select('id, scheduled_at, duration_minutes, subject, rejection_reason, student:student_id(full_name)')
      .eq('teacher_id', uid)
      .eq('state', SessionState.teacherRejected.englishKey)
      .order('created_at', ascending: false);
  return List<Map<String, dynamic>>.from(data as List);
});

// ── Teacher sessions split by time bucket ────────────────────
final teacherTodaySessionsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(currentSessionProvider);
  final uid = SupabaseService.userId;
  if (uid == null) return [];
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day).toIso8601String();
  final todayEnd   = DateTime(now.year, now.month, now.day + 1).toIso8601String();
  final data = await SupabaseService.client
      .from('sessions')
      .select('id, scheduled_at, duration_minutes, subject, state, amount, student:student_id(full_name)')
      .eq('teacher_id', uid)
      .inFilter('state', [
        SessionState.teacherApproved.englishKey,
        SessionState.awaitingPayment.englishKey,
        SessionState.paymentSubmitted.englishKey,
        SessionState.paymentRejected.englishKey,
        SessionState.paymentConfirmed.englishKey,
        SessionState.confirmedBooking.englishKey,
        SessionState.activeSession.englishKey,
        SessionState.teacherNoShow.englishKey,
        SessionState.studentNoShow.englishKey,
      ])
      .gte('scheduled_at', todayStart)
      .lt('scheduled_at', todayEnd)
      .order('scheduled_at');
  return List<Map<String, dynamic>>.from(data as List);
});

final teacherUpcomingSessionsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(currentSessionProvider);
  final uid = SupabaseService.userId;
  if (uid == null) return [];
  final now = DateTime.now();
  final tomorrowStart = DateTime(now.year, now.month, now.day + 1).toIso8601String();
  final data = await SupabaseService.client
      .from('sessions')
      .select('id, scheduled_at, duration_minutes, subject, state, amount, student:student_id(full_name)')
      .eq('teacher_id', uid)
      .inFilter('state', [
        SessionState.teacherApproved.englishKey,
        SessionState.awaitingPayment.englishKey,
        SessionState.paymentSubmitted.englishKey,
        SessionState.paymentRejected.englishKey,
        SessionState.paymentConfirmed.englishKey,
        SessionState.confirmedBooking.englishKey,
      ])
      .gte('scheduled_at', tomorrowStart)
      .order('scheduled_at')
      .limit(30);
  return List<Map<String, dynamic>>.from(data as List);
});

final teacherCompletedSessionsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  ref.watch(currentSessionProvider);
  final uid = SupabaseService.userId;
  if (uid == null) return [];
  final data = await SupabaseService.client
      .from('sessions')
      .select('id, scheduled_at, duration_minutes, subject, state, amount, student:student_id(full_name)')
      .eq('teacher_id', uid)
      .inFilter('state', [
        SessionState.completed.englishKey,
        SessionState.teacherRejected.englishKey,
        SessionState.cancelled.englishKey,
        SessionState.studentNoShow.englishKey,
        SessionState.teacherNoShow.englishKey,
        SessionState.dispute.englishKey,
      ])
      .order('scheduled_at', ascending: false)
      .limit(50);
  return List<Map<String, dynamic>>.from(data as List);
});

// ── Teacher booked times (for double-booking prevention) ─────
// Key: (teacherId, date truncated to midnight)
final teacherBookedTimesProvider = FutureProvider.autoDispose
    .family<List<DateTime>, ({String teacherId, DateTime date})>((ref, args) async {
  return SessionService.getTeacherBookedTimes(args.teacherId, args.date);
});

// ── Teacher earnings / ledger ────────────────────────────────
class TeacherEarningsData {
  final double totalBalance;
  final double weekEarnings;
  final double monthEarnings;
  final double courseEarnings;    // total from course subscriptions
  final double sessionEarnings;   // total from sessions
  final List<Map<String, dynamic>> entries;

  const TeacherEarningsData({
    required this.totalBalance,
    required this.weekEarnings,
    required this.monthEarnings,
    this.courseEarnings = 0,
    this.sessionEarnings = 0,
    required this.entries,
  });
}

final teacherEarningsProvider = FutureProvider.autoDispose<TeacherEarningsData>((ref) async {
  ref.watch(currentSessionProvider);
  final uid = SupabaseService.userId;
  if (uid == null) return const TeacherEarningsData(totalBalance: 0, weekEarnings: 0, monthEarnings: 0, entries: []);

  final now = DateTime.now();
  final weekStart  = DateTime(now.year, now.month, now.day - now.weekday);
  final monthStart = DateTime(now.year, now.month, 1);

  final data = await SupabaseService.client
      .from('ledger_entries')
      .select('id, net_amount, description, created_at, type, session:session_id(subject, student:student_id(full_name))')
      .eq('teacher_id', uid)
      .order('created_at', ascending: false)
      .limit(100);

  final entries = List<Map<String, dynamic>>.from(data as List);

  double total = 0, week = 0, month = 0, courseTot = 0, sessionTot = 0;
  for (final e in entries) {
    final amt      = (e['net_amount'] as num?)?.toDouble() ?? 0;
    final type     = e['type'] as String? ?? '';
    final created  = DateTime.tryParse(e['created_at'] as String? ?? '') ?? DateTime(2000);
    total += amt;
    if (created.isAfter(weekStart))  { week  += amt; }
    if (created.isAfter(monthStart)) { month += amt; }
    if (type == 'course_subscription')      { courseTot  += amt; }
    else if (type == 'session_payment')     { sessionTot += amt; }
  }

  return TeacherEarningsData(
    totalBalance:    total,
    weekEarnings:    week,
    monthEarnings:   month,
    courseEarnings:  courseTot,
    sessionEarnings: sessionTot,
    entries:         entries,
  );
});
