import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/course.dart';
import '../../../core/providers/courses_provider.dart';

class PackageDetailsScreen extends ConsumerWidget {
  final String packageId;
  const PackageDetailsScreen({super.key, required this.packageId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pkgAsync = ref.watch(packageDetailsProvider(packageId));
    final hasSubAsync = ref.watch(hasPackageSubscriptionProvider(packageId));

    return pkgAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: AppColors.background, elevation: 0),
        body: Center(child: Text('تعذّر التحميل: $e')),
      ),
      data: (pkg) {
        final hasSub = hasSubAsync.valueOrNull ?? false;
        return Scaffold(
          backgroundColor: AppColors.background,
          body: CustomScrollView(
            slivers: [
              _buildHeader(context, pkg),
              SliverToBoxAdapter(child: _buildStats(pkg)),
              SliverToBoxAdapter(child: _buildDescription(pkg)),
              SliverToBoxAdapter(child: _buildCoursesList(pkg)),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
          bottomNavigationBar: _buildBottomBar(context, pkg, hasSub),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, CoursePackage pkg) {
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
                    child: const Text('باقة',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
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

  Widget _buildStats(CoursePackage pkg) {
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
          _statItem('${pkg.courses.length}', 'دروس'),
          _divider(),
          _statItem('${pkg.totalLessons}', 'حصة'),
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

  Widget _buildCoursesList(CoursePackage pkg) {
    if (pkg.courses.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: Text('لا توجد دروس في هذه الباقة بعد',
            style: TextStyle(color: AppColors.textHint, fontSize: 13)),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('الدروس المشمولة',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          ...pkg.courses.map((course) => Container(
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
                          Text('${course.totalLessons} درس · ${course.subject}',
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
                      child: Text(course.level,
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, CoursePackage pkg, bool hasSub) {
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
                      '${pkg.originalPrice!.toStringAsFixed(0)} أوقية',
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
                      const Text(' أوقية/شهر',
                          style: TextStyle(fontSize: 10, color: AppColors.textHint)),
                    ],
                  ),
                  if (pkg.priceYearly != null)
                    Text(
                      '${pkg.priceYearly!.toStringAsFixed(0)} أوقية/سنة',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.statusConfirmed, fontWeight: FontWeight.w600),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: hasSub
                    ? Container(
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
                            Text('مشترك',
                                style: TextStyle(color: AppColors.statusConfirmed, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      )
                    : GestureDetector(
                        onTap: () => context.push('/subscribe/package/${pkg.id}',
                            extra: {'priceMonthly': pkg.priceMonthly, 'priceYearly': pkg.priceYearly, 'title': pkg.title}),
                        child: Container(
                          decoration: BoxDecoration(
                            color: pkg.coverColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text('اشترك في الباقة',
                                style: TextStyle(
                                    color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
