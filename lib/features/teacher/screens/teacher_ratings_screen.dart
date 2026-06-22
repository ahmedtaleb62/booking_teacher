import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/l10n_extension.dart';
import '../../../core/services/supabase_service.dart';

// ── Model ────────────────────────────────────────────────────────────────────

class _ReviewItem {
  final String studentName;
  final String? studentAvatar;
  final String? subject;
  final int rating;
  final String? comment;
  final DateTime createdAt;

  const _ReviewItem({
    required this.studentName,
    this.studentAvatar,
    this.subject,
    required this.rating,
    this.comment,
    required this.createdAt,
  });
}

// ── Provider ─────────────────────────────────────────────────────────────────

final _teacherReviewsProvider =
    FutureProvider.autoDispose<List<_ReviewItem>>((ref) async {
  final uid = SupabaseService.userId;
  if (uid == null) return [];

  final data = await SupabaseService.client
      .from('reviews')
      .select('rating, comment, created_at, '
          'student:student_id(full_name, avatar_url), '
          'session:session_id(subject)')
      .eq('teacher_id', uid)
      .order('created_at', ascending: false);

  return (data as List).map((r) {
    final m = Map<String, dynamic>.from(r as Map);
    final student = m['student'] as Map<String, dynamic>? ?? {};
    final session = m['session'] as Map<String, dynamic>? ?? {};

    return _ReviewItem(
      studentName: student['full_name'] as String? ?? '—',
      studentAvatar: student['avatar_url'] as String?,
      subject: session['subject'] as String?,
      rating: (m['rating'] as num?)?.toInt() ?? 0,
      comment: m['comment'] as String?,
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }).toList();
});

// ── Screen ───────────────────────────────────────────────────────────────────

class TeacherRatingsScreen extends ConsumerWidget {
  const TeacherRatingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final reviewsAsync = ref.watch(_teacherReviewsProvider);

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
      body: reviewsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textHint),
              const SizedBox(height: 12),
              Text(l.myRatingsLoadError,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(_teacherReviewsProvider),
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
        data: (items) {
          if (items.isEmpty) return _buildEmpty(l);

          final avg = items.fold<double>(0, (s, r) => s + r.rating) / items.length;

          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => ref.refresh(_teacherReviewsProvider.future),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
              children: [
                _buildSummaryCard(l, avg, items.length),
                const SizedBox(height: 20),
                ...items.map((r) => _ReviewCard(review: r)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(dynamic l, double avg, int count) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: AppColors.shadow, blurRadius: 4, offset: const Offset(0, 1))
        ],
      ),
      child: Row(
        children: [
          Column(
            children: [
              Text(avg.toStringAsFixed(1),
                  style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1)),
              const SizedBox(height: 6),
              Row(
                children: List.generate(5, (i) {
                  if (i < avg.floor()) {
                    return const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 18);
                  } else if (i < avg && avg - i >= 0.5) {
                    return const Icon(Icons.star_half_rounded, color: Color(0xFFF59E0B), size: 18);
                  }
                  return const Icon(Icons.star_outline_rounded,
                      color: AppColors.textMuted, size: 18);
                }),
              ),
              const SizedBox(height: 4),
              Text(l.teacherRatingCount(count),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(child: _RatingBars(avg: avg, count: count)),
        ],
      ),
    );
  }

  Widget _buildEmpty(dynamic l) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
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
          Text(l.teacherRatingsEmptyHint,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ── Rating distribution bars ──────────────────────────────────────────────────

class _RatingBars extends StatelessWidget {
  final double avg;
  final int count;

  const _RatingBars({required this.avg, required this.count});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final star = 5 - i;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Text('$star', style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
              const SizedBox(width: 4),
              const Icon(Icons.star_rounded, size: 11, color: Color(0xFFF59E0B)),
              const SizedBox(width: 6),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: count > 0
                        ? (avg >= star - 0.5 ? 1.0 : 0.0) * (avg / 5)
                        : 0,
                    minHeight: 6,
                    backgroundColor: AppColors.border,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Color(0xFFF59E0B)),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ── Individual review card ────────────────────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  final _ReviewItem review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(color: AppColors.shadow, blurRadius: 4, offset: const Offset(0, 1))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.accentLight,
                backgroundImage: review.studentAvatar != null
                    ? NetworkImage(review.studentAvatar!)
                    : null,
                child: review.studentAvatar == null
                    ? Text(
                        review.studentName.isNotEmpty
                            ? review.studentName[0]
                            : 'ط',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.studentName,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    if (review.subject != null && review.subject!.isNotEmpty)
                      Text(review.subject!,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textHint)),
                  ],
                ),
              ),
              Text(_formatDate(review.createdAt),
                  style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: List.generate(5, (i) {
              return Icon(
                i < review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                color: i < review.rating
                    ? const Color(0xFFF59E0B)
                    : AppColors.textMuted,
                size: 18,
              );
            }),
          ),
          if (review.comment != null && review.comment!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                review.comment!,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
