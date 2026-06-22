import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;
import '../models/session.dart';
import '../constants/session_states.dart';
import 'supabase_service.dart';

class SessionService {
  static final _db = SupabaseService.client;

  // ── Student: request new session ─────────────────────────────────────────────
  // Trigger doesn't fire on INSERT, so we log the REQUESTED event manually.
  static Future<String> requestSession({
    required String teacherId,
    required DateTime scheduledAt,
    required int durationMinutes,
    required double amount,
    required String subject,
    String? studentLevel,
    String? note,
  }) async {
    final response = await _db.from('sessions').insert({
      'student_id':       SupabaseService.userId,
      'teacher_id':       teacherId,
      'scheduled_at':     scheduledAt.toIso8601String(),
      'duration_minutes': durationMinutes,
      'amount':           amount,
      'subject':          subject,
      'student_level':    studentLevel,
      'student_note':     note,
      'state':            SessionState.requested.englishKey,
    }).select().single();

    await _db.from('session_events').insert({
      'session_id': response['id'],
      'event_type': 'REQUESTED',
      'actor':      'student',
    });

    return response['id'] as String;
  }

  // ── Student: cancel session ───────────────────────────────────────────────────
  // DB trigger (BEFORE UPDATE) auto-logs the CANCELLED event.
  static Future<void> cancelSession(String sessionId) async {
    final session = await getSession(sessionId);
    if (!session.state.canStudentCancel) {
      throw Exception('لا يمكن إلغاء الجلسة في هذه المرحلة');
    }
    await _db.from('sessions').update({
      'state':      SessionState.cancelled.englishKey,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', sessionId);
    // Trigger logs CANCELLED (system)
  }

  // ── Teacher: approve REQUESTED → TEACHER_APPROVED ─────────────────────────────
  // DB trigger auto-advances TEACHER_APPROVED → AWAITING_PAYMENT and sets
  // payment_deadline from system_settings. The Flutter-set deadline below is a
  // safety fallback in case system_settings isn't populated; the trigger overrides it.
  static Future<void> approveSession(String sessionId) async {
    final deadline = DateTime.now().add(const Duration(hours: 1));
    final updated = await _db.from('sessions').update({
      'state':            SessionState.teacherApproved.englishKey,
      'payment_deadline': deadline.toIso8601String(), // fallback; trigger overrides
      'updated_at':       DateTime.now().toIso8601String(),
    }).eq('id', sessionId)
      .eq('state', SessionState.requested.englishKey) // guard: only from REQUESTED
      .select('id');

    if ((updated as List).isEmpty) {
      throw Exception('لا يمكن الموافقة على هذا الطلب في حالته الحالية');
    }
    // Trigger logs TEACHER_APPROVED event — no duplicate insert here
  }

  // ── Teacher: reject REQUESTED ─────────────────────────────────────────────────
  // DB trigger logs TEACHER_REJECTED and notifies the student.
  static Future<void> rejectSession(String sessionId, {String? reason}) async {
    final updated = await _db.from('sessions').update({
      'state':            SessionState.teacherRejected.englishKey,
      if (reason != null && reason.isNotEmpty) 'rejection_reason': reason,
      'updated_at':       DateTime.now().toIso8601String(),
    }).eq('id', sessionId)
      .eq('state', SessionState.requested.englishKey) // guard: only from REQUESTED
      .select('id');

    if ((updated as List).isEmpty) {
      throw Exception('لا يمكن رفض هذا الطلب في حالته الحالية');
    }
    // Trigger logs TEACHER_REJECTED event + notifies student
  }

  // ── Teacher: cancel or open dispute ──────────────────────────────────────────
  // • Before PAYMENT_CONFIRMED → cancel (safe, money not confirmed)
  // • At/After PAYMENT_CONFIRMED → cannot cancel → open DISPUTE for admin
  // Returns true if cancelled, false if dispute was opened.
  // DB trigger logs the resulting state change event.
  static Future<bool> teacherCancelOrDispute(String sessionId, {String? reason}) async {
    final session = await getSession(sessionId);

    final blockedStates = {
      SessionState.paymentConfirmed,
      SessionState.confirmedBooking,
      SessionState.activeSession,
    };

    if (blockedStates.contains(session.state)) {
      await _db.from('sessions').update({
        'state':      SessionState.dispute.englishKey,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', sessionId);

      await _db.from('disputes').insert({
        'session_id': sessionId,
        'reason':     reason ?? 'طلب إلغاء من الأستاذ بعد تأكيد الدفع',
      });
      // Trigger logs DISPUTE event + notifies admin
      return false;
    }

    await _db.from('sessions').update({
      'state':      SessionState.cancelled.englishKey,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', sessionId);
    // Trigger logs CANCELLED event
    return true;
  }

  // ── Student: submit payment proof ─────────────────────────────────────────────
  // DB trigger logs PAYMENT_SUBMITTED and notifies admin.
  static Future<void> submitPaymentProof({
    required String sessionId,
    required String method,
    required String proofImageUrl,
  }) async {
    // Prevent duplicate submission
    final existing = await _db
        .from('payments')
        .select('id, status')
        .eq('session_id', sessionId)
        .eq('status', 'submitted')
        .maybeSingle();
    if (existing != null) {
      throw Exception('إثبات الدفع أُرسل مسبقاً وهو قيد المراجعة');
    }

    final reference = 'PAY-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final session = await getSession(sessionId);

    await _db.from('payments').insert({
      'session_id':      sessionId,
      'student_id':      SupabaseService.userId,
      'amount':          session.amount,
      'method':          method,
      'proof_image_url': proofImageUrl,
      'reference':       reference,
      'status':          'submitted',
    });

    await _db.from('sessions').update({
      'state':      SessionState.paymentSubmitted.englishKey,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', sessionId);
    // Trigger logs PAYMENT_SUBMITTED event + notifies admin
  }

  // ── Teacher: start session ────────────────────────────────────────────────────
  // Guard: only allowed from CONFIRMED_BOOKING to prevent duplicate starts.
  static Future<String> startSession(String sessionId) async {
    final roomName = 'HajezUstad${sessionId.replaceAll('-', '').substring(0, 12)}';
    final roomUrl  = 'https://meet.jit.si/$roomName'
        '#config.disableDeepLinking=true'
        '&config.prejoinPageEnabled=false'
        '&config.startWithAudioMuted=false'
        '&config.startWithVideoMuted=false'
        '&userInfo.displayName=Ustaz';

    final updated = await _db.from('sessions').update({
      'state':      SessionState.activeSession.englishKey,
      'room_url':   roomUrl,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', sessionId)
      .eq('state', SessionState.confirmedBooking.englishKey) // guard: only from CONFIRMED_BOOKING
      .select('id');

    if ((updated as List).isEmpty) {
      throw Exception('لا يمكن بدء الجلسة في حالتها الحالية');
    }
    // Trigger sets started_at + logs ACTIVE_SESSION + notifies student
    return roomUrl;
  }

  // ── Student: record join timestamp ───────────────────────────────────────────
  // Called when the student's WebView finishes loading the Jitsi room.
  // Sets sessions.student_joined_at → prevents the cron job from firing
  // STUDENT_NO_SHOW for this session.
  static Future<void> markStudentJoined(String sessionId) async {
    await _db.from('sessions').update({
      'student_joined_at': DateTime.now().toIso8601String(),
    }).eq('id', sessionId)
      .eq('student_id', SupabaseService.userId!)
      .eq('state', SessionState.activeSession.englishKey); // no-op if already not active
  }

  // ── Teacher: end session ──────────────────────────────────────────────────────
  // Guard: only allowed from ACTIVE_SESSION.
  static Future<void> endSession(String sessionId) async {
    final updated = await _db.from('sessions').update({
      'state':      SessionState.completed.englishKey,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', sessionId)
      .eq('state', SessionState.activeSession.englishKey) // guard: only from ACTIVE_SESSION
      .select('id');

    if ((updated as List).isEmpty) {
      throw Exception('الجلسة ليست نشطة أو انتهت بالفعل');
    }
    // Trigger sets ended_at + logs COMPLETED
  }

  // ── Student: report teacher no-show ──────────────────────────────────────────
  static Future<void> reportTeacherNoShow(String sessionId) async {
    final updated = await _db.from('sessions').update({
      'state':      SessionState.teacherNoShow.englishKey,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', sessionId)
      .eq('state', SessionState.confirmedBooking.englishKey) // guard: only from CONFIRMED_BOOKING
      .select();
    if ((updated as List).isEmpty) {
      throw Exception('لا يمكن الإبلاغ عن غياب إلا في جلسة مؤكّدة');
    }
    // Trigger logs TEACHER_NO_SHOW + notifies student (re-scheduling message)
  }

  // ── Teacher: report student no-show ──────────────────────────────────────────
  static Future<void> reportStudentNoShow(String sessionId) async {
    await _db.from('sessions').update({
      'state':      SessionState.studentNoShow.englishKey,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', sessionId)
      .eq('state', SessionState.confirmedBooking.englishKey); // guard: only from CONFIRMED_BOOKING
    // Trigger logs STUDENT_NO_SHOW
  }

  // ── Student: reschedule after no-show ────────────────────────────────────────
  // • After TEACHER_NO_SHOW: payment already confirmed → start at CONFIRMED_BOOKING
  // • Otherwise (voluntary): start fresh from REQUESTED
  // Trigger doesn't fire on INSERT, so we log REQUESTED/CONFIRMED_BOOKING manually.
  static Future<String> rescheduleSession({
    required String parentSessionId,
    required DateTime newScheduledAt,
    required int durationMinutes,
  }) async {
    final original = await getSession(parentSessionId);

    final isAfterTeacherNoShow = original.state == SessionState.teacherNoShow;
    final newState = isAfterTeacherNoShow
        ? SessionState.confirmedBooking.englishKey
        : SessionState.requested.englishKey;

    final response = await _db.from('sessions').insert({
      'student_id':        SupabaseService.userId,
      'teacher_id':        original.teacherId,
      'scheduled_at':      newScheduledAt.toIso8601String(),
      'duration_minutes':  durationMinutes,
      'amount':            original.amount,
      'subject':           original.subject,
      'state':             newState,
      'parent_session_id': parentSessionId,
    }).select().single();

    final newSessionId = response['id'] as String;

    // Log RESCHEDULED on the parent session (trigger doesn't cover this)
    await _db.from('session_events').insert({
      'session_id': parentSessionId,
      'event_type': 'RESCHEDULED',
      'actor':      'student',
      'note':       'أُعيدت الجدولة — جلسة جديدة: $newSessionId',
    });

    // Log the initial event for the new session (trigger doesn't fire on INSERT)
    await _db.from('session_events').insert({
      'session_id': newSessionId,
      'event_type': isAfterTeacherNoShow ? 'CONFIRMED_BOOKING' : 'REQUESTED',
      'actor':      'student',
    });

    return newSessionId;
  }

  // ── Fetch single session ─────────────────────────────────────────────────────
  static Future<Session> getSession(String sessionId) async {
    final data = await _db.from('sessions')
        .select('*, teacher:teacher_id(profiles(full_name)), student:student_id(full_name), payments(*), session_events(*)')
        .eq('id', sessionId)
        .single();
    final raw = Map<String, dynamic>.from(data as Map);
    final teacherOuter = raw['teacher'] as Map? ?? {};
    final profileInner = teacherOuter['profiles'] as Map? ?? {};
    raw['teacher']      = {'full_name': profileInner['full_name'] ?? ''};
    raw['student_name'] = (raw['student'] as Map?)?['full_name'] ?? '';
    return _parseSession(raw);
  }

  // ── Fetch all sessions for student ──────────────────────────────────────────
  static Future<List<Session>> getStudentSessions() async {
    final uid = SupabaseService.userId;
    if (uid == null) return [];

    final data = await _db.from('sessions')
        .select('*, teacher:teacher_id(profiles(full_name)), student:student_id(full_name), payments(*), session_events(*)')
        .eq('student_id', uid)
        .order('created_at', ascending: false);

    return (data as List).map((s) {
      final raw = Map<String, dynamic>.from(s as Map);
      final teacherOuter = raw['teacher'] as Map? ?? {};
      final profileInner = teacherOuter['profiles'] as Map? ?? {};
      raw['teacher']      = {'full_name': profileInner['full_name'] ?? ''};
      raw['student_name'] = (raw['student'] as Map?)?['full_name'] ?? '';
      return _parseSession(raw);
    }).toList();
  }

  // ── Parse raw DB map into Session model ──────────────────────────────────────
  static Session _parseSession(Map<String, dynamic> raw) {
    final map        = Map<String, dynamic>.from(raw);
    final teacherMap = map['teacher'] as Map<String, dynamic>? ?? {};
    map['teacher_name'] = teacherMap['full_name'] ?? '';

    final paymentsList = (map['payments'] as List?)
        ?.cast<Map<String, dynamic>>() ?? [];

    // Priority: confirmed (most relevant) → submitted → rejected → pending
    Map<String, dynamic>? bestPayment;
    if (paymentsList.isNotEmpty) {
      const priority = {'confirmed': 0, 'submitted': 1, 'rejected': 2, 'pending': 3};
      paymentsList.sort((a, b) {
        final pa = priority[a['status']] ?? 99;
        final pb = priority[b['status']] ?? 99;
        return pa.compareTo(pb);
      });
      bestPayment = paymentsList.first;
    }
    map['payment'] = bestPayment;
    map['events']  = (map['session_events'] as List?) ?? [];
    return Session.fromJson(map);
  }

  // ── Upload proof image then submit ──────────────────────────────────────────
  static Future<void> uploadAndSubmitPayment({
    required String sessionId,
    required String method,
    required Uint8List imageBytes,
    required String imageExt,
  }) async {
    final uid         = SupabaseService.userId!;
    final ext         = imageExt.toLowerCase();
    final contentType = ext == 'png' ? 'image/png' : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
    final fileName    = '$uid/${sessionId}_${DateTime.now().millisecondsSinceEpoch}.$ext';

    await SupabaseService.client.storage
        .from('payment-proofs')
        .uploadBinary(fileName, imageBytes, fileOptions: FileOptions(contentType: contentType));

    final publicUrl = SupabaseService.client.storage
        .from('payment-proofs')
        .getPublicUrl(fileName);

    await submitPaymentProof(
      sessionId:     sessionId,
      method:        method,
      proofImageUrl: publicUrl,
    );
  }

  // ── Submit review after completed session ────────────────────────────────────
  static Future<void> submitReview({
    required String sessionId,
    required String teacherId,
    required int    rating,
    String?         comment,
  }) async {
    await _db.from('reviews').insert({
      'session_id': sessionId,
      'student_id': SupabaseService.userId,
      'teacher_id': teacherId,
      'rating':     rating,
      'comment':    comment,
    });
  }

  // ── Realtime subscription for a single session ───────────────────────────────
  static RealtimeChannel subscribeToSession(
    String sessionId,
    void Function(Session) onUpdate,
  ) {
    return _db
        .channel('session-$sessionId')
        .onPostgresChanges(
          event:  PostgresChangeEvent.update,
          schema: 'public',
          table:  'sessions',
          filter: PostgresChangeFilter(
            type:   PostgresChangeFilterType.eq,
            column: 'id',
            value:  sessionId,
          ),
          callback: (payload) async {
            final session = await getSession(sessionId);
            onUpdate(session);
          },
        )
        .subscribe();
  }

  // ── Teacher booked times (for double-booking prevention) ─────────────────────
  // Excludes TEACHER_REJECTED, CANCELLED, TEACHER_NO_SHOW, STUDENT_NO_SHOW
  // since those slots are effectively free.
  static Future<List<DateTime>> getTeacherBookedTimes(
    String teacherId,
    DateTime date,
  ) async {
    final dayStart = DateTime(date.year, date.month, date.day).toIso8601String();
    final dayEnd   = DateTime(date.year, date.month, date.day + 1).toIso8601String();

    final data = await _db
        .from('sessions')
        .select('scheduled_at')
        .eq('teacher_id', teacherId)
        .gte('scheduled_at', dayStart)
        .lt('scheduled_at', dayEnd)
        .not('state', 'in', '(${[
          SessionState.teacherRejected.englishKey,
          SessionState.cancelled.englishKey,
          SessionState.teacherNoShow.englishKey,
          SessionState.studentNoShow.englishKey,
        ].join(',')})');

    return (data as List)
        .map((s) => DateTime.parse(s['scheduled_at'] as String).toLocal())
        .toList();
  }
}
