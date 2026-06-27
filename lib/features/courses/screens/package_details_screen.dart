import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/levels.dart';
import '../../../core/constants/subjects.dart';
import '../../../core/extensions/l10n_extension.dart';
import '../../../core/models/course.dart';
import '../../../core/providers/courses_provider.dart';

class PackageDetailsScreen extends ConsumerWidget {
  final String packageId;
  const PackageDetailsScreen({super.key, required this.packageId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final pkgAsync = ref.watch(packageDetailsProvider(packageId));
    final subStatusAsync = ref.watch(packageSubStatusProvider(packageId));

    return pkgAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: AppColors.background, elevation: 0),
        body: Center(child: Text('${l.commonErrorLoading}: $e')),
      ),
      data: (pkg) {
        final subStatus = subStatusAsync.valueOrNull;
        return Scaffold(
          backgroundColor: AppColors.background,
          body: CustomScrollView(
            slivers: [
              _buildHeader(context, pkg),
              SliverToBoxAdapter(child: _buildStats(context, pkg)),
              SliverToBoxAdapter(child: _buildDescription(pkg)),
              SliverToBoxAdapter(child: _buildCoursesList(context, pkg)),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
          bottomNavigationBar: _buildBottomBar(context, pkg, subStatus),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, CoursePackage pkg) {
    final l = context.l10n;
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: pkg.coverColor,
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
          color: pkg.coverColor,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 56, 22, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(l.packageTypeLabel,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 10),
                  Text(pkg.title,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                  if (pkg.subjects != null) ...[
                    const SizedBox(height: 6),
                    Text(pkg.subjects!,
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8), fontSize: 13)),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStats(BuildContext context, CoursePackage pkg) {
    final l = context.l10n;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 4, offset: const Offset(0, 1))],
      ),
      child: Row(
        children: [
          _statItem('${pkg.courses.length}', l.packageCoursesStatLabel),
          _divider(),
          _statItem('${pkg.totalLessons}', l.packageLessonsStatLabel),
          _divider(),
          if (pkg.saveLabel != null)
            _statItem(pkg.saveLabel!, '', highlight: true),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label, {bool highlight = false}) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: highlight ? AppColors.primary : AppColors.textPrimary)),
          if (label.isNotEmpty)
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(width: 1, height: 36, color: AppColors.border,
        margin: const EdgeInsets.symmetric(horizontal: 8));
  }

  Widget _buildDescription(CoursePackage pkg) {
    if (pkg.description == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(pkg.description!,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.6)),
    );
  }

  Widget _buildCoursesList(BuildContext context, CoursePackage pkg) {
    final l = context.l10n;
    if (pkg.courses.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(l.packageNoCourses,
            style: const TextStyle(color: AppColors.textHint, fontSize: 13)),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.packageCoursesTitle,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          ...pkg.courses.map((course) => GestureDetector(
                onTap: () => context.push('/course/${course.id}'),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: course.coverColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Icon(Icons.play_circle_outline_rounded,
                            color: course.coverColor, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(course.title,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                            const SizedBox(height: 3),
                            Text('${l.homeLessonCount(course.totalLessons)} · ${translateSubject(course.subject, Localizations.localeOf(context))}',
                                style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.accentLight,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(translateLevel(course.level, Localizations.localeOf(context)),
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 13, color: AppColors.textHint),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, CoursePackage pkg, String? subStatus) {
    final l = context.l10n;
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pkg.originalPrice != null)
                    Text(
                      l.homeOriginalPrice(pkg.originalPrice!.toStringAsFixed(0)),
                      style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textHint,
                          decoration: TextDecoration.lineThrough),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(pkg.priceMonthly.toStringAsFixed(0),
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.primary)),
                      Text(' ${l.homeOugiyaPerMonth}',
                          style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
                    ],
                  ),
                  if (pkg.priceYearly != null)
                    Text(
                      l.coursePriceYearly(pkg.priceYearly!.toStringAsFixed(0)),
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.statusConfirmed, fontWeight: FontWeight.w600),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(child: _subscribeButton(context, pkg, subStatus, l)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _subscribeButton(BuildContext context, CoursePackage pkg, String? subStatus, dynamic l) {
    if (subStatus == 'active') {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.statusConfirmedBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.statusConfirmed.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.statusConfirmed, size: 18),
            const SizedBox(width: 6),
            Text(l.courseSubscribedLabel,
                style: const TextStyle(color: AppColors.statusConfirmed, fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }

    if (subStatus == 'pending') {
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF3F0FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.3)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.hourglass_top_rounded, color: Color(0xFF7C3AED), size: 18),
            SizedBox(width: 6),
            Text('قيد المراجعة',
                style: TextStyle(color: Color(0xFF7C3AED), fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }

    if (subStatus == 'expired') {
      return GestureDetector(
        onTap: () => context.push('/subscribe/package/${pkg.id}',
            extra: {'priceMonthly': pkg.priceMonthly, 'priceYearly': pkg.priceYearly, 'title': pkg.title}),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.4)),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.refresh_rounded, color: Color(0xFFD97706), size: 18),
              SizedBox(width: 6),
              Text('تجديد الاشتراك',
                  style: TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );
    }

    if (subStatus == 'rejected') {
      return GestureDetector(
        onTap: () => context.push('/subscribe/package/${pkg.id}',
            extra: {'priceMonthly': pkg.priceMonthly, 'priceYearly': pkg.priceYearly, 'title': pkg.title}),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
          ),
          child: Builder(builder: (context) {
            final l = context.l10n;
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.replay_rounded, color: AppColors.error, size: 18),
                const SizedBox(width: 6),
                Text(l.commonRetry,
                    style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w700)),
              ],
            );
          }),
        ),
      );
    }

    // null — no subscription yet
    return GestureDetector(
      onTap: () => context.push('/subscribe/package/${pkg.id}',
          extra: {'priceMonthly': pkg.priceMonthly, 'priceYearly': pkg.priceYearly, 'title': pkg.title}),
      child: Container(
        decoration: BoxDecoration(
          color: pkg.coverColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(l.packageSubscribeBtn,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
        ),
      ),
    );
  }
}
