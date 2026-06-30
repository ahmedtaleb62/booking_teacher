import '../constants/session_states.dart';
import '../../l10n/app_localizations.dart';

class Session {
  final String id;
  final String studentId;
  final String teacherId;
  final String teacherName;
  final String teacherInitial;
  final String studentName;
  final String subject;
  final SessionState state;
  final DateTime scheduledAt;
  final int durationMinutes;
  final double amount;
  final String? studentLevel;
  final String? studentNote;
  final String? parentSessionId;
  final String? roomUrl;
  final DateTime? startedAt;
  final DateTime? teacherLeftAt;
  final DateTime? studentJoinedAt;
  final DateTime? paymentDeadline;
  final Payment? payment;
  final List<SessionEvent> events;
  final String? teacherAvatarUrl;
  final String? studentAvatarUrl;
  final String? cancellationReason;
  final String? refundStatus;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Session({
    required this.id,
    required this.studentId,
    required this.teacherId,
    required this.teacherName,
    required this.teacherInitial,
    this.studentName = '',
    this.teacherAvatarUrl,
    this.studentAvatarUrl,
    required this.subject,
    required this.state,
    required this.scheduledAt,
    required this.durationMinutes,
    required this.amount,
    this.studentLevel,
    this.studentNote,
    this.parentSessionId,
    this.roomUrl,
    this.startedAt,
    this.teacherLeftAt,
    this.studentJoinedAt,
    this.paymentDeadline,
    this.payment,
    required this.events,
    this.cancellationReason,
    this.refundStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get canEnterSession {
    if (state == SessionState.activeSession) return true;
    if (state != SessionState.confirmedBooking) return false;
    final now = DateTime.now();
    final diff = scheduledAt.difference(now).inMinutes;
    return diff <= 10 && diff >= -durationMinutes;
  }

  bool get isLive => state == SessionState.activeSession;

  bool get hasRefundRequested => refundStatus == 'student_requested';
  bool get hasRefundProcessed => refundStatus == 'admin_processed';

  Session copyWith({
    SessionState? state,
    String? roomUrl,
    DateTime? studentJoinedAt,
    DateTime? paymentDeadline,
    Payment? payment,
    List<SessionEvent>? events,
    String? cancellationReason,
    String? refundStatus,
  }) {
    return Session(
      id: id,
      studentId: studentId,
      teacherId: teacherId,
      teacherName: teacherName,
      teacherInitial: teacherInitial,
      teacherAvatarUrl: teacherAvatarUrl,
      studentAvatarUrl: studentAvatarUrl,
      subject: subject,
      state: state ?? this.state,
      scheduledAt: scheduledAt,
      durationMinutes: durationMinutes,
      amount: amount,
      studentLevel: studentLevel,
      studentNote: studentNote,
      parentSessionId: parentSessionId,
      roomUrl: roomUrl ?? this.roomUrl,
      startedAt: startedAt,
      teacherLeftAt: teacherLeftAt,
      studentJoinedAt: studentJoinedAt ?? this.studentJoinedAt,
      paymentDeadline: paymentDeadline ?? this.paymentDeadline,
      payment: payment ?? this.payment,
      events: events ?? this.events,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      refundStatus: refundStatus ?? this.refundStatus,
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
      teacherInitial: ((json['teacher_name'] as String?) ?? '?').isNotEmpty
          ? ((json['teacher_name'] as String?) ?? '?')[0]
          : '?',
      studentName: json['student_name'] as String? ?? '',
      teacherAvatarUrl: json['teacher_avatar_url'] as String?,
      studentAvatarUrl: json['student_avatar_url'] as String?,
      subject: json['subject'] as String? ?? '',
      state: SessionStateX.fromString(json['state'] as String? ?? 'REQUESTED'),
      scheduledAt: DateTime.parse(json['scheduled_at'] as String),
      durationMinutes: json['duration_minutes'] as int? ?? 60,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      studentLevel: json['student_level'] as String?,
      studentNote: json['student_note'] as String?,
      parentSessionId: json['parent_session_id'] as String?,
      roomUrl: json['room_url'] as String?,
      startedAt: json['started_at'] != null ? DateTime.parse(json['started_at'] as String) : null,
      teacherLeftAt: json['teacher_left_at'] != null ? DateTime.parse(json['teacher_left_at'] as String) : null,
      studentJoinedAt: json['student_joined_at'] != null ? DateTime.parse(json['student_joined_at'] as String) : null,
      paymentDeadline: json['payment_deadline'] != null ? DateTime.parse(json['payment_deadline'] as String) : null,
      payment: json['payment'] != null
          ? Payment.fromJson(json['payment'] as Map<String, dynamic>)
          : null,
      events: (json['events'] as List<dynamic>? ?? [])
          .map((e) => SessionEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      cancellationReason: json['cancellation_reason'] as String?,
      refundStatus: json['refund_status'] as String?,
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
  final String? rejectReason;
  final DateTime createdAt;

  const Payment({
    required this.id,
    required this.sessionId,
    required this.amount,
    required this.method,
    this.proofImageUrl,
    required this.reference,
    required this.status,
    this.rejectReason,
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
      rejectReason: json['reject_reason'] as String?,
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

  String labelFor(AppLocalizations l, {String? cancellationReason}) {
    switch (eventType) {
      case 'REQUESTED':         return l.evtRequested;
      case 'TEACHER_APPROVED':  return l.evtTeacherApproved;
      case 'TEACHER_REJECTED':  return l.evtTeacherRejected;
      case 'AWAITING_PAYMENT':  return l.evtAwaitingPayment;
      case 'PAYMENT_SUBMITTED': return l.evtPaymentSubmitted;
      case 'PAYMENT_REJECTED':  return l.evtPaymentRejected;
      case 'PAYMENT_CONFIRMED': return l.evtPaymentConfirmed;
      case 'CONFIRMED_BOOKING': return l.evtConfirmedBooking;
      case 'SESSION_STARTED':   return l.evtSessionStarted;
      case 'SESSION_COMPLETED': return l.evtSessionCompleted;
      case 'ACTIVE_SESSION':    return l.evtActiveSession;
      case 'COMPLETED':         return l.evtCompleted;
      case 'CANCELLED':
        switch (cancellationReason) {
          case 'teacher_timeout':        return 'انتهت مهلة رد الأستاذ — إلغاء تلقائي';
          case 'payment_timeout':
          case 'no_payment_deadline':    return 'انتهت مهلة الدفع — إلغاء تلقائي';
          case 'fake_proof':             return 'رُفض الدفع — الوصل مزيف';
          case 'insufficient_refund':    return 'رُفض الدفع — المبلغ غير مكتمل';
          case 'teacher_no_show_refund': return 'إلغاء — غياب الأستاذ · سيُستَرد مبلغك';
          default:                       return l.evtCancelled;
        }
      case 'RESCHEDULED':       return l.evtRescheduled;
      case 'REFUND_REQUESTED':  return l.evtRefundRequested;
      case 'REFUND_PROCESSED':  return l.evtRefundProcessed;
      default:                  return eventType;
    }
  }

  String teacherLabelFor(AppLocalizations l, {String? cancellationReason}) {
    switch (eventType) {
      case 'REQUESTED':         return l.evtTRequested;
      case 'TEACHER_APPROVED':  return l.evtTApproved;
      case 'TEACHER_REJECTED':  return l.evtTRejected;
      case 'AWAITING_PAYMENT':  return l.evtTAwaitingPayment;
      case 'PAYMENT_SUBMITTED': return l.evtTPaymentSubmitted;
      case 'PAYMENT_REJECTED':  return l.evtTPaymentRejected;
      case 'PAYMENT_CONFIRMED': return l.evtTPaymentConfirmed;
      case 'CONFIRMED_BOOKING': return l.evtTConfirmedBooking;
      case 'SESSION_STARTED':   return l.evtTSessionStarted;
      case 'SESSION_COMPLETED': return l.evtTSessionCompleted;
      case 'ACTIVE_SESSION':    return l.evtTActiveSession;
      case 'COMPLETED':         return l.evtTCompleted;
      case 'CANCELLED':
        switch (cancellationReason) {
          case 'teacher_timeout':        return 'انتهت مهلة ردك — إلغاء تلقائي';
          case 'payment_timeout':
          case 'no_payment_deadline':    return 'انتهت مهلة دفع الطالب — إلغاء تلقائي';
          case 'student_cancelled':      return l.evtTCancelled;
          case 'fake_proof':             return 'رُفض الدفع — الوصل مزيف';
          case 'insufficient_refund':    return 'رُفض الدفع — المبلغ غير مكتمل';
          case 'teacher_no_show_refund': return 'إلغاء — غياب الأستاذ';
          default:                       return l.evtTCancelled;
        }
      case 'RESCHEDULED':       return l.evtTRescheduled;
      case 'REFUND_REQUESTED':  return l.evtTRefundRequested;
      case 'REFUND_PROCESSED':  return l.evtTRefundProcessed;
      default:                  return eventType;
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

