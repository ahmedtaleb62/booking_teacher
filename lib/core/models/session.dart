import '../constants/session_states.dart';

class Session {
  final String id;
  final String studentId;
  final String teacherId;
  final String teacherName;
  final String teacherInitial;
  final String subject;
  final SessionState state;
  final DateTime scheduledAt;
  final int durationMinutes;
  final double amount;
  final String? studentNote;
  final String? parentSessionId;
  final String? roomUrl;
  final DateTime? startedAt;
  final Payment? payment;
  final List<SessionEvent> events;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Session({
    required this.id,
    required this.studentId,
    required this.teacherId,
    required this.teacherName,
    required this.teacherInitial,
    required this.subject,
    required this.state,
    required this.scheduledAt,
    required this.durationMinutes,
    required this.amount,
    this.studentNote,
    this.parentSessionId,
    this.roomUrl,
    this.startedAt,
    this.payment,
    required this.events,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get canEnterSession {
    final now = DateTime.now();
    final diff = scheduledAt.difference(now).inMinutes;
    return state == SessionState.confirmedBooking && diff <= 10 && diff >= -durationMinutes;
  }

  bool get isLive => state == SessionState.activeSession;

  Session copyWith({SessionState? state, String? roomUrl, Payment? payment, List<SessionEvent>? events}) {
    return Session(
      id: id,
      studentId: studentId,
      teacherId: teacherId,
      teacherName: teacherName,
      teacherInitial: teacherInitial,
      subject: subject,
      state: state ?? this.state,
      scheduledAt: scheduledAt,
      durationMinutes: durationMinutes,
      amount: amount,
      studentNote: studentNote,
      parentSessionId: parentSessionId,
      roomUrl: roomUrl ?? this.roomUrl,
      startedAt: startedAt,
      payment: payment ?? this.payment,
      events: events ?? this.events,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      teacherId: json['teacher_id'] as String,
      teacherName: json['teacher_name'] as String? ?? '',
      teacherInitial: (json['teacher_name'] as String? ?? '?').isNotEmpty
          ? (json['teacher_name'] as String)[0]
          : '?',
      subject: json['subject'] as String? ?? '',
      state: SessionStateX.fromString(json['state'] as String? ?? 'REQUESTED'),
      scheduledAt: DateTime.parse(json['scheduled_at'] as String),
      durationMinutes: json['duration_minutes'] as int? ?? 60,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      studentNote: json['student_note'] as String?,
      parentSessionId: json['parent_session_id'] as String?,
      roomUrl: json['room_url'] as String?,
      startedAt: json['started_at'] != null ? DateTime.parse(json['started_at'] as String) : null,
      payment: json['payment'] != null
          ? Payment.fromJson(json['payment'] as Map<String, dynamic>)
          : null,
      events: (json['events'] as List<dynamic>? ?? [])
          .map((e) => SessionEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class Payment {
  final String id;
  final String sessionId;
  final double amount;
  final String method;
  final String? proofImageUrl;
  final String reference;
  final PaymentStatus status;
  final DateTime createdAt;

  const Payment({
    required this.id,
    required this.sessionId,
    required this.amount,
    required this.method,
    this.proofImageUrl,
    required this.reference,
    required this.status,
    required this.createdAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      method: json['method'] as String,
      proofImageUrl: json['proof_image_url'] as String?,
      reference: json['reference'] as String? ?? '',
      status: PaymentStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => PaymentStatus.pending,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

enum PaymentStatus { pending, submitted, confirmed, rejected }

class SessionEvent {
  final String id;
  final String sessionId;
  final String eventType;
  final String? actor;
  final String? note;
  final DateTime createdAt;

  const SessionEvent({
    required this.id,
    required this.sessionId,
    required this.eventType,
    this.actor,
    this.note,
    required this.createdAt,
  });

  String get label {
    switch (eventType) {
      case 'REQUESTED':        return 'أرسلت الطلب';
      case 'TEACHER_APPROVED': return 'وافق الأستاذ';
      case 'TEACHER_REJECTED': return 'رفض الأستاذ';
      case 'PAYMENT_SUBMITTED':return 'رُفع إثبات الدفع';
      case 'PAYMENT_CONFIRMED':return 'أكّدت الإدارة الدفع';
      case 'SESSION_STARTED':  return 'بدأت الجلسة';
      case 'SESSION_COMPLETED':return 'انتهت الجلسة';
      case 'TEACHER_NO_SHOW':  return 'غياب الأستاذ';
      case 'STUDENT_NO_SHOW':  return 'غياب الطالب';
      case 'DISPUTE_OPENED':   return 'فُتح نزاع';
      case 'CANCELLED':        return 'تم الإلغاء';
      case 'RESCHEDULED':      return 'إعادة جدولة';
      default:                 return eventType;
    }
  }

  factory SessionEvent.fromJson(Map<String, dynamic> json) {
    return SessionEvent(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      eventType: json['event_type'] as String,
      actor: json['actor'] as String?,
      note: json['note'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

// Mock sessions for UI development
class MockSessions {
  static List<Session> get list => [
    Session(
      id: 'ses-001',
      studentId: 'stu-1',
      teacherId: 'tch-1',
      teacherName: 'د. محمد الأمين',
      teacherInitial: 'م',
      subject: 'رياضيات',
      state: SessionState.confirmedBooking,
      scheduledAt: DateTime.now().add(const Duration(hours: 2)),
      durationMinutes: 60,
      amount: 500,
      studentNote: 'أحتاج مراجعة الدوال والنهايات',
      events: [
        SessionEvent(id: 'e1', sessionId: 'ses-001', eventType: 'REQUESTED', createdAt: DateTime.now().subtract(const Duration(hours: 3))),
        SessionEvent(id: 'e2', sessionId: 'ses-001', eventType: 'TEACHER_APPROVED', createdAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 30))),
        SessionEvent(id: 'e3', sessionId: 'ses-001', eventType: 'PAYMENT_CONFIRMED', createdAt: DateTime.now().subtract(const Duration(hours: 2))),
      ],
      createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
    Session(
      id: 'ses-002',
      studentId: 'stu-1',
      teacherId: 'tch-2',
      teacherName: 'أ. فاطمة محمود',
      teacherInitial: 'ف',
      subject: 'فيزياء',
      state: SessionState.requested,
      scheduledAt: DateTime.now().add(const Duration(days: 1, hours: 4)),
      durationMinutes: 60,
      amount: 450,
      events: [
        SessionEvent(id: 'e4', sessionId: 'ses-002', eventType: 'REQUESTED', createdAt: DateTime.now().subtract(const Duration(minutes: 30))),
      ],
      createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
      updatedAt: DateTime.now().subtract(const Duration(minutes: 30)),
    ),
    Session(
      id: 'ses-003',
      studentId: 'stu-1',
      teacherId: 'tch-3',
      teacherName: 'د. أحمد ولد سيدي',
      teacherInitial: 'أ',
      subject: 'لغة عربية',
      state: SessionState.completed,
      scheduledAt: DateTime.now().subtract(const Duration(days: 2)),
      durationMinutes: 60,
      amount: 400,
      events: [
        SessionEvent(id: 'e5', sessionId: 'ses-003', eventType: 'REQUESTED', createdAt: DateTime.now().subtract(const Duration(days: 3))),
        SessionEvent(id: 'e6', sessionId: 'ses-003', eventType: 'TEACHER_APPROVED', createdAt: DateTime.now().subtract(const Duration(days: 2, hours: 23))),
        SessionEvent(id: 'e7', sessionId: 'ses-003', eventType: 'PAYMENT_CONFIRMED', createdAt: DateTime.now().subtract(const Duration(days: 2, hours: 22))),
        SessionEvent(id: 'e8', sessionId: 'ses-003', eventType: 'SESSION_COMPLETED', createdAt: DateTime.now().subtract(const Duration(days: 2))),
      ],
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      updatedAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];
}
