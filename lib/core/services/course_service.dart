import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/course.dart';
import 'supabase_service.dart';

class CourseService {
  static final _db = SupabaseService.client;

  // ── Courses ─────────────────────────────────────────────────────

  static Future<List<Course>> getCourses({String? subject}) async {
    var q = _db
        .from('courses')
        .select('*, teacher:teacher_id(full_name, avatar_url)')
        .eq('is_active', true);
    if (subject != null) q = q.eq('subject', subject);
    final data = await q.order('created_at', ascending: false);
    return (data as List)
        .map((j) => Course.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  static Future<Course> getCourseDetails(String courseId) async {
    final courseData = await _db
        .from('courses')
        .select('*, teacher:teacher_id(full_name, avatar_url)')
        .eq('id', courseId)
        .single();

    final uid = SupabaseService.userId;
    List<dynamic> lessonsRaw = [];

    if (uid != null) {
      // 1. Full lesson outline for ALL authenticated users (no video_url — bypasses RLS)
      final outlineData = await _db
          .rpc('get_course_lesson_outline', params: {'p_course_id': courseId});
      final outline = (outlineData as List).map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        m['course_id'] = courseId;
        return m;
      }).toList();

      // 2. Full lesson data (video_url etc.) — RLS returns rows only for subscribers
      final fullData = await _db
          .from('course_lessons')
          .select('id, video_url, quiz_data, description, thumbnail_url, lesson_type')
          .eq('course_id', courseId);
      final fullMap = <String, Map<String, dynamic>>{
        for (final f in (fullData as List))
          (f as Map<String, dynamic>)['id'] as String:
              Map<String, dynamic>.from(f as Map),
      };

      // 3. Progress for completed lessons
      final progressData = await _db
          .from('lesson_progress')
          .select('lesson_id, completed')
          .eq('student_id', uid);
      final progressMap = <String, bool>{};
      for (final p in (progressData as List)) {
        final m = p as Map<String, dynamic>;
        progressMap[m['lesson_id'] as String] = m['completed'] == true;
      }

      // Merge: outline + subscribed video data + progress
      lessonsRaw = outline.map((item) {
        final m = Map<String, dynamic>.from(item);
        final full = fullMap[m['id'] as String];
        if (full != null) {
          m['video_url']     = full['video_url'];
          m['quiz_data']     = full['quiz_data'];
          m['description']   = full['description'];
          m['thumbnail_url'] = full['thumbnail_url'];
          if (full['lesson_type'] != null) m['lesson_type'] = full['lesson_type'];
        }
        if (progressMap.containsKey(m['id'] as String)) {
          m['progress'] = {'completed': progressMap[m['id'] as String]};
        }
        return m;
      }).toList();
    } else {
      // Logged-out: only preview lessons
      final lessonsData = await _db
          .from('course_lessons')
          .select('*')
          .eq('course_id', courseId)
          .eq('is_preview', true)
          .order('order_index');
      lessonsRaw = lessonsData as List;
    }

    // subscribers_count comes from the denormalized column on courses
    // (maintained by trigger — avoids RLS issues with reading other students' subscriptions)
    final map = Map<String, dynamic>.from(courseData as Map);
    map['lessons'] = lessonsRaw;
    return Course.fromJson(map);
  }

  // ── Packages ─────────────────────────────────────────────────────

