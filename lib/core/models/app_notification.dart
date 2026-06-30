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
      case 'session_approved':
      case 'TEACHER_APPROVED':    return l.notifTypeSessionApproved;
      case 'session_rejected':
      case 'TEACHER_REJECTED':    return l.notifTypeTeacherRejected;
      case 'payment_confirmed':
      case 'PAYMENT_CONFIRMED':
      case 'SESSION_CONFIRMED':   return l.notifTypePaymentConfirmed;
      case 'session_started':
      case 'SESSION_STARTING':    return l.notifTypeSessionStarting;
      case 'session_completed':
      case 'SESSION_COMPLETED':   return l.notifTypeSessionCompleted;
      // ── Subscriptions ───────────────────────────────────────────────
      case 'SUB_PENDING':         return l.notifTypeSubPending;
      case 'SUB_ACTIVE':          return l.notifTypeSubActive;
      case 'SUB_REJECTED':        return l.notifTypeSubRejected;
      // ── Admin / teacher account ──────────────────────────────────────
      case 'teacher_approved':    return l.notifTypeTeacherAccountApproved;
      case 'teacher_rejected':    return l.notifTypeTeacherAccountRejected;
      case 'teacher_revoked':     return l.notifTypeTeacherRevoked;
      // ── Platform announcements ───────────────────────────────────────
      case 'NEW_COURSE':          return l.notifTypeNewCourse;
      case 'NEW_PACKAGE':         return l.notifTypeNewPackage;
      case 'NEW_TEACHER':         return l.notifTypeNewTeacher;
      // ── Cancellations (title localized, body stays raw — reason-specific)
      case 'session_cancelled':
      case 'payment_rejected':    return l.notifTypeSessionCancelled;
      default:                    return title;
    }
  }

  String localizedBody(AppLocalizations l) {
    switch (type) {
      // ── Session lifecycle (DB trigger — lowercase) ──────────────────
      case 'session_requested':
      case 'SESSION_REQUESTED':   return l.notifBodySessionRequested;
      case 'session_approved':
      case 'TEACHER_APPROVED':    return l.notifBodySessionApproved;
      case 'session_rejected':
      case 'TEACHER_REJECTED':    return l.notifBodyTeacherRejected;
      case 'payment_confirmed':
      case 'PAYMENT_CONFIRMED':
      case 'SESSION_CONFIRMED':   return l.notifBodyPaymentConfirmed;
      case 'session_started':
      case 'SESSION_STARTING':    return l.notifBodySessionStarting;
      case 'session_completed':
      case 'SESSION_COMPLETED':   return l.notifBodySessionCompleted;
      // ── Subscriptions ───────────────────────────────────────────────
      case 'SUB_PENDING':         return l.notifBodySubPending;
      case 'SUB_ACTIVE':          return l.notifBodySubActive;
      case 'SUB_REJECTED':        return l.notifBodySubRejected;
      // ── Admin / teacher account ──────────────────────────────────────
      case 'teacher_approved':    return l.notifBodyTeacherAccountApproved;
      case 'teacher_rejected':    return l.notifBodyTeacherAccountRejected;
      case 'teacher_revoked':     return l.notifBodyTeacherRevoked;
      // ── Platform announcements ───────────────────────────────────────
      case 'NEW_COURSE':          return l.notifBodyNewCourse;
      case 'NEW_PACKAGE':         return l.notifBodyNewPackage;
      case 'NEW_TEACHER':         return l.notifBodyNewTeacher;
      // ── Cancellations (body stays raw — reason-specific) ────────────
      case 'session_cancelled':
      case 'payment_rejected':
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
      case 'payment_confirmed':
      case 'PAYMENT_CONFIRMED':
      case 'SESSION_CONFIRMED':   return '✅';
      case 'session_started':
      case 'SESSION_STARTING':    return '🔔';
      case 'session_completed':   return '⭐';
      case 'SUB_PENDING':         return '⏳';
      case 'SUB_ACTIVE':          return '🎓';
      case 'SUB_REJECTED':        return '❌';
      case 'teacher_approved':    return '🎉';
      case 'teacher_rejected':    return '❌';
      case 'teacher_revoked':     return '🚫';
      case 'session_cancelled':
      case 'payment_rejected':    return '❌';
      case 'NEW_COURSE':          return '📖';
      case 'NEW_PACKAGE':         return '🎁';
      case 'NEW_TEACHER':         return '🎓';
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

