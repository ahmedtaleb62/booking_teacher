import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/subjects.dart';
import '../../../core/extensions/l10n_extension.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/utils/app_errors.dart';

// ── Models ────────────────────────────────────────────────────────────────────

class _CourseRatingItem {
  final String id;
  final String courseId;
  final String courseTitle;
  final String subject;
  final int coverColorValue;
  final int rating;
  final DateTime createdAt;

  const _CourseRatingItem({
    required this.id,
    required this.courseId,
    required this.courseTitle,
    required this.subject,
    required this.coverColorValue,
    required this.rating,
    required this.createdAt,
  });
}

class _TeacherRatingItem {
  final String teacherName;
  final String? teacherAvatar;
  final String? subject;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  const _TeacherRatingItem({
    required this.teacherName,
    this.teacherAvatar,
    this.subject,
    required this.rating,
    this.comment,
    required this.createdAt,
  });
}

// ── Providers ─────────────────────────────────────────────────────────────────

final _myCourseRatingsProvider =
    FutureProvider.autoDispose<List<_CourseRatingItem>>((ref) async {
  ref.watch(currentSessionProvider);
  final uid = SupabaseService.userId;
  if (uid == null) return [];

  final data = await SupabaseService.client
      .from('course_ratings')
      .select('*, course:course_id(id, title, subject, cover_color)')
      .eq('student_id', uid)
      .order('created_at', ascending: false);

  return (data as List).map((r) {
    final m = Map<String, dynamic>.from(r as Map);
    final course = m['course'] as Map<String, dynamic>? ?? {};
    final hexStr = (course['cover_color'] as String? ?? '1B6B7A')
        .replaceAll('#', '');
    final colorVal = int.tryParse('FF$hexStr', radix: 16) ?? 0xFF1B6B7A;

    return _CourseRatingItem(
      id: m['id'] as String,
      courseId: course['id'] as String? ?? '',
      courseTitle: course['title'] as String? ?? '—',
      subject: course['subject'] as String? ?? '',
      coverColorValue: colorVal,
      rating: (m['rating'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }).toList();
});

final _myTeacherRatingsProvider =
    FutureProvider.autoDispose<List<_TeacherRatingItem>>((ref) async {
  ref.watch(currentSessionProvider);
  final uid = SupabaseService.userId;
  if (uid == null) return [];

  final data = await SupabaseService.client
      .from('reviews')
      .select('rating, comment, created_at, '
          'teacher:teacher_id(full_name, avatar_url)')
      .eq('student_id', uid)
      .order('created_at', ascending: false);

  return (data as List).map((r) {
    final m = Map<String, dynamic>.from(r as Map);
    final teacher = m['teacher'] as Map<String, dynamic>? ?? {};

    return _TeacherRatingItem(
      teacherName: teacher['full_name'] as String? ?? '—',
      teacherAvatar: teacher['avatar_url'] as String?,
      subject: null,
      rating: (m['rating'] as num?)?.toInt() ?? 0,
      comment: m['comment'] as String?,
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }).toList();
});

// ── Screen ────────────────────────────────────────────────────────────────────

class MyRatingsScreen extends ConsumerStatefulWidget {
  const MyRatingsScreen({super.key});

  @override
  ConsumerState<MyRatingsScreen> createState() => _MyRatingsScreenState();
}

class _MyRatingsScreenState extends ConsumerState<MyRatingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: GestureDetector(
          onTap: () => context.pop(),
          child: const Icon(Icons.arrow_forward_rounded, color: AppColors.textPrimary),
        ),
        title: Text(l.profileMyRatings,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textHint,
          indicatorColor: AppColors.primary,
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'تقييمات الأساتذة'),
            Tab(text: 'تقييمات الدورات'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _TeacherRatingsTab(),
          _CourseRatingsTab(),
        ],
      ),
    );
  }
}

// ── Teacher ratings tab ───────────────────────────────────────────────────────

