import 'package:flutter/material.dart';

// ── Color helper ─────────────────────────────────────────────────
Color hexColor(String? hex, Color fallback) {
  if (hex == null || hex.isEmpty) return fallback;
  final clean = hex.replaceAll('#', '');
  if (clean.length == 6) {
    return Color(int.parse('FF$clean', radix: 16));
  }
  return fallback;
}

// ── Course ───────────────────────────────────────────────────────
class Course {
  final String id;
  final String title;
  final String? description;
  final String subject;
  final String level;
  final String? teacherId;
  final String teacherName;
  final String? teacherAvatarUrl;
  final int totalLessons;
  final double totalHours;
  final double priceMonthly;
  final double? priceQuarterly;
  final double? priceYearly;
  final double? originalPrice;
  final Color coverColor;
  final String? badge;
  final Color badgeBg;
  final Color badgeFg;
  final double? rating;
  final int ratingsCount;
  final int subscribersCount;
  final List<CourseLesson> lessons;

  const Course({
    required this.id,
    required this.title,
    this.description,
    required this.subject,
    required this.level,
    this.teacherId,
    this.teacherName = '',
    this.teacherAvatarUrl,
    required this.totalLessons,
    required this.totalHours,
    required this.priceMonthly,
    this.priceQuarterly,
    this.priceYearly,
    this.originalPrice,
    this.rating,
    this.ratingsCount = 0,
    this.subscribersCount = 0,
    required this.coverColor,
    this.badge,
    required this.badgeBg,
    required this.badgeFg,
    this.lessons = const [],
  });

  String get teacherInitial =>
      teacherName.isNotEmpty ? teacherName[0] : '؟';

