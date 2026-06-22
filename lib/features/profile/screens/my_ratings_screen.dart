import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/l10n_extension.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/supabase_service.dart';

// ── Model ─────────────────────────────────────────────────────────

class _RatingItem {
  final String id;
  final String courseId;
  final String courseTitle;
  final String subject;
  final int coverColorValue;
  final int rating;
  final DateTime createdAt;

  const _RatingItem({
    required this.id,
    required this.courseId,
    required this.courseTitle,
    required this.subject,
    required this.coverColorValue,
    required this.rating,
    required this.createdAt,
  });
}

// ── Provider ──────────────────────────────────────────────────────

final _myRatingsProvider =
    FutureProvider.autoDispose<List<_RatingItem>>((ref) async {
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
    final colorVal =
        int.tryParse('FF$hexStr', radix: 16) ?? 0xFF1B6B7A;

    return _RatingItem(
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

// ── Screen ────────────────────────────────────────────────────────

class MyRatingsScreen extends ConsumerWidget {
  const MyRatingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final ratingsAsync = ref.watch(_myRatingsProvider);

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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: ratingsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textHint),
              const SizedBox(height: 12),
              Text(l.myRatingsLoadError,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(_myRatingsProvider),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: Text(l.commonRetry),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        data: (items) => items.isEmpty
            ? _buildEmpty(context, l)
            : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: () => ref.refresh(_myRatingsProvider.future),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
                  itemCount: items.length,
                  itemBuilder: (_, i) => _buildCard(context, items[i]),
                ),
              ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, _RatingItem item) {
    final courseColor = Color(item.coverColorValue);
    return GestureDetector(
      onTap: () => context.push('/course/${item.courseId}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(color: AppColors.shadow, blurRadius: 4, offset: const Offset(0, 1))
          ],
        ),
        child: Column(
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: courseColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
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
                    child: Icon(Icons.play_circle_outline_rounded,
                        color: courseColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.courseTitle,
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 3),
                        Text(item.subject,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textHint)),
                        const SizedBox(height: 10),
                        Row(
                          children: List.generate(5, (si) {
                            return Icon(
                              si < item.rating
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: si < item.rating
                                  ? const Color(0xFFF59E0B)
                                  : AppColors.textMuted,
                              size: 20,
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                  Text(_formatDate(item.createdAt),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textHint)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, dynamic l) {
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
            child: const Icon(Icons.star_outline_rounded,
                size: 34, color: Color(0xFFF59E0B)),
          ),
          const SizedBox(height: 16),
          Text(l.myRatingsEmpty,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text(l.myRatingsEmptyHint,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/my-courses'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text(l.subPendingViewCourses,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