class _TeacherRatingsTab extends ConsumerWidget {
  const _TeacherRatingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return ref.watch(_myTeacherRatingsProvider).when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => _ErrorView(
        error: AppErrors.friendly(e, l),
        onRetry: () => ref.invalidate(_myTeacherRatingsProvider),
      ),
      data: (items) => items.isEmpty
          ? _EmptyView(
              icon: Icons.person_outline_rounded,
              message: 'لم تقيّم أي أستاذ بعد',
              hint: 'تقييماتك للأساتذة بعد انتهاء الجلسات ستظهر هنا',
            )
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => ref.refresh(_myTeacherRatingsProvider.future),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
                itemCount: items.length,
                itemBuilder: (_, i) => _TeacherRatingCard(item: items[i]),
              ),
            ),
    );
  }
}

class _TeacherRatingCard extends StatelessWidget {
  final _TeacherRatingItem item;
  const _TeacherRatingCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              backgroundImage: item.teacherAvatar != null
                  ? NetworkImage(item.teacherAvatar!)
                  : null,
              child: item.teacherAvatar == null
                  ? Text(
                      item.teacherName.isNotEmpty ? item.teacherName[0] : '؟',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(item.teacherName,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                      ),
                      Text(_fmtDate(item.createdAt),
                          style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                    ],
                  ),
                  if (item.subject != null && item.subject!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(translateSubject(item.subject!, locale),
                        style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(5, (si) => Icon(
                      si < item.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: si < item.rating ? const Color(0xFFF59E0B) : AppColors.textMuted,
                      size: 19,
                    )),
                  ),
                  if (item.comment != null && item.comment!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(item.comment!,
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime dt) => '${dt.day}/${dt.month}/${dt.year}';
}

// ── Course ratings tab ────────────────────────────────────────────────────────

class _CourseRatingsTab extends ConsumerWidget {
  const _CourseRatingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return ref.watch(_myCourseRatingsProvider).when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => _ErrorView(
        error: AppErrors.friendly(e, l),
        onRetry: () => ref.invalidate(_myCourseRatingsProvider),
      ),
      data: (items) => items.isEmpty
          ? _EmptyView(
              icon: Icons.menu_book_outlined,
              message: l.myRatingsEmpty,
              hint: l.myRatingsEmptyHint,
              actionLabel: l.subPendingViewCourses,
              onAction: () => context.go('/my-courses'),
            )
          : RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => ref.refresh(_myCourseRatingsProvider.future),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
                itemCount: items.length,
                itemBuilder: (_, i) => _CourseRatingCard(item: items[i]),
              ),
            ),
    );
  }
}

class _CourseRatingCard extends StatelessWidget {
  final _CourseRatingItem item;
  const _CourseRatingCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final courseColor = Color(item.coverColorValue);
    return GestureDetector(
      onTap: () => context.push('/course/${item.courseId}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 4, offset: const Offset(0, 1))],
        ),
        child: Column(
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: courseColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: courseColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.play_circle_outline_rounded, color: courseColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.courseTitle,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Text(translateSubject(item.subject, Localizations.localeOf(context)),
                            style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
                        const SizedBox(height: 10),
                        Row(
                          children: List.generate(5, (si) => Icon(
                            si < item.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                            color: si < item.rating ? const Color(0xFFF59E0B) : AppColors.textMuted,
                            size: 20,
                          )),
                        ),
                      ],
                    ),
                  ),
                  Text('${item.createdAt.day}/${item.createdAt.month}/${item.createdAt.year}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text(l.myRatingsLoadError,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(error,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(l.commonRetry),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final IconData icon;
  final String message;
  final String hint;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyView({
    required this.icon,
    required this.message,
    required this.hint,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(20),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 34, color: const Color(0xFFF59E0B)),
          ),
          const SizedBox(height: 16),
          Text(message,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(hint,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(actionLabel!, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }
}
