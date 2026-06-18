class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type;
  final String? sessionId;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    this.sessionId,
    required this.isRead,
    required this.createdAt,
  });

  String get icon {
    switch (type) {
      case 'SESSION_REQUESTED':   return '📝';
      case 'TEACHER_APPROVED':    return '✅';
      case 'TEACHER_REJECTED':    return '❌';
      case 'PAYMENT_REQUIRED':    return '💳';
      case 'PAYMENT_CONFIRMED':   return '✅';
      case 'SESSION_CONFIRMED':   return '🎉';
      case 'SESSION_STARTING':    return '🔴';
      case 'TEACHER_NO_SHOW':     return '⚠️';
      case 'STUDENT_NO_SHOW':     return '⚠️';
      case 'SESSION_COMPLETED':   return '⭐';
      case 'DISPUTE_OPENED':      return '🚨';
      case 'RESCHEDULED':         return '🔄';
      default:                    return '🔔';
    }
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      type: json['type'] as String,
      sessionId: json['session_id'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id, title: title, body: body, type: type,
      sessionId: sessionId, isRead: isRead ?? this.isRead,
      createdAt: createdAt,
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
