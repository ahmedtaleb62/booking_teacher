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

    SupabaseService.client.functions.invoke('notify-user', body: {
      'user_id': teacherId,
      'title':   'طلب جلسة جديد 📚',
      'body':    'لديك طلب جلسة جديد في مادة $subject',
      'data': {
        'type':       'SESSION_REQUESTED',
        'session_id': response['id'] as String,
        'role':       'teacher',
      },
    }).then((_) {}, onError: (_) {});

    return response['id'] as String;
  }

  // ── Student: cancel session ───────────────────────────────────────────────────
  // DB trigger (BEFORE UPDATE) auto-logs the CANCELLED event.
  static Future<void> cancelSession(String sessionId) async {
    final session = await getSession(sessionId);
    if (!session.state.canStudentCancel) {
      throw Exception('لا يمكن إلغاء الجلسة في هذه المرحلة');
    }
    // State guard in UPDATE prevents TOCTOU race where session transitions
    // to a non-cancellable state between the check above and the write below.
    final updated = await _db.from('sessions').update({
      'state':      SessionState.cancelled.englishKey,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', sessionId)
      .inFilter('state', [
        SessionState.requested.englishKey,
        SessionState.teacherApproved.englishKey,
        SessionState.awaitingPayment.englishKey,
        SessionState.paymentRejected.englishKey,
      ])
      .select('id');

    if ((updated as List).isEmpty) {
      throw Exception('لا يمكن إلغاء الجلسة — تغيرت حالتها');
    }
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

    // Guard: already in DISPUTE — don't insert a second disputes row
    if (session.state == SessionState.dispute) return false;

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

    // Validate that session is in a state that accepts payment proof
    if (session.state != SessionState.awaitingPayment &&
        session.state != SessionState.paymentRejected) {
      throw Exception('لا يمكن إرسال إثبات الدفع في هذه المرحلة');
    }

    // Validate payment deadline has not expired
    if (session.paymentDeadline != null &&
        DateTime.now().isAfter(session.paymentDeadline!)) {
      throw Exception('انتهت مهلة السداد — تواصل مع الأستاذ للحصول على موعد جديد');
    }

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
    }).eq('id', sessionId)
      .inFilter('state', [  // defense-in-depth: DB-level state guard
        SessionState.awaitingPayment.englishKey,
        SessionState.paymentRejected.englishKey,
      ]);
    // Trigger logs PAYMENT_SUBMITTED event + notifies admin
  }

  // ── Teacher: activate session ─────────────────────────────────────────────────
  // Called by SessionRoomScreen when scheduledAt is reached.
  static Future<void> activateSession(String sessionId) async {
    final now = DateTime.now().toIso8601String();
    final updated = await _db.from('sessions').update({
      'state':      SessionState.activeSession.englishKey,
      'started_at': now, // set client-side; DB trigger may override
      'updated_at': now,
    }).eq('id', sessionId)
      .eq('state', SessionState.confirmedBooking.englishKey)
      .select('id');

    if ((updated as List).isEmpty) {
      throw Exception('لا يمكن بدء الجلسة في حالتها الحالية');
    }
    // Trigger sets started_at + logs ACTIVE_SESSION + notifies student
  }

  // ── Either party: initiate a video call via Jitsi ─────────────────────────
  // Stores a unique room_url in sessions → triggers Realtime on other party's screen.
  // Returns the Jitsi URL that both parties should load.
  static Future<String> initiateVideoCall(String sessionId) async {
    final roomName = 'HajezUstad${sessionId.replaceAll('-', '').substring(0, 12)}';
    final ts       = DateTime.now().millisecondsSinceEpoch;
    final roomUrl  = 'https://meet.jit.si/$roomName'
        '#config.disableDeepLinking=true'
        '&config.prejoinPageEnabled=false'
        '&config.startWithAudioMuted=false'
        '&config.startWithVideoMuted=false'
        '&ts=$ts';

    final updated = await _db.from('sessions').update({
      'room_url':   roomUrl,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', sessionId)
      .eq('state', SessionState.activeSession.englishKey)
      .select('id');

    if ((updated as List).isEmpty) {
      throw Exception('لا يمكن بدء المكالمة — الجلسة ليست نشطة');
    }

    return roomUrl;
  }

  // ── Student: record join timestamp ───────────────────────────────────────────
  // Called when the student enters the session room (initState).
  // Sets sessions.student_joined_at → prevents the cron job from firing
  // STUDENT_NO_SHOW for this session. Allowed in both confirmedBooking (early
  // arrival) and activeSession states so early arrivals are not penalised.
  // Retries up to 3 times — a silent failure here means cron could flag absence.
  static Future<void> markStudentJoined(String sessionId) async {
    final uid = SupabaseService.userId;
    if (uid == null) return;
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        await _db.from('sessions').update({
          'student_joined_at': DateTime.now().toIso8601String(),
        }).eq('id', sessionId)
          .eq('student_id', uid)
          .inFilter('state', [
            SessionState.confirmedBooking.englishKey,
            SessionState.activeSession.englishKey,
          ]);
        return; // success
      } catch (_) {
        if (attempt < 2) {
          await Future.delayed(const Duration(seconds: 2));
        } else {
          rethrow; // propagate after final attempt so callers can decide
        }
      }
    }
  }

  // ── Teacher: end session ──────────────────────────────────────────────────────
  // Records teacher_left_at so admin can verify attendance duration.
  // Guard: only allowed from ACTIVE_SESSION.
  static Future<void> endSession(String sessionId) async {
    final updated = await _db.from('sessions').update({
      'state':           SessionState.completed.englishKey,
      'teacher_left_at': DateTime.now().toIso8601String(),
      'updated_at':      DateTime.now().toIso8601String(),
    }).eq('id', sessionId)
      .eq('state', SessionState.activeSession.englishKey)
      .select('id');

    if ((updated as List).isEmpty) {
      throw Exception('الجلسة ليست نشطة أو انتهت بالفعل');
    }
    // Trigger sets ended_at + logs COMPLETED
  }

  // ── Teacher: record departure without ending session ──────────────────────────
  // Session closes authoritatively via pg_cron when time is up.
  // Teacher can leave early — we only record the timestamp for admin audit.
  static Future<void> recordTeacherLeft(String sessionId) async {
    final uid = SupabaseService.userId;
    if (uid == null) return;
    await _db.from('sessions').update({
      'teacher_left_at': DateTime.now().toIso8601String(),
      'updated_at':      DateTime.now().toIso8601String(),
    }).eq('id', sessionId)
      .eq('teacher_id', uid);
  }

  // ── Student: request refund after teacher no-show ────────────────────────────
  // Sets refund_status = 'student_requested' so admin can process it.
  // Dispute is opened automatically by cron — student can only reschedule or refund.
  static Future<void> requestRefund(String sessionId) async {
    final updated = await _db.from('sessions').update({
      'refund_status': 'student_requested',
      'updated_at':    DateTime.now().toIso8601String(),
    }).eq('id', sessionId)
      .eq('state', SessionState.teacherNoShow.englishKey)
      .isFilter('refund_status', null)
      .select('id');

    if ((updated as List).isEmpty) {
      throw Exception('لا يمكن طلب الاسترداد في هذه الحالة');
    }

    await _db.from('session_events').insert({
      'session_id': sessionId,
      'event_type': 'REFUND_REQUESTED',
      'actor':      'student',
    });
  }

  // ── Teacher: report student no-show ──────────────────────────────────────────
  static Future<void> reportStudentNoShow(String sessionId) async {
    // Guard: student_joined_at must be null — cannot mark absent if student already joined
    final check = await _db
        .from('sessions')
        .select('student_joined_at')
        .eq('id', sessionId)
        .single();
    if (check['student_joined_at'] != null) {
      throw Exception('لا يمكن تسجيل الغياب — الطالب انضم بالفعل');
    }

    final updated = await _db.from('sessions').update({
      'state':      SessionState.studentNoShow.englishKey,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', sessionId)
      .inFilter('state', [  // allowed from CONFIRMED_BOOKING or ACTIVE_SESSION
        SessionState.confirmedBooking.englishKey,
        SessionState.activeSession.englishKey,
      ])
      .select('id');

    if ((updated as List).isEmpty) {
      throw Exception('لا يمكن تسجيل الغياب — تغيرت حالة الجلسة');
    }
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

    const allowedStates = {SessionState.teacherNoShow, SessionState.completed};
    if (!allowedStates.contains(original.state)) {
      throw Exception('لا يمكن إعادة الجدولة إلا بعد غياب الأستاذ أو اكتمال الجلسة');
    }

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
        .select('*, teacher:teacher_id(profiles(full_name, avatar_url)), student:student_id(full_name, avatar_url), payments(*), session_events(*)')
        .eq('id', sessionId)
        .single();
    final raw = Map<String, dynamic>.from(data as Map);
    final teacherOuter = raw['teacher'] as Map? ?? {};
    final profileInner = teacherOuter['profiles'] as Map? ?? {};
    raw['teacher']             = {'full_name': profileInner['full_name'] ?? ''};
    raw['student_name']        = (raw['student'] as Map?)?['full_name'] ?? '';
    raw['teacher_avatar_url']  = profileInner['avatar_url'] as String?;
    raw['student_avatar_url']  = (raw['student'] as Map?)?['avatar_url'] as String?;
    return _parseSession(raw);
  }

  // ── Fetch all sessions for student ──────────────────────────────────────────
  static Future<List<Session>> getStudentSessions() async {
    final uid = SupabaseService.userId;
    if (uid == null) return [];

    final data = await _db.from('sessions')
        .select('*, teacher:teacher_id(profiles(full_name, avatar_url)), student:student_id(full_name, avatar_url), payments(*), session_events(*)')
        .eq('student_id', uid)
        .order('created_at', ascending: false);

    return (data as List).map((s) {
      final raw = Map<String, dynamic>.from(s as Map);
      final teacherOuter = raw['teacher'] as Map? ?? {};
      final profileInner = teacherOuter['profiles'] as Map? ?? {};
      raw['teacher']            = {'full_name': profileInner['full_name'] ?? ''};
      raw['student_name']       = (raw['student'] as Map?)?['full_name'] ?? '';
      raw['teacher_avatar_url'] = profileInner['avatar_url'] as String?;
      raw['student_avatar_url'] = (raw['student'] as Map?)?['avatar_url'] as String?;
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
    await _db.from('reviews').upsert({
      'session_id': sessionId,
      'student_id': SupabaseService.userId,
      'teacher_id': teacherId,
      'rating':     rating,
      'comment':    comment,
    }, onConflict: 'session_id,student_id');
  }

  static Future<bool> hasReviewedSession(String sessionId) async {
    final uid = SupabaseService.userId;
    if (uid == null) return false;
    final data = await _db
        .from('reviews')
        .select('id')
        .eq('session_id', sessionId)
        .eq('student_id', uid)
        .maybeSingle();
    return data != null;
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
