import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/course.dart';
import '../services/course_service.dart';
import '../services/supabase_service.dart';
import 'auth_provider.dart';

// ── Filter state ──────────────────────────────────────────────────
final courseSubjectFilterProvider  = StateProvider<String?>((ref) => null);
final courseSearchQueryProvider    = StateProvider<String>((ref) => '');
final packageSearchQueryProvider   = StateProvider<String>((ref) => '');

// ── Lists ─────────────────────────────────────────────────────────

final coursesProvider = FutureProvider.autoDispose<List<Course>>((ref) async {
  ref.watch(currentSessionProvider);
  final subject = ref.watch(courseSubjectFilterProvider);
  return CourseService.getCourses(subject: subject);
});

final packagesProvider = FutureProvider.autoDispose<List<CoursePackage>>((ref) async {
  ref.watch(currentSessionProvider);
  return CourseService.getPackages();
});

// ── My subscriptions ─────────────────────────────────────────────

final mySubscriptionsProvider =
    FutureProvider.autoDispose<List<Subscription>>((ref) async {
  ref.watch(currentSessionProvider);
  return CourseService.getMySubscriptions();
});

final subscriptionProvider =
    FutureProvider.autoDispose.family<Subscription?, String>((ref, id) async {
  final subs = await ref.watch(mySubscriptionsProvider.future);
  try {
    return subs.firstWhere((s) => s.id == id);
  } catch (_) {
    return null;
  }
});

// ── Details ───────────────────────────────────────────────────────
// These watch mySubscriptionsProvider so they re-fetch automatically when
// the user's subscription status changes (e.g. admin approves payment).

final courseDetailsProvider =
    FutureProvider.autoDispose.family<Course, String>((ref, id) async {
  ref.watch(mySubscriptionsProvider); // re-fetch lessons when sub status changes
  return CourseService.getCourseDetails(id);
});

final packageDetailsProvider =
    FutureProvider.autoDispose.family<CoursePackage, String>((ref, id) async {
  ref.watch(mySubscriptionsProvider);
  return CourseService.getPackageDetails(id);
});

// ── Has active sub ────────────────────────────────────────────────

// True only if status=active AND not past expires_at
bool _isActiveAndNotExpired(Subscription s) =>
    s.status == SubscriptionStatus.active && !s.isExpired;

final hasCourseSubscriptionProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, courseId) async {
  final subs = await ref.watch(mySubscriptionsProvider.future);
  return subs.any((s) =>
      _isActiveAndNotExpired(s) &&
      (s.courseId == courseId ||
       s.package?.courses.any((c) => c.id == courseId) == true));
});

final hasPackageSubscriptionProvider =
    FutureProvider.autoDispose.family<bool, String>((ref, packageId) async {
  final subs = await ref.watch(mySubscriptionsProvider.future);
  return subs.any((s) =>
      s.packageId == packageId && _isActiveAndNotExpired(s));
});

// Returns the active Subscription for a course (direct or via package)
// — used to pass subscriptionId to lesson player
final courseActiveSubscriptionProvider =
    FutureProvider.autoDispose.family<Subscription?, String>((ref, courseId) async {
  final subs = await ref.watch(mySubscriptionsProvider.future);
  // Prefer direct course subscription
  try {
    return subs.firstWhere((s) =>
        s.courseId == courseId && _isActiveAndNotExpired(s));
  } catch (_) {}
  // Fall back to package subscription that includes this course
  try {
    return subs.firstWhere((s) =>
        _isActiveAndNotExpired(s) &&
        s.package?.courses.any((c) => c.id == courseId) == true);
  } catch (_) {
    return null;
  }
});

// ── Subscription status (active | pending | rejected | expired | null) ──

final courseSubStatusProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, courseId) async {
  final subs = await ref.watch(mySubscriptionsProvider.future);
  // Include direct course subs AND package subs that contain this course
  final relevant = subs.where((s) =>
      s.courseId == courseId ||
      (s.packageId != null &&
       s.package?.courses.any((c) => c.id == courseId) == true)).toList();
  if (relevant.isEmpty) return null;
  // DB may still say 'active' after expiry if cron hasn't run — treat as expired
  if (relevant.any(_isActiveAndNotExpired)) return 'active';
  if (relevant.any((s) => s.status == SubscriptionStatus.pending)) return 'pending';
  if (relevant.any((s) =>
      s.status == SubscriptionStatus.expired ||
      (s.status == SubscriptionStatus.active && s.isExpired))) return 'expired';
  return 'rejected';
});

final packageSubStatusProvider =
    FutureProvider.autoDispose.family<String?, String>((ref, packageId) async {
  final subs = await ref.watch(mySubscriptionsProvider.future);
  final pkgSubs = subs.where((s) => s.packageId == packageId).toList();
  if (pkgSubs.isEmpty) return null;
  if (pkgSubs.any(_isActiveAndNotExpired)) return 'active';
  if (pkgSubs.any((s) => s.status == SubscriptionStatus.pending)) return 'pending';
  if (pkgSubs.any((s) =>
      s.status == SubscriptionStatus.expired ||
      (s.status == SubscriptionStatus.active && s.isExpired))) return 'expired';
  return 'rejected';
});

// ── Subscriptions realtime ────────────────────────────────────────────────────
// Watches the subscriptions table for the current student and invalidates all
// subscription-derived providers whenever a row changes (admin approve/reject).
// Anchor this in MainShell so it stays alive on all student tabs.
final subscriptionsRealtimeProvider = Provider.autoDispose<void>((ref) {
  final uid = SupabaseService.userId;
  if (uid == null) return;

  final channel = SupabaseService.client
      .channel('rt-subscriptions-$uid')
      .onPostgresChanges(
        event:  PostgresChangeEvent.all,
        schema: 'public',
        table:  'subscriptions',
        filter: PostgresChangeFilter(
          type:   PostgresChangeFilterType.eq,
          column: 'student_id',
          value:  uid,
        ),
        callback: (_) => ref.invalidate(mySubscriptionsProvider),
      )
      .subscribe();

  ref.onDispose(() => SupabaseService.client.removeChannel(channel));
});
