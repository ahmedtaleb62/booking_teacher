import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/course.dart';
import '../../../core/providers/courses_provider.dart';

class CourseDetailsScreen extends ConsumerWidget {
  final String courseId;
  const CourseDetailsScreen({super.key, required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courseAsync    = ref.watch(courseDetailsProvider(courseId));
    final subStatusAsync = ref.watch(courseSubStatusProvider(courseId));
    final activeSubAsync = ref.watch(courseActiveSubscriptionProvider(courseId));

    return courseAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: AppColors.background, elevation: 0),
        body: Center(child: Text('تعذّر التحميل: $e')),
      ),
      data: (course) {
        final subStatus    = subStatusAsync.valueOrNull;
        final hasSub       = subStatus == 'active';
        final subscriptionId = activeSubAsync.valueOrNull?.id;
        return Scaffold(
          backgroundColor: AppColors.background,
          body: CustomScrollView(
            slivers: [
              _buildHeader(context, course),
              SliverToBoxAdapter(child: _buildInfo(course)),
              SliverToBoxAdapter(child: _buildLessonsList(context, course, hasSub, subStatus, subscriptionId)),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
          bottomNavigationBar: _buildBottomBar(context, course, subStatus),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, Course course) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: course.coverColor,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                course.coverColor.withValues(alpha: 0.9),
                course.coverColor,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 56, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (course.badge != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: course.badgeBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(course.badge!,
                          style: TextStyle(
                              color: course.badgeFg,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ),
                  Text(course.title,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(course.level,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfo(Course course) {
    final hoursStr = course.totalHours == 0
        ? '—'
        : '${course.totalHours.toStringAsFixed(course.totalHours % 1 == 0 ? 0 : 1)} س';

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Teacher
          if (course.teacherName.isNotEmpty) ...[
            Row(children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: AppColors.accentLight, borderRadius: BorderRadius.circular(9)),
                alignment: Alignment.center,
                child: Text(course.teacherInitial,
                    style: const TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
              const SizedBox(width: 10),
              Text(course.teacherName,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            ]),
            const SizedBox(height: 14),
          ],

          // Stats row 1: lessons, hours, subject
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _statChip(Icons.play_circle_outline_rounded, '${course.totalLessons} درس'),
              _statChip(Icons.schedule_rounded, hoursStr),
              _statChip(Icons.book_outlined, course.subject),
            ],
          ),

          const SizedBox(height: 10),

          // Stats row 2: subscribers + rating
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _statChip(Icons.group_outlined,
                  '${_formatCount(course.subscribersCount)} مشترك'),
              if (course.ratingsCount > 0) ...[
                _statChipColored(
                  Icons.star_rounded,
                  '${course.rating?.toStringAsFixed(1) ?? '—'} (${course.ratingsCount} تقييم)',
                  const Color(0xFFF59E0B),
                ),
              ],
            ],
          ),

          if (course.description != null) ...[
            const SizedBox(height: 14),
            const Divider(color: AppColors.border),
            const SizedBox(height: 12),
            Text(course.description!,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary, height: 1.6)),
          ],
        ],
      ),
    );
  }

  String _formatCount(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  Widget _statChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.textHint),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _statChipColored(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildLessonsList(BuildContext context, Course course, bool hasSub, String? subStatus, String? subscriptionId) {
    // No lessons at all (course not yet built)
    if (course.lessons.isEmpty && course.totalLessons == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('الدروس',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: const Center(
                child: Text('لا توجد دروس متاحة بعد',
                    style: TextStyle(color: AppColors.textHint, fontSize: 13)),
              ),
            ),
          ],
        ),
      );
    }

    // Non-subscriber and no preview lessons available — show locked placeholder
    if (course.lessons.isEmpty && !hasSub && course.totalLessons > 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Text('الدروس',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const Spacer(),
              Text('${course.totalLessons} درس',
                  style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
            ]),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F6F8),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.lock_outline_rounded,
                        size: 28, color: AppColors.textHint),
                  ),
                  const SizedBox(height: 14),
                  Text('${course.totalLessons} درس متاح للمشتركين',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 7),
                  const Text('اشترك الآن للوصول إلى جميع الدروس والمحتوى',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.push('/subscribe/course/${course.id}',
                          extra: {
                            'priceMonthly': course.priceMonthly,
                            'priceYearly': course.priceYearly,
                            'title': course.title,
                          }),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                      ),
                      child: const Text('اشترك الآن',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Group lessons by chapterTitle
    final Map<String, List<CourseLesson>> chapters = {};
    for (final lesson in course.lessons) {
      final ch = lesson.chapterTitle ?? 'الدروس';
      chapters.putIfAbsent(ch, () => []).add(lesson);
    }

    // Global lesson counter for numbering across chapters
    int globalIndex = 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('الدروس',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const Spacer(),
            Text('${course.lessons.length} درس',
                style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
          ]),
          const SizedBox(height: 12),
          ...chapters.entries.map((chapter) {
            final chTitle    = chapter.key;
            final chLessons  = chapter.value;
            final freeCount  = chLessons.where((l) => l.isPreview).length;

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
                boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 3, offset: const Offset(0, 1))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Chapter header
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0E2B33),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(9),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.folder_outlined, color: Colors.white70, size: 17),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(chTitle,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                      Text('${chLessons.length} درس${freeCount > 0 ? ' · $freeCount مجاني' : ''}',
                          style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.6))),
                    ]),
                  ),
                  // Lessons in this chapter
                  ...chLessons.map((lesson) {
                    final idx       = ++globalIndex;
                    final canAccess = hasSub || lesson.isPreview;
                    return Column(
                      children: [
                        const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF0F1F3)),
                        GestureDetector(
                          onTap: canAccess
                              ? () => context.push('/lesson/${lesson.id}',
                                    extra: {'courseId': course.id, 'title': lesson.title, 'videoUrl': lesson.videoUrl, 'subscriptionId': subscriptionId, 'lessonType': lesson.lessonType, 'quizData': lesson.quizData})
                              : () => _showSubscribePrompt(context, course, subStatus),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            child: Row(children: [
                              // Number / icon
                              Container(
                                width: 34, height: 34,
                                decoration: BoxDecoration(
                                  color: lesson.completed
                                      ? AppColors.statusConfirmedBg
                                      : canAccess
                                          ? AppColors.accentLight
                                          : const Color(0xFFF4F6F8),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: lesson.completed
                                    ? const Icon(Icons.check_rounded, color: AppColors.statusConfirmed, size: 17)
                                    : canAccess
                                        ? const Icon(Icons.play_arrow_rounded, color: AppColors.primary, size: 17)
                                        : Text('$idx',
                                            style: const TextStyle(
                                                fontSize: 12, fontWeight: FontWeight.w700,
                                                color: AppColors.textHint)),
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(lesson.title,
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: canAccess ? AppColors.textPrimary : AppColors.textSecondary)),
                                    if (lesson.infoLabel.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(lesson.infoLabel,
                                          style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (lesson.isPreview)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.statusConfirmedBg,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text('مجاني',
                                      style: TextStyle(fontSize: 10, color: AppColors.statusConfirmed, fontWeight: FontWeight.w700)),
                                )
                              else if (!canAccess)
                                const Icon(Icons.lock_outline_rounded, size: 15, color: AppColors.textHint),
                            ]),
                          ),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, Course course, String? subStatus) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 80,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Price column
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (course.originalPrice != null)
                    Text(
                      '${course.originalPrice!.toStringAsFixed(0)} أوقية',
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textHint,
                          decoration: TextDecoration.lineThrough),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(course.priceMonthly.toStringAsFixed(0),
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primary)),
                      const Text(' أوقية/شهر',
                          style: TextStyle(fontSize: 10, color: AppColors.textHint)),
                    ],
                  ),
                  if (course.priceYearly != null)
                    Text(
                      '${course.priceYearly!.toStringAsFixed(0)} أوقية/سنة',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.statusConfirmed, fontWeight: FontWeight.w600),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(child: _subscribeButton(context, course, subStatus)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _subscribeButton(BuildContext context, Course course, String? subStatus) {
    switch (subStatus) {
      case 'active':
        return Container(
          decoration: BoxDecoration(
            color: AppColors.statusConfirmedBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.statusConfirmed.withValues(alpha: 0.3)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle_rounded, color: AppColors.statusConfirmed, size: 18),
              SizedBox(width: 6),
              Text('مشترك', style: TextStyle(color: AppColors.statusConfirmed, fontWeight: FontWeight.w700)),
            ],
          ),
        );
      case 'pending':
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3E2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFC77A1A).withValues(alpha: 0.4)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFC77A1A))),
              SizedBox(width: 8),
              Text('قيد المراجعة',
                  style: TextStyle(color: Color(0xFFC77A1A), fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
        );
      case 'expired':
        return GestureDetector(
          onTap: () => context.push('/subscribe/course/${course.id}',
              extra: {'priceMonthly': course.priceMonthly, 'priceYearly': course.priceYearly, 'title': course.title}),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF8A96A3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('تجديد الاشتراك',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ),
        );
      default: // null or 'rejected'
        return GestureDetector(
          onTap: () => context.push('/subscribe/course/${course.id}',
              extra: {'priceMonthly': course.priceMonthly, 'priceYearly': course.priceYearly, 'title': course.title}),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('اشترك الآن',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        );
    }
  }

  void _showSubscribePrompt(BuildContext context, Course course, String? subStatus) {
    // If pending — just inform, no subscribe button
    if (subStatus == 'pending') {
      showModalBottomSheet(
        context: context,
        builder: (_) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 40, height: 40,
                  child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFFC77A1A))),
              const SizedBox(height: 16),
              const Text('طلب اشتراكك قيد المراجعة',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('سيتم تفعيل اشتراكك خلال 24 ساعة بعد تأكيد الدفع من الإدارة.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.lock_outline_rounded, size: 40, color: AppColors.textHint),
            const SizedBox(height: 12),
            const Text('هذا الدرس للمشتركين فقط',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('اشترك في "${course.title}" للوصول إلى جميع الدروس',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/subscribe/course/${course.id}',
                      extra: {'priceMonthly': course.priceMonthly, 'priceYearly': course.priceYearly, 'title': course.title});
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('اشترك الآن', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
