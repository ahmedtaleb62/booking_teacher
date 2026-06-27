import 'package:teacher_booking/l10n/app_localizations.dart';

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final String? sessionId;
  final String? subscriptionId;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.sessionId,
    this.subscriptionId,
    required this.isRead,
    required this.createdAt,
  });

  String localizedTitle(AppLocalizations l) {
    switch (type) {
      // ── Session lifecycle (DB trigger — lowercase) ──────────────────
      case 'session_requested':
      case 'SESSION_REQUESTED':   return l.notifTypeSessionRequested;
      case 'session_approved':    return l.notifTypeSessionApproved;
      case 'session_rejected':
      case 'TEACHER_REJECTED':    return l.notifTypeTeacherRejected;
      case 'payment_confirmed':
      case 'PAYMENT_CONFIRMED':   return l.notifTypePaymentConfirmed;
      case 'payment_rejected':    return l.notifTypePaymentRejected;
      case 'session_started':
      case 'SESSION_STARTING':    return l.notifTypeSessionStarting;
      case 'teacher_no_show':
      case 'TEACHER_NO_SHOW':     return l.notifTypeTeacherNoShow;
      case 'student_no_show':
      case 'STUDENT_NO_SHOW':     return l.notifTypeStudentNoShow;
      case 'dispute_opened':
      case 'DISPUTE_OPENED':      return l.notifTypeDisputeOpened;
      // ── Legacy uppercase aliases ────────────────────────────────────
      case 'TEACHER_APPROVED':    return l.notifTypeSessionApproved;
      case 'PAYMENT_REQUIRED':    return l.notifTypePaymentRequired;
      case 'SESSION_CONFIRMED':   return l.notifTypeSessionConfirmed;
      case 'SESSION_COMPLETED':   return l.notifTypeSessionCompleted;
      case 'RESCHEDULED':         return l.notifTypeRescheduled;
      // ── Subscriptions ───────────────────────────────────────────────
      case 'SUB_PENDING':         return l.notifTypeSubPending;
      case 'SUB_ACTIVE':          return l.notifTypeSubActive;
      case 'SUB_REJECTED':        return l.notifTypeSubRejected;
      case 'subscription_refunded': return l.notifTypeSubscriptionRefunded;
      // ── Admin actions ───────────────────────────────────────────────
      case 'dispute_resolved':    return l.notifTypeDisputeResolved;
      case 'refund_processed':    return l.notifTypeRefundProcessed;
      case 'teacher_approved':    return l.notifTypeTeacherAccountApproved;
      case 'teacher_rejected':    return l.notifTypeTeacherAccountRejected;
      case 'teacher_revoked':     return l.notifTypeTeacherRevoked;
      case 'auto_cancelled':
      case 'AUTO_CANCELLED':      return l.notifTypeAutoCancelled;
      default:                    return title;
    }
  }

  String localizedBody(AppLocalizations l) {
    switch (type) {
      // ── Session lifecycle (DB trigger — lowercase) ──────────────────
      case 'session_requested':
      case 'SESSION_REQUESTED':   return l.notifBodySessionRequested;
      case 'session_approved':    return l.notifBodySessionApproved;
      case 'session_rejected':
      case 'TEACHER_REJECTED':    return l.notifBodyTeacherRejected;
      case 'payment_confirmed':
      case 'PAYMENT_CONFIRMED':   return l.notifBodyPaymentConfirmed;
      case 'payment_rejected':    return l.notifBodyPaymentRejected;
      case 'session_started':
      case 'SESSION_STARTING':    return l.notifBodySessionStarting;
      case 'teacher_no_show':
      case 'TEACHER_NO_SHOW':     return l.notifBodyTeacherNoShow;
      case 'student_no_show':
      case 'STUDENT_NO_SHOW':     return l.notifBodyStudentNoShow;
      case 'dispute_opened':
      case 'DISPUTE_OPENED':      return l.notifBodyDisputeOpened;
      // ── Legacy uppercase aliases ────────────────────────────────────
      case 'TEACHER_APPROVED':    return l.notifBodyTeacherApproved;
      case 'PAYMENT_REQUIRED':    return l.notifBodyPaymentRequired;
      case 'SESSION_CONFIRMED':   return l.notifBodySessionConfirmed;
      case 'SESSION_COMPLETED':   return l.notifBodySessionCompleted;
      case 'RESCHEDULED':         return l.notifBodyRescheduled;
      // ── Subscriptions ───────────────────────────────────────────────
      case 'SUB_PENDING':         return l.notifBodySubPending;
      case 'SUB_ACTIVE':          return l.notifBodySubActive;
      case 'SUB_REJECTED':        return l.notifBodySubRejected;
      case 'subscription_refunded': return l.notifBodySubscriptionRefunded;
      // ── Admin actions ───────────────────────────────────────────────
      case 'dispute_resolved':    return l.notifBodyDisputeResolved;
      case 'refund_processed':    return l.notifBodyRefundProcessed;
      case 'teacher_approved':    return l.notifBodyTeacherAccountApproved;
      case 'teacher_rejected':    return l.notifBodyTeacherAccountRejected;
      case 'teacher_revoked':     return l.notifBodyTeacherRevoked;
      case 'auto_cancelled':
      case 'AUTO_CANCELLED':      return l.notifBodyAutoCancelled;
      default:                    return body;
    }
  }

  String get icon {
    switch (type) {
      case 'session_requested':
      case 'SESSION_REQUESTED':   return '📝';
      case 'session_approved':
      case 'TEACHER_APPROVED':    return '🎉';
      case 'session_rejected':
      case 'TEACHER_REJECTED':    return '❌';
      case 'PAYMENT_REQUIRED':    return '💳';
      case 'payment_confirmed':
      case 'PAYMENT_CONFIRMED':   return '✅';
      case 'payment_rejected':    return '❌';
      case 'SESSION_CONFIRMED':   return '🎉';
      case 'session_started':
      case 'SESSION_STARTING':    return '🔔';
      case 'teacher_no_show':
      case 'TEACHER_NO_SHOW':     return '⚠️';
      case 'student_no_show':
      case 'STUDENT_NO_SHOW':     return '⚠️';
      case 'SESSION_COMPLETED':   return '⭐';
      case 'dispute_opened':
      case 'DISPUTE_OPENED':      return '🚨';
      case 'dispute_resolved':    return '✅';
      case 'RESCHEDULED':         return '🔄';
      case 'refund_processed':    return '💰';
      case 'SUB_PENDING':         return '⏳';
      case 'SUB_ACTIVE':          return '🎓';
      case 'SUB_REJECTED':        return '❌';
      case 'subscription_refunded': return '💰';
      case 'teacher_approved':    return '🎉';
      case 'teacher_rejected':    return '❌';
      case 'teacher_revoked':     return '🚫';
      case 'auto_cancelled':
      case 'AUTO_CANCELLED':      return '❌';
      default:                    return '🔔';
    }
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? {};
    return AppNotification(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      type: json['type'] as String,
      sessionId: json['session_id'] as String?,
      subscriptionId: data['subscription_id'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id, title: title, body: body, type: type,
      sessionId: sessionId, subscriptionId: subscriptionId,
      isRead: isRead ?? this.isRead, createdAt: createdAt,
    );
  }
}

// Mock notifications
class MockNotifications {
  static List<AppNotification> get list => [
    AppNotification(
      id: 'n1', title: 'وافق الأستاذ على طلبك',
      body: 'د. محمد الأمين وافق على جلسة رياضيات — أكمل الدفع الآن',
      type: 'TEACHER_APPROVED', sessionId: 'ses-001',
      isRead: false, createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
    ),
    AppNotification(
      id: 'n2', title: 'تأكيد الدفع',
      body: 'تم تأكيد دفعتك بنجاح. حجزك مؤكّد!',
      type: 'PAYMENT_CONFIRMED', sessionId: 'ses-001',
      isRead: false, createdAt: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    AppNotification(
      id: 'n3', title: 'جلستك اكتملت',
      body: 'انتهت جلسة اللغة العربية. يمكنك الآن تقييم الأستاذ.',
      type: 'SESSION_COMPLETED', sessionId: 'ses-003',
      isRead: true, createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];
}
