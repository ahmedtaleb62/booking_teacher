import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/subjects.dart';
import '../../../core/extensions/l10n_extension.dart';
import '../../../core/models/teacher.dart';
import '../../../core/providers/teachers_provider.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/app_button.dart';

// ── Reviews provider (per teacher) ───────────────────────────────────────────

class _ReviewItem {
  final String studentName;
  final String? studentAvatar;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  const _ReviewItem({
    required this.studentName,
    this.studentAvatar,
    required this.rating,
    this.comment,
    required this.createdAt,
  });
}

final _teacherPublicReviewsProvider =
    FutureProvider.autoDispose.family<List<_ReviewItem>, String>((ref, teacherId) async {
  final data = await SupabaseService.client
      .from('reviews')
      .select('rating, comment, created_at, student:student_id(full_name, avatar_url)')
      .eq('teacher_id', teacherId)
      .order('created_at', ascending: false)
      .limit(10);

  return (data as List).map((r) {
    final m = Map<String, dynamic>.from(r as Map);
    final student = m['student'] as Map<String, dynamic>? ?? {};
    return _ReviewItem(
      studentName: student['full_name'] as String? ?? '—',
      studentAvatar: student['avatar_url'] as String?,
      rating: (m['rating'] as num?)?.toInt() ?? 0,
      comment: m['comment'] as String?,
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }).toList();
});

// ── Screen ────────────────────────────────────────────────────────────────────

class TeacherProfileScreen extends ConsumerWidget {
  final String teacherId;
  const TeacherProfileScreen({super.key, required this.teacherId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final teacherAsync = ref.watch(teacherProvider(teacherId));
    final teacher = teacherAsync.valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: teacherAsync.when(
        loading: () => _buildLoadingBody(context),
        error: (_, __) => _buildErrorBody(context, ref, l),
        data: (t) {
          if (t == null) return _buildNotFoundBody(context, l);
          return _TeacherProfileBody(teacher: t);
        },
      ),
      bottomNavigationBar: teacher != null
          ? _TeacherProfileBody.buildCTA(context, teacher)
          : null,
    );
  }

  Widget _buildLoadingBody(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 200,
          backgroundColor: AppColors.primaryDark,
          leading: Padding(
            padding: const EdgeInsets.all(8),
            child: GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
              ),
            ),
          ),
          flexibleSpace: const FlexibleSpaceBar(
            background: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primary, AppColors.primaryDark],
                ),
              ),
            ),
          ),
        ),
        const SliverFillRemaining(
          child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
        ),
      ],
    );
  }

  Widget _buildErrorBody(BuildContext context, WidgetRef ref, dynamic l) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: AppColors.primaryDark,
          leading: Padding(
            padding: const EdgeInsets.all(8),
            child: GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
              ),
            ),
          ),
        ),
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textHint),
                const SizedBox(height: 12),
                Text(l.reqSessionErrLoadTeacher),
                TextButton(
                  onPressed: () => ref.invalidate(teacherProvider(teacherId)),
                  child: Text(l.commonRetry),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNotFoundBody(BuildContext context, dynamic l) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          backgroundColor: AppColors.primaryDark,
          leading: Padding(
            padding: const EdgeInsets.all(8),
            child: GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
              ),
            ),
          ),
        ),
        SliverFillRemaining(
          child: Center(child: Text(l.reqSessionTeacherNotFound)),
        ),
      ],
    );
  }
}

class _TeacherProfileBody extends StatelessWidget {
  final Teacher teacher;
  const _TeacherProfileBody({required this.teacher});

