import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/teacher.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/teachers_provider.dart';
import '../../../shared/widgets/teacher_card.dart';
import 'filter_sheet.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchCtrl = TextEditingController();

  static const _subjects = ['الكل', 'رياضيات', 'فيزياء', 'عربية', 'إنجليزية', 'علوم', 'أحياء'];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teachersAsync = ref.watch(teachersProvider);
    final profileAsync  = ref.watch(currentProfileProvider);
    final selectedSubject = ref.watch(teacherSubjectFilterProvider);
    final query = ref.watch(teacherSearchQueryProvider);

    final userName = profileAsync.when(
      data: (p) => p?['full_name'] as String? ?? 'طالب',
      loading: () => '',
      error: (_, __) => 'طالب',
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(userName)),
            SliverToBoxAdapter(child: _buildSearch(query)),
            SliverToBoxAdapter(child: _buildSubjectChips(selectedSubject)),
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
                  child: Column(
                    children: [
                      const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textHint),
                      const SizedBox(height: 12),
                      Text('تعذّر التحميل: $e',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => ref.invalidate(teachersProvider),
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (teachers) => _buildList(teachers),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<Teacher> teachers) {
    if (teachers.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 60),
          child: Center(
            child: Text('لا يوجد أساتذة متاحون حالياً',
              style: TextStyle(color: AppColors.textHint, fontSize: 14)),
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

  Widget _buildHeader(String userName) {
    final greeting = _greeting();
    final initial = userName.isNotEmpty ? userName[0] : '؟';
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greeting,
                  style: const TextStyle(fontSize: 13, color: AppColors.textHint)),
                const SizedBox(height: 2),
                Text(userName.isEmpty ? '' : '$userName 👋',
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ],
            ),
          ),
          Container(
            width: 46, height: 46,
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(initial,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch(String currentQuery) {
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
                boxShadow: [BoxShadow(color: AppColors.textPrimary.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 1))],
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => ref.read(teacherSearchQueryProvider.notifier).state = v,
                decoration: const InputDecoration(
                  hintText: 'ابحث عن أستاذ أو مادة…',
                  prefixIcon: Icon(Icons.search_rounded, color: AppColors.textHint, size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
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
      ),
    );
  }

  Widget _buildSubjectChips(String? selectedSubject) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 14),
      child: Row(
        children: _subjects.map((s) {
          final isAll = s == 'الكل';
          final selected = isAll ? selectedSubject == null : selectedSubject == s;
          return Padding(
            padding: const EdgeInsets.only(left: 9),
            child: GestureDetector(
              onTap: () => ref.read(teacherSubjectFilterProvider.notifier).state =
                  isAll ? null : s,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: selected ? AppColors.primary : AppColors.borderStrong),
                ),
                child: Text(s,
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppColors.textPrimary,
                  )),
              ),
            ),
          );
        }).toList(),
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

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'صباح الخير،';
    if (h < 17) return 'مساء الخير،';
    return 'مساء النور،';
  }
}