  static Future<List<CoursePackage>> getPackages() async {
    final data = await _db
        .from('packages')
        .select('*, package_courses(course:course_id(*, teacher:teacher_id(full_name)))')
        .eq('is_active', true)
        .order('created_at', ascending: false);
    return (data as List)
        .map((j) => CoursePackage.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  static Future<CoursePackage> getPackageDetails(String packageId) async {
    final data = await _db
        .from('packages')
        .select('*, package_courses(course:course_id(*, teacher:teacher_id(full_name)))')
        .eq('id', packageId)
        .single();
    return CoursePackage.fromJson(data);
  }

  // ── Subscriptions ────────────────────────────────────────────────

  static Future<List<Subscription>> getMySubscriptions() async {
    final uid = SupabaseService.userId;
    if (uid == null) return [];

    final results = await Future.wait([
      _db
          .from('subscriptions')
          .select('*, course:course_id(*, teacher:teacher_id(full_name)), package:package_id(*, package_courses(course:course_id(*)))')
          .eq('student_id', uid)
          .order('created_at', ascending: false),
      _db
          .from('lesson_progress')
          .select('subscription_id')
          .eq('student_id', uid)
          .eq('completed', true),
    ]);

    // Count completed lessons per subscription
    final progress = results[1] as List;
    final countMap = <String, int>{};
    for (final p in progress) {
      final sid = (p as Map)['subscription_id'] as String?;
      if (sid != null) countMap[sid] = (countMap[sid] ?? 0) + 1;
    }

    return (results[0] as List).map((j) {
      final map = Map<String, dynamic>.from(j as Map);
      final sub = Subscription.fromJson(map);
      final completed = countMap[sub.id] ?? 0;
      return completed > 0
          ? Subscription(
              id: sub.id, studentId: sub.studentId, courseId: sub.courseId,
              packageId: sub.packageId, type: sub.type, status: sub.status,
              proofImageUrl: sub.proofImageUrl, amount: sub.amount,
              rejectReason: sub.rejectReason, startedAt: sub.startedAt,
              expiresAt: sub.expiresAt, createdAt: sub.createdAt,
              course: sub.course, package: sub.package,
              completedLessons: completed,
            )
          : sub;
    }).toList();
  }

  static Future<Subscription?> getActiveSubscription(String courseId) async {
    final uid = SupabaseService.userId;
    if (uid == null) return null;
    final data = await _db
        .from('subscriptions')
        .select('*, course:course_id(title, price_monthly, cover_color)')
        .eq('student_id', uid)
        .eq('course_id', courseId)
        .eq('status', 'active')
        .maybeSingle();
    if (data == null) return null;
    return Subscription.fromJson(data);
  }

  // Returns 'active' | 'pending' | 'rejected' | 'expired' | null
  static Future<String?> getSubscriptionStatus({
    String? courseId,
    String? packageId,
  }) async {
    final uid = SupabaseService.userId;
    if (uid == null) return null;

    var q = _db
        .from('subscriptions')
        .select('status, expires_at')
        .eq('student_id', uid);

    if (courseId != null)  q = q.eq('course_id', courseId);
    if (packageId != null) q = q.eq('package_id', packageId);

    final data = await q
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (data == null) return null;

    final status = data['status'] as String;
    if (status == 'active') {
      final exp = data['expires_at'] as String?;
      if (exp != null && DateTime.now().isAfter(DateTime.parse(exp))) {
        return 'expired';
      }
    }
    return status;
  }

  static Future<bool> hasActiveSubscription({
    String? courseId,
    String? packageId,
  }) async {
    final uid = SupabaseService.userId;
    if (uid == null) return false;

    final nowIso = DateTime.now().toIso8601String();

    if (courseId != null) {
      // Check direct course subscription (not expired)
      final direct = await _db
          .from('subscriptions')
          .select('id')
          .eq('student_id', uid)
          .eq('course_id', courseId)
          .eq('status', 'active')
          .or('expires_at.is.null,expires_at.gt.$nowIso')
          .maybeSingle();
      if (direct != null) return true;

      // Check via package (not expired)
      final viaPackage = await _db
          .from('subscriptions')
          .select('id, package:package_id(package_courses(course_id))')
          .eq('student_id', uid)
          .eq('status', 'active')
          .or('expires_at.is.null,expires_at.gt.$nowIso')
          .not('package_id', 'is', null);

      for (final sub in (viaPackage as List)) {
        final pkg = (sub as Map)['package'] as Map?;
        final pkgCourses = (pkg?['package_courses'] as List?) ?? [];
        if (pkgCourses.any((pc) => (pc as Map)['course_id'] == courseId)) {
          return true;
        }
      }
      return false;
    }

    if (packageId != null) {
      final data = await _db
          .from('subscriptions')
          .select('id')
          .eq('student_id', uid)
          .eq('package_id', packageId)
          .eq('status', 'active')
          .or('expires_at.is.null,expires_at.gt.$nowIso')
          .maybeSingle();
      return data != null;
    }
    return false;
  }

  static Future<String> createSubscription({
    required String type,
    String? courseId,
    String? packageId,
    required double amount,
    String planType = 'monthly',
    required String localProofPath,
  }) async {
    final uid = SupabaseService.userId!;

    // Prevent duplicate active/pending subscription.
    // .limit(1) before .maybeSingle() avoids a PostgrestException if the student
    // somehow has multiple rows (data-integrity violation / prior bug).
    var dupQ = _db
        .from('subscriptions')
        .select('id, status')
        .eq('student_id', uid)
        .inFilter('status', ['active', 'pending']);
    if (courseId != null) dupQ = dupQ.eq('course_id', courseId);
    if (packageId != null) dupQ = dupQ.eq('package_id', packageId);
    final existing = await dupQ.limit(1).maybeSingle();
    if (existing != null) {
      final s = existing['status'] as String;
      throw Exception(s == 'active'
          ? 'أنت مشترك بالفعل في هذا المحتوى'
          : 'اشتراكك قيد المراجعة حالياً، يرجى الانتظار');
    }

    // Upload proof image
    final ext = localProofPath.contains('.')
        ? localProofPath.split('.').last.toLowerCase()
        : 'jpg';
    final contentType =
        ext == 'png' ? 'image/png' : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
    final fileName =
        '$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';

    final bytes = await File(localProofPath).readAsBytes();
    await SupabaseService.client.storage
        .from('subscription-proofs')
        .uploadBinary(
          fileName,
          bytes,
          fileOptions: FileOptions(contentType: contentType),
        );

    // Create subscription record
    final row = <String, dynamic>{
      'student_id': uid,
      'type': type,
      'status': 'pending',
      'proof_image_url': fileName,
      'amount': amount,
    };
    row['plan_type'] = planType;
    if (courseId != null) row['course_id'] = courseId;
    if (packageId != null) row['package_id'] = packageId;

    final result = await _db
        .from('subscriptions')
        .insert(row)
        .select()
        .single();
    return result['id'] as String;
  }

  // ── Lesson progress ──────────────────────────────────────────────

  static Future<void> markLessonCompleted({
    required String lessonId,
    required String subscriptionId,
  }) async {
    final uid = SupabaseService.userId!;
    await _db.from('lesson_progress').upsert({
      'student_id': uid,
      'lesson_id': lessonId,
      'subscription_id': subscriptionId,
      'completed': true,
      'last_watched': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> rateCourse({
    required String courseId,
    required int rating,
  }) async {
    final uid = SupabaseService.userId!;
    await _db.from('course_ratings').upsert({
      'course_id':  courseId,
      'student_id': uid,
      'rating':     rating,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'course_id,student_id');
  }

  /// Returns true if the student already rated this course WITHIN the current
  /// subscription period (i.e. updated_at >= subscription.started_at).
  /// Falls back to checking any rating when subscriptionId is null.
  static Future<bool> hasRatedInCurrentSubscription({
    required String courseId,
    String? subscriptionId,
  }) async {
    final uid = SupabaseService.userId;
    if (uid == null) return true;

    // Fetch the existing rating
    final rating = await _db
        .from('course_ratings')
        .select('updated_at')
        .eq('course_id', courseId)
        .eq('student_id', uid)
        .maybeSingle();

    if (rating == null) return false; // never rated → show dialog

    if (subscriptionId == null) return true; // rated before, no sub context → skip

    // Check if the rating was submitted after the current subscription started
    final sub = await _db
        .from('subscriptions')
        .select('started_at')
        .eq('id', subscriptionId)
        .maybeSingle();

    final startedAt = sub?['started_at'] as String?;
    if (startedAt == null) return true;

    final ratedAt   = DateTime.tryParse(rating['updated_at'] as String? ?? '');
    final subStart  = DateTime.tryParse(startedAt);
    if (ratedAt == null || subStart == null) return false;

    // If rated AFTER current subscription started → already rated this round
    return ratedAt.isAfter(subStart);
  }
}
