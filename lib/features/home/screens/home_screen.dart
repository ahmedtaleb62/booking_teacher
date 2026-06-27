import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/levels.dart';
import '../../../core/constants/subjects.dart';
import '../../../core/extensions/l10n_extension.dart';
import '../../../core/models/course.dart';
import '../../../core/models/teacher.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/courses_provider.dart';
import '../../../core/providers/notifications_provider.dart';
import '../../../core/providers/teachers_provider.dart';
import '../../../shared/widgets/teacher_card.dart';
import 'filter_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final profileAsync = ref.watch(currentProfileProvider);
    final userName = profileAsync.when(
      data: (p) => p?['full_name'] as String? ?? l.authStudent,
      loading: () => '',
      error: (_, __) => l.authStudent,
    );

    final subjects = <String?>[null, ...kSubjects];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(context, userName),
            _buildSearch(context),
            _buildTabBar(context),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _TeachersTab(subjects: subjects),
                  _CoursesTab(subjects: subjects),
                  const _PackagesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String userName) {
    final unread    = ref.watch(unreadCountProvider).valueOrNull ?? 0;
    final avatarUrl = ref.watch(currentProfileProvider).valueOrNull?['avatar_url'] as String?;
    final initial   = userName.isNotEmpty ? userName[0] : '؟';
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_greeting(context),
                    style: const TextStyle(fontSize: 13, color: AppColors.textHint)),
                const SizedBox(height: 2),
                Text(userName.isEmpty ? '' : userName,
                    style: const TextStyle(
                        fontSize: 21, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => context.push('/notifications'),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.notifications_outlined,
                      color: AppColors.textSecondary, size: 20),
                ),
                if (unread > 0)
                  Positioned(
                    top: -4, left: -4,
                    child: Container(
                      width: 17, height: 17,
                      decoration: const BoxDecoration(
                          color: AppColors.error, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: Text(
                        unread > 9 ? '9+' : '$unread',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => context.go('/profile'),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                image: avatarUrl != null
                    ? DecorationImage(image: NetworkImage(avatarUrl), fit: BoxFit.cover)
                    : null,
              ),
              alignment: Alignment.center,
              child: avatarUrl == null
                  ? Text(initial,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white))
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.borderStrong),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.textPrimary.withValues(alpha: 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1))
                ],
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) =>
                    ref.read(teacherSearchQueryProvider.notifier).state = v,
                decoration: InputDecoration(
                  hintText: l.homeSearchHint,
                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textHint, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          if (_tabCtrl.index == 0) ...[
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _openFilter,
              child: Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderStrong),
                ),
                child: const Icon(Icons.tune_rounded, color: AppColors.primary, size: 20),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTabBar(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(3),
        child: TabBar(
          controller: _tabCtrl,
          onTap: (_) => setState(() {}),
          indicator: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                  color: AppColors.textPrimary.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 1))
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textHint,
          labelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          unselectedLabelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          tabs: [
            Tab(text: l.homeTeachersTab),
            Tab(text: l.homeCoursesTab),
            Tab(text: l.homePackagesTab),
          ],
        ),
      ),
    );
  }

  void _openFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FilterSheet(),
    );
  }

  String _greeting(BuildContext context) {
    final l = context.l10n;
    final h = DateTime.now().hour;
    if (h < 12) return l.greetingMorning;
    if (h < 17) return l.greetingAfternoon;
    return l.greetingEvening;
  }
}

