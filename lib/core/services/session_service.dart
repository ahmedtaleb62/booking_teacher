import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;
import '../models/session.dart';
import '../constants/session_states.dart';
import 'supabase_service.dart';

class SessionService {
  static final _db = SupabaseService.client;

  static Future<String> requestSession({
    required String teacherId,
    required DateTime scheduledAt,
    required int durationMinutes,
    required double amount,
    required String subject,
    String? note,
  }) async {
    final response = await _db.from('sessions').insert({
      'student_id': SupabaseService.userId,
      'teacher_id': teacherId,
      'scheduled_at': scheduledAt.toIso8601String(),
      'duration_minutes': durationMinutes,
      'amount': amount,
      'subject': subject,
      'student_note': note,
      'state': SessionState.requested.englishKey,
    }).select().single();

    await _db.from('session_events').insert({
      'session_id': response['id'],
      'event_type': 'REQUESTED',
      'actor': 'student',
    });

    return response['id'] as String;
  }

  static Future<void> cancelSession(String sessionId) async {
    final session = await getSession(sessionId);
    if (!session.state.canStudentCancel) {
      throw Exception('لا يمكن إلغاء الجلسة في هذه المرحلة');
    }
    await _db.from('sessions').update({
      'state': SessionState.cancelled.englishKey,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', sessionId);

    await _db.from('session_events').insert({
      'session_id': sessionId,
      'event_type': 'CANCELLED',
      'actor': 'student',
    });
  }

  static Future<void> submitPaymentProof({
    required String sessionId,
    required String method,
    required String proofImageUrl,
  }) async {
    final reference = 'PAY-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    final session = await getSession(sessionId);
    await _db.from('payments').insert({
      'session_id': sessionId,
      'student_id': SupabaseService.userId,
      'amount': session.amount,
      'method': method,
      'proof_image_url': proofImageUrl,
      'reference': reference,
      'status': 'submitted',
    });

    await _db.from('sessions').update({
      'state': SessionState.paymentSubmitted.englishKey,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', sessionId);

    await _db.from('session_events').insert({
      'session_id': sessionId,
      'event_type': 'PAYMENT_SUBMITTED',
      'actor': 'student',
    });
  }

  static Future<Session> getSession(String sessionId) async {
    final data = await _db.from('sessions')
        .select('*, teacher:teacher_id(full_name), payments(*), session_events(*)')
        .eq('id', sessionId)
        .single();
    return _parseSession(Map<String, dynamic>.from(data as Map));
  }

  static Future<List<Session>> getStudentSessions() async {
    final data = await _db.from('sessions')
        .select('*, teacher:teacher_id(full_name), payments(*), session_events(*)')
        .eq('student_id', SupabaseService.userId ?? '')
        .order('created_at', ascending: false);

    return (data as List).map((s) => _parseSession(Map<String, dynamic>.from(s as Map))).toList();
  }

  static Session _parseSession(Map<String, dynamic> raw) {
    final map = Map<String, dynamic>.from(raw);
    final teacherMap = map['teacher'] as Map<String, dynamic>? ?? {};
    map['teacher_name'] = teacherMap['full_name'] ?? '';
    final paymentsList = map['payments'] as List?;
    map['payment'] = (paymentsList != null && paymentsList.isNotEmpty)
        ? paymentsList.first as Map<String, dynamic>
        : null;
    map['events'] = (map['session_events'] as List?) ?? [];
    return Session.fromJson(map);
  }

  static Future<void> uploadAndSubmitPayment({
    required String sessionId,
    required String method,
    required String localFilePath,
  }) async {
    final uid = SupabaseService.userId!;
    final ext = localFilePath.contains('.') ? localFilePath.split('.').last.toLowerCase() : 'jpg';
    final contentType = ext == 'png' ? 'image/png' : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
    final fileName = '$uid/${sessionId}_${DateTime.now().millisecondsSinceEpoch}.$ext';

    final bytes = await File(localFilePath).readAsBytes();
    await SupabaseService.client.storage
        .from('payment-proofs')
        .uploadBinary(
          fileName,
          bytes,
          fileOptions: FileOptions(contentType: contentType),
        );

    await submitPaymentProof(
      sessionId: sessionId,
      method: method,
      proofImageUrl: fileName,
    );
  }

  static Future<String> startSession(String sessionId) async {
    final roomName = 'HajezUstad${sessionId.replaceAll('-', '').substring(0, 12)}';
    final roomUrl = 'https://meet.jit.si/$roomName';
    await _db.from('sessions').update({
      'state': SessionState.activeSession.englishKey,
      'room_url': roomUrl,
      'started_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', sessionId);
    await _db.from('session_events').insert({
      'session_id': sessionId,
      'event_type': 'SESSION_STARTED',
      'actor': 'teacher',
    });
    return roomUrl;
  }

  static Future<void> endSession(String sessionId) async {
    await _db.from('sessions').update({
      'state': SessionState.completed.englishKey,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', sessionId);
    await _db.from('session_events').insert({
      'session_id': sessionId,
      'event_type': 'SESSION_COMPLETED',
      'actor': 'teacher',
    });
  }

  static RealtimeChannel subscribeToSession(
    String sessionId,
    void Function(Session) onUpdate,
  ) {
    return _db
        .channel('session-$sessionId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'sessions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: sessionId,
          ),
          callback: (payload) async {
            final session = await getSession(sessionId);
            onUpdate(session);
          },
        )
        .subscribe();
  }
}