  static Widget buildCTA(BuildContext context, Teacher t) {
    final l = context.l10n;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.fromLTRB(
          22, 14, 22, MediaQuery.of(context).padding.bottom + 14),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('${t.pricePerHour.toInt()}',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
              Text(l.unitOugiyaPerHour,
                style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: AppButton(
              label: l.reqSessionTitle,
              onTap: () => context.push('/request-session/${t.id}'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = teacher;
    return CustomScrollView(
      slivers: [
        _buildHeader(context, t),
        SliverToBoxAdapter(child: _buildBody(context, t)),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, Teacher t) {
    final l = context.l10n;
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: AppColors.primaryDark,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: GestureDetector(
          onTap: () => context.pop(),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.primaryDark],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 56, 22, 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _TeacherAvatar(initial: t.initial, size: 78, avatarUrl: t.avatarUrl),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(t.name,
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                            ),
                            if (t.isVerified) ...[
                              const SizedBox(width: 7),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(l.teacherVerifiedBadge,
                                  style: const TextStyle(
                                      fontSize: 9, fontWeight: FontWeight.w700,
                                      color: AppColors.primaryDark)),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${translateSubject(t.subject, Localizations.localeOf(context))} · ${l.teacherYearsExpBadge(t.yearsExperience)}',
                          style: const TextStyle(
                              fontSize: 13, color: Color(0xFFCFE6EA))),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded,
                                color: Colors.amber, size: 14),
                            const SizedBox(width: 3),
                            Text('${t.rating}',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                            Text(' · ${l.teacherRatingCount(t.reviewCount)}',
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFF9DB2B8))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, Teacher t) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatCard(value: '${t.pricePerHour.toInt()}', sub: l.unitOugiyaPerHour),
              const SizedBox(width: 10),
              _StatCard(value: '${t.totalSessions}+', sub: l.teacherStatSessions),
              const SizedBox(width: 10),
              _StatCard(
                value: '${t.attendanceRate.toInt()}%',
                sub: l.teacherStatAttendance,
                valueColor: AppColors.statusActive),
            ],
          ),
          const SizedBox(height: 20),

          if (t.bio.isNotEmpty) ...[
            Text(l.teacherBioLabel,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
            const SizedBox(height: 7),
            Text(t.bio,
              style: const TextStyle(
                  fontSize: 13, height: 1.7, color: AppColors.textSecondary)),
            const SizedBox(height: 20),
          ],

          Text(l.teacherSubjectsTitle,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: t.subjects.map((s) => _Chip(label: translateSubject(s, Localizations.localeOf(context)))).toList(),
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l.teacherAvailToday,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
              GestureDetector(
                onTap: () {},
                child: Text(l.teacherAvailViewWeek,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 9),
          t.availableSlots.isEmpty
              ? Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Center(
                    child: Text(l.teacherNoSlotsToday,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textHint)),
                  ),
                )
              : Row(
                  children: t.availableSlots.take(3).map((slot) {
                    final isBooked = slot.isBooked;
                    final hour   = slot.dateTime.hour;
                    final minute = slot.dateTime.minute;
                    final period = hour >= 12 ? l.timePmAbbrev : l.timeAmAbbrev;
                    final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
                    final timeStr = '$h:${minute.toString().padLeft(2, '0')} $period';
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: isBooked
                                ? AppColors.surfaceAlt
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                              color: isBooked
                                  ? AppColors.border
                                  : AppColors.primary,
                              width: isBooked ? 1 : 1.5,
                            ),
                          ),
                          child: Text(timeStr,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700,
                              color: isBooked
                                  ? AppColors.textMuted
                                  : AppColors.primary,
                              decoration: isBooked
                                  ? TextDecoration.lineThrough
                                  : null,
                            )),
                        ),
                      ),
                    );
                  }).toList(),
                ),
          const SizedBox(height: 20),
          _TeacherReviewsSection(
              teacherId: t.id, reviewCount: t.reviewCount),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── Student-visible reviews section ──────────────────────────────────────────

class _TeacherReviewsSection extends ConsumerWidget {
  final String teacherId;
  final int reviewCount;
  const _TeacherReviewsSection(
      {required this.teacherId, required this.reviewCount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (reviewCount == 0) return const SizedBox.shrink();
    final l = context.l10n;
    final reviewsAsync = ref.watch(_teacherPublicReviewsProvider(teacherId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.teacherPublicReviews(reviewCount),
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w700,
              color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        reviewsAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2))),
          error: (_, __) => const SizedBox.shrink(),
          data: (items) => Column(
            children:
                items.map((r) => _PublicReviewCard(review: r)).toList(),
          ),
        ),
      ],
    );
  }
}

class _PublicReviewCard extends StatelessWidget {
  final _ReviewItem review;
  const _PublicReviewCard({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 17,
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
                            fontSize: 13, fontWeight: FontWeight.w700,
                            color: AppColors.primary))
                    : null,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(review.studentName,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              ),
              Text('${review.createdAt.day}/${review.createdAt.month}/${review.createdAt.year}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(
              5,
              (i) => Icon(
                i < review.rating
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                color: i < review.rating
                    ? const Color(0xFFF59E0B)
                    : AppColors.textMuted,
                size: 15,
              ),
            ),
          ),
          if (review.comment != null &&
              review.comment!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(review.comment!,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary,
                  height: 1.6)),
          ],
        ],
      ),
    );
  }
}

class _TeacherAvatar extends StatelessWidget {
  final String initial;
  final double size;
  final String? avatarUrl;
  const _TeacherAvatar({required this.initial, required this.size, this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.25),
        image: avatarUrl != null
            ? DecorationImage(image: NetworkImage(avatarUrl!), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: avatarUrl == null
          ? Text(initial,
              style: TextStyle(
                  fontSize: size * 0.38,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary))
          : null,
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String sub;
  final Color? valueColor;
  const _StatCard({required this.value, required this.sub, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(value,
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700,
                  color: valueColor ?? AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(sub,
              style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  const _Chip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label,
        style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: AppColors.primary)),
    );
  }
}