// ── Teachers Tab ──────────────────────────────────────────────────
class _TeachersTab extends ConsumerWidget {
  final List<String?> subjects;
  const _TeachersTab({required this.subjects});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final teachersAsync    = ref.watch(teachersProvider);
    final selectedSubject  = ref.watch(teacherSubjectFilterProvider);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildSubjectChips(context, ref, selectedSubject)),
        teachersAsync.when(
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (e, _) => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(children: [
                const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textHint),
                const SizedBox(height: 12),
                Text(l.homeLoadError,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => ref.invalidate(teachersProvider),
                  child: Text(l.commonRetry),
                ),
              ]),
            ),
          ),
          data: (teachers) => _buildList(context, teachers, l),
        ),
      ],
    );
  }

  Widget _buildSubjectChips(BuildContext context, WidgetRef ref, String? selectedSubject) {
    final l = context.l10n;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
      child: Row(
        children: subjects.map((s) {
          final isAll    = s == null;
          final selected = isAll ? selectedSubject == null : selectedSubject == s;
          return Padding(
            padding: const EdgeInsets.only(left: 9),
            child: GestureDetector(
              onTap: () =>
                  ref.read(teacherSubjectFilterProvider.notifier).state = isAll ? null : s,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: selected ? AppColors.primary : AppColors.borderStrong),
                ),
                child: Text(
                  isAll ? l.homeAllSubjects : translateSubject(s, Localizations.localeOf(context)),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : AppColors.textPrimary),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<Teacher> teachers, dynamic l) {
    if (teachers.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Center(
            child: Text(context.l10n.homeNoTeachers,
                style: const TextStyle(color: AppColors.textHint, fontSize: 14)),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TeacherCard(
              teacher: teachers[i],
              onTap: () => context.push('/tutor/${teachers[i].id}'),
            ),
          ),
          childCount: teachers.length,
        ),
      ),
    );
  }
}

