class Teacher {
  final String id;
  final String name;
  final String subject;
  final List<String> subjects;
  final double rating;
  final int reviewCount;
  final double pricePerHour;
  final bool isOnline;
  final bool isVerified;
  final String bio;
  final int yearsExperience;
  final int totalSessions;
  final double attendanceRate;
  final String? avatarUrl;
  final String initial;
  final List<TimeSlot> availableSlots;

  const Teacher({
    required this.id,
    required this.name,
    required this.subject,
    required this.subjects,
    required this.rating,
    required this.reviewCount,
    required this.pricePerHour,
    required this.isOnline,
    required this.isVerified,
    required this.bio,
    required this.yearsExperience,
    required this.totalSessions,
    required this.attendanceRate,
    this.avatarUrl,
    required this.initial,
    required this.availableSlots,
  });

  factory Teacher.fromJson(Map<String, dynamic> json) {
    return Teacher(
      id: json['id'] as String,
      name: json['name'] as String,
      subject: json['subject'] as String,
      subjects: List<String>.from(json['subjects'] ?? []),
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      reviewCount: json['review_count'] as int? ?? 0,
      pricePerHour: (json['price_per_hour'] as num?)?.toDouble() ?? 0,
      isOnline: json['is_online'] as bool? ?? false,
      isVerified: json['is_verified'] as bool? ?? false,
      bio: json['bio'] as String? ?? '',
      yearsExperience: json['years_experience'] as int? ?? 0,
      totalSessions: json['total_sessions'] as int? ?? 0,
      attendanceRate: (json['attendance_rate'] as num?)?.toDouble() ?? 0,
      avatarUrl: json['avatar_url'] as String?,
      initial: (json['name'] as String? ?? '?').isNotEmpty ? (json['name'] as String)[0] : '?',
      availableSlots: (json['available_slots'] as List<dynamic>? ?? [])
          .map((s) => TimeSlot.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TimeSlot {
  final DateTime dateTime;
  final bool isBooked;
  final int durationMinutes;

  const TimeSlot({
    required this.dateTime,
    required this.isBooked,
    this.durationMinutes = 60,
  });

  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    return TimeSlot(
      dateTime: DateTime.parse(json['date_time'] as String),
      isBooked: json['is_booked'] as bool? ?? false,
      durationMinutes: json['duration_minutes'] as int? ?? 60,
    );
  }
}

// Mock data for UI development
class MockTeachers {
  static List<Teacher> get list => [
    Teacher(
      id: '1',
      name: 'د. محمد الأمين',
      subject: 'رياضيات',
      subjects: ['رياضيات', 'إحصاء', 'جبر خطّي'],
      rating: 4.9,
      reviewCount: 128,
      pricePerHour: 500,
      isOnline: true,
      isVerified: true,
      bio: 'أستاذ رياضيات متخصص في الثانوية والإعداد للباكالوريا. أركّز على بناء الفهم خطوة بخطوة وحل التمارين تفاعلياً.',
      yearsExperience: 8,
      totalSessions: 340,
      attendanceRate: 98,
      initial: 'م',
      availableSlots: [
        TimeSlot(dateTime: DateTime.now().add(const Duration(hours: 4)), isBooked: false),
        TimeSlot(dateTime: DateTime.now().add(const Duration(hours: 6, minutes: 30)), isBooked: false),
        TimeSlot(dateTime: DateTime.now().add(const Duration(hours: 8)), isBooked: true),
      ],
    ),
    Teacher(
      id: '2',
      name: 'أ. فاطمة محمود',
      subject: 'فيزياء',
      subjects: ['فيزياء', 'كيمياء'],
      rating: 4.7,
      reviewCount: 87,
      pricePerHour: 450,
      isOnline: false,
      isVerified: true,
      bio: 'أستاذة علوم متخصصة في الفيزياء والكيمياء مع خبرة في تبسيط المفاهيم الصعبة.',
      yearsExperience: 5,
      totalSessions: 210,
      attendanceRate: 95,
      initial: 'ف',
      availableSlots: [],
    ),
    Teacher(
      id: '3',
      name: 'د. أحمد ولد سيدي',
      subject: 'لغة عربية',
      subjects: ['لغة عربية', 'نحو وصرف', 'أدب'],
      rating: 4.8,
      reviewCount: 64,
      pricePerHour: 400,
      isOnline: true,
      isVerified: false,
      bio: 'متخصص في تدريس اللغة العربية وقواعدها لجميع المستويات.',
      yearsExperience: 10,
      totalSessions: 180,
      attendanceRate: 97,
      initial: 'أ',
      availableSlots: [],
    ),
    Teacher(
      id: '4',
      name: 'م. خديجة آدم',
      subject: 'إنجليزية',
      subjects: ['لغة إنجليزية', 'IELTS', 'محادثة'],
      rating: 4.6,
      reviewCount: 42,
      pricePerHour: 350,
      isOnline: true,
      isVerified: true,
      bio: 'معلّمة لغة إنجليزية حاصلة على شهادة CELTA مع خبرة في تحضير طلاب IELTS.',
      yearsExperience: 4,
      totalSessions: 120,
      attendanceRate: 94,
      initial: 'خ',
      availableSlots: [],
    ),
  ];
}