  factory Course.fromJson(Map<String, dynamic> json) {
    final teacherMap      = json['teacher'] as Map?;
    final teacherName     = (teacherMap?['full_name'] as String?) ?? '';
    final teacherAvatarUrl = teacherMap?['avatar_url'] as String?;

    final lessonsJson = json['lessons'] as List<dynamic>? ?? [];
    final parsedLessons = lessonsJson
        .map((l) => CourseLesson.fromJson(l as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

    // Compute total hours from lesson durations if DB value is 0
    double totalHours = (json['total_hours'] as num?)?.toDouble() ?? 0;
    if (totalHours == 0 && parsedLessons.isNotEmpty) {
      final totalMinutes = parsedLessons.fold<int>(
          0, (sum, l) => sum + l.durationMinutes);
      totalHours = totalMinutes / 60.0;
    }

    return Course(
      id:               json['id'] as String,
      title:            json['title'] as String,
      description:      json['description'] as String?,
      subject:          json['subject'] as String,
      level:            json['level'] as String? ?? 'مبتدئ',
      teacherId:          json['teacher_id'] as String?,
      teacherName:        teacherName,
      teacherAvatarUrl:   teacherAvatarUrl,
      totalLessons:     json['total_lessons'] as int? ?? parsedLessons.length,
      totalHours:       totalHours,
      priceMonthly:     (json['price_monthly'] as num).toDouble(),
      priceQuarterly:   (json['price_quarterly'] as num?)?.toDouble(),
      priceYearly:      (json['price_yearly'] as num?)?.toDouble(),
      originalPrice:    (json['original_price'] as num?)?.toDouble(),
      rating:           (json['rating'] as num?)?.toDouble(),
      ratingsCount:     json['ratings_count'] as int? ?? 0,
      subscribersCount: json['subscribers_count'] as int? ?? 0,
      coverColor:       hexColor(json['cover_color'] as String?, const Color(0xFF1B6B7A)),
      badge:            json['badge'] as String?,
      badgeBg:          hexColor(json['badge_bg'] as String?, const Color(0xFF1B9E77)),
      badgeFg:          hexColor(json['badge_fg'] as String?, Colors.white),
      lessons:          parsedLessons,
    );
  }
}

// ── CourseLesson ─────────────────────────────────────────────────
class CourseLesson {
  final String id;
  final String courseId;
  final String title;
  final String? description;
  final String? videoUrl;
  final String? thumbnailUrl;
  final int orderIndex;
  final int durationMinutes;
  final int? filePages;
  final bool isPreview;
  final bool completed;
  final String? chapterTitle;
  final String lessonType; // 'video' | 'file' | 'exercise' | 'summary'
  final List<Map<String, dynamic>>? quizData;

  const CourseLesson({
    required this.id,
    required this.courseId,
    required this.title,
    this.description,
    this.videoUrl,
    this.thumbnailUrl,
    required this.orderIndex,
    required this.durationMinutes,
    this.filePages,
    this.isPreview = false,
    this.completed = false,
    this.chapterTitle,
    this.lessonType = 'video',
    this.quizData,
  });

  // Shows "X د" for video/summary, "X صفحة" for file, empty for exercise
  String get infoLabel {
    switch (lessonType) {
      case 'file':
        return (filePages != null && filePages! > 0) ? '$filePages صفحة' : '';
      case 'exercise':
        return '';
      default:
        if (durationMinutes <= 0) return '';
        if (durationMinutes < 60) return '$durationMinutes د';
        final h = durationMinutes ~/ 60;
        final m = durationMinutes % 60;
        return m == 0 ? '$h س' : '$h س $m د';
    }
  }

  // Kept for compatibility
  String get durationLabel => infoLabel;

  factory CourseLesson.fromJson(Map<String, dynamic> json) {
    final progress = json['progress'] as Map?;
    return CourseLesson(
      id: json['id'] as String,
      courseId: json['course_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      videoUrl: json['video_url'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      orderIndex: json['order_index'] as int? ?? 0,
      durationMinutes: json['duration_minutes'] as int? ?? 0,
      filePages: json['file_pages'] as int?,
      isPreview: json['is_preview'] as bool? ?? false,
      completed: progress?['completed'] as bool? ?? false,
      chapterTitle: json['chapter_title'] as String?,
      lessonType: json['lesson_type'] as String? ?? 'video',
      quizData: (json['quiz_data'] as List?)
          ?.map((q) => Map<String, dynamic>.from(q as Map))
          .toList(),
    );
  }
}

// ── Package ──────────────────────────────────────────────────────
class CoursePackage {
  final String id;
  final String title;
  final String? description;
  final double priceMonthly;
  final double? priceYearly;
  final double? originalPrice;
  final Color coverColor;
  final String? subjects;
  final String? saveLabel;
  final List<Course> courses;

  const CoursePackage({
    required this.id,
    required this.title,
    this.description,
    required this.priceMonthly,
    this.priceYearly,
    this.originalPrice,
    required this.coverColor,
    this.subjects,
    this.saveLabel,
    this.courses = const [],
  });

  int get totalLessons => courses.fold(0, (s, c) => s + c.totalLessons);

  factory CoursePackage.fromJson(Map<String, dynamic> json) {
    final coursesList = (json['package_courses'] as List<dynamic>? ?? [])
        .map((pc) {
          final courseData = pc['course'] as Map<String, dynamic>?;
          return courseData != null ? Course.fromJson(courseData) : null;
        })
        .whereType<Course>()
        .toList();

    return CoursePackage(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      priceMonthly: (json['price_monthly'] as num).toDouble(),
      priceYearly: (json['price_yearly'] as num?)?.toDouble(),
      originalPrice: (json['original_price'] as num?)?.toDouble(),
      coverColor: hexColor(json['cover_color'] as String?, const Color(0xFF7B61FF)),
      subjects: json['subjects'] as String?,
      saveLabel: json['save_label'] as String?,
      courses: coursesList,
    );
  }
}

// ── Subscription ─────────────────────────────────────────────────
class Subscription {
  final String id;
  final String studentId;
  final String? courseId;
  final String? packageId;
  final String type;
  final SubscriptionStatus status;
  final String? proofImageUrl;
  final double amount;
  final String? rejectReason;
  final double? actualRefundAmount;
  final DateTime? startedAt;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final Course? course;
  final CoursePackage? package;
  final int completedLessons;

  const Subscription({
    required this.id,
    required this.studentId,
    this.courseId,
    this.packageId,
    required this.type,
    required this.status,
    this.proofImageUrl,
    required this.amount,
    this.rejectReason,
    this.actualRefundAmount,
    this.startedAt,
    this.expiresAt,
    required this.createdAt,
    this.course,
    this.package,
    this.completedLessons = 0,
  });

  String get itemName => course?.title ?? package?.title ?? '—';
  String get itemSubject => course?.subject ?? package?.subjects ?? '';
  int get totalLessons => course?.totalLessons ?? package?.totalLessons ?? 0;

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  factory Subscription.fromJson(Map<String, dynamic> json) {
    final courseData = json['course'] as Map<String, dynamic>?;
    final packageData = json['package'] as Map<String, dynamic>?;
    return Subscription(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      courseId: json['course_id'] as String?,
      packageId: json['package_id'] as String?,
      type: json['type'] as String,
      status: SubscriptionStatus.values.firstWhere(
        (s) => s.name == (json['status'] as String? ?? 'pending'),
        orElse: () => SubscriptionStatus.pending,
      ),
      proofImageUrl: json['proof_image_url'] as String?,
      amount: (json['amount'] as num).toDouble(),
      rejectReason: json['reject_reason'] as String?,
      actualRefundAmount: (json['actual_refund_amount'] as num?)?.toDouble(),
      startedAt: json['started_at'] != null
          ? DateTime.parse(json['started_at'] as String)
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      course: courseData != null ? Course.fromJson(courseData) : null,
      package: packageData != null ? CoursePackage.fromJson(packageData) : null,
    );
  }
}

enum SubscriptionStatus { pending, active, expired, rejected, suspended }

extension SubscriptionStatusX on SubscriptionStatus {
  String get label {
    switch (this) {
      case SubscriptionStatus.pending:   return 'قيد المراجعة';
      case SubscriptionStatus.active:    return 'نشط';
      case SubscriptionStatus.expired:   return 'منتهي';
      case SubscriptionStatus.rejected:  return 'مرفوض';
      case SubscriptionStatus.suspended: return 'معطَّل';
    }
  }

  Color get color {
    switch (this) {
      case SubscriptionStatus.pending:   return const Color(0xFF7B61FF);
      case SubscriptionStatus.active:    return const Color(0xFF16A34A);
      case SubscriptionStatus.expired:   return const Color(0xFF8A96A3);
      case SubscriptionStatus.rejected:  return const Color(0xFFC0392B);
      case SubscriptionStatus.suspended: return const Color(0xFFC0392B);
    }
  }

  Color get bgColor {
    switch (this) {
      case SubscriptionStatus.pending:   return const Color(0xFFF0EDFF);
      case SubscriptionStatus.active:    return const Color(0xFFDCFCE7);
      case SubscriptionStatus.expired:   return const Color(0xFFF1F2F4);
      case SubscriptionStatus.rejected:  return const Color(0xFFFDECEC);
      case SubscriptionStatus.suspended: return const Color(0xFFFDECEC);
    }
  }
}