// ── Courses Tab ───────────────────────────────────────────────────
class _CoursesTab extends ConsumerWidget {
  final List<String?> subjects;
  const _CoursesTab({required this.subjects});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final coursesAsync    = ref.watch(coursesProvider);
    final selectedSubject = ref.watch(courseSubjectFilterProvider);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildSubjectChips(context, ref, selectedSubject)),
        coursesAsync.when(
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 60),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
          error: (e, _) => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textHint),
                const SizedBox(height: 12),
                Text(l.homeLoadError,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                TextButton(
                  onPressed: () => ref.invalidate(coursesProvider),
                  child: Text(l.commonRetry),
                ),
              ]),
            ),
          ),
          data: (courses) {
            if (courses.isEmpty) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: Text(l.homeNoCoursesAvailable,
                        style: const TextStyle(color: AppColors.textHint, fontSize: 14)),
                  ),
                ),
              );
            }
            return SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _CourseCard(course: courses[i]),
                  childCount: courses.length,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSubjectChips(BuildContext context, WidgetRef ref, String? selectedSubject) {
    final l = context.l10n;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
      child: Row(
        children: subjects.map((s) {
          final isAll    = s == null;
          final selected = isAll ? selectedSubject == null : selectedSubject == s;
          return Padding(
            padding: const EdgeInsets.only(left: 9),
            child: GestureDetector(
              onTap: () => ref
                  .read(courseSubjectFilterProvider.notifier)
                  .state = isAll ? null : s,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: selected ? AppColors.primary : AppColors.borderStrong),
                ),
                child: Text(
                  isAll ? l.homeAllSubjects : translateSubject(s, Localizations.localeOf(context)),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : AppColors.textPrimary),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final Course course;
  const _CourseCard({required this.course});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return GestureDetector(
      onTap: () => context.push('/course/${course.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(color: AppColors.shadow, blurRadius: 4, offset: const Offset(0, 1))
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(13)),
              child: Container(
                width: 90, height: 90,
                color: course.coverColor,
                child: Stack(children: [
                  Positioned(
                    bottom: 7, left: 6, right: 6,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(translateLevel(course.level, Localizations.localeOf(context)),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: AppColors.textPrimary, fontSize: 9,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(course.title,
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                      ),
                      if (course.badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: course.badgeBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(course.badge!,
                              style: TextStyle(
                                  color: course.badgeFg, fontSize: 9,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ]),
                    const SizedBox(height: 4),
                    if (course.teacherName.isNotEmpty)
                      Row(children: [
                        Container(
                          width: 18, height: 18,
                          decoration: BoxDecoration(
                            color: AppColors.accentLight,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          alignment: Alignment.center,
                          child: Text(course.teacherInitial,
                              style: const TextStyle(
                                  color: AppColors.primary, fontWeight: FontWeight.w700,
                                  fontSize: 9)),
                        ),
                        const SizedBox(width: 5),
                        Text(course.teacherName,
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ]),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                const Icon(Icons.play_circle_outline_rounded,
                                    size: 11, color: AppColors.textHint),
                                const SizedBox(width: 2),
                                Text(
                                  l.homeLessonCount(course.totalLessons),
                                  style: const TextStyle(fontSize: 10, color: AppColors.textHint),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.schedule_rounded,
                                    size: 11, color: AppColors.textHint),
                                const SizedBox(width: 2),
                                Text(
                                  l.homeHoursAbbrev(course.totalHours.toStringAsFixed(
                                      course.totalHours % 1 == 0 ? 0 : 1)),
                                  style: const TextStyle(fontSize: 10, color: AppColors.textHint),
                                ),
                                if (course.rating != null) ...[
                                  const SizedBox(width: 8),
                                  const Icon(Icons.star_rounded,
                                      size: 11, color: Color(0xFFF59E0B)),
                                  const SizedBox(width: 2),
                                  Text(course.rating!.toStringAsFixed(1),
                                      style: const TextStyle(
                                          fontSize: 10, fontWeight: FontWeight.w700,
                                          color: Color(0xFFF59E0B))),
                                ],
                              ]),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (course.originalPrice != null)
                              Text(
                                l.homeOriginalPrice(course.originalPrice!.toStringAsFixed(0)),
                                style: const TextStyle(
                                    fontSize: 9, color: AppColors.textHint,
                                    decoration: TextDecoration.lineThrough),
                              ),
                            Text(
                              l.homePricePerMonth(course.priceMonthly.toStringAsFixed(0)),
                              style: const TextStyle(
                                  fontSize: 12.5, fontWeight: FontWeight.w700,
                                  color: AppColors.primary),
                            ),
                            if (course.priceYearly != null)
                              Text(
                                l.homePricePerYear(course.priceYearly!.toStringAsFixed(0)),
                                style: const TextStyle(
                                    fontSize: 9.5, color: AppColors.statusConfirmed,
                                    fontWeight: FontWeight.w600),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Packages Tab ──────────────────────────────────────────────────
class _PackagesTab extends ConsumerWidget {
  const _PackagesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final pkgsAsync = ref.watch(packagesProvider);
    return pkgsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textHint),
          const SizedBox(height: 12),
          Text(l.homeLoadError,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          TextButton(
            onPressed: () => ref.invalidate(packagesProvider),
            child: Text(l.commonRetry),
          ),
        ]),
      ),
      data: (packages) {
        if (packages.isEmpty) {
          return Center(
            child: Text(l.homeNoPackagesAvailable,
                style: const TextStyle(color: AppColors.textHint, fontSize: 14)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 100),
          itemCount: packages.length,
          itemBuilder: (_, i) => _PackageCard(package: packages[i]),
        );
      },
    );
  }
}

class _PackageCard extends StatelessWidget {
  final CoursePackage package;
  const _PackageCard({required this.package});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return GestureDetector(
      onTap: () => context.push('/package/${package.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: package.coverColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(package.title,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                      const SizedBox(height: 4),
                      if (package.subjects != null)
                        Text(package.subjects!,
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.8))),
                    ],
                  ),
                ),
                if (package.saveLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(package.saveLabel!,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Container(height: 1, color: Colors.white.withValues(alpha: 0.18)),
            const SizedBox(height: 14),
            Row(
              children: [
                Text('${package.priceMonthly.toStringAsFixed(0)} ',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                Text(l.homeOugiyaPerMonth,
                    style: TextStyle(
                        fontSize: 10, color: Colors.white.withValues(alpha: 0.75))),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(l.homeDetails,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
