import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/teacher.dart';
import '../../../core/providers/teachers_provider.dart';
import '../../../shared/widgets/app_button.dart';

class TeacherProfileScreen extends ConsumerWidget {
  final String teacherId;
  const TeacherProfileScreen({super.key, required this.teacherId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teacherAsync = ref.watch(teacherProvider(teacherId));

    return teacherAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: () => context.pop())),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textHint),
              const SizedBox(height: 12),
              const Text('تعذّر تحميل بيانات الأستاذ'),
              TextButton(
                onPressed: () => ref.invalidate(teacherProvider(teacherId)),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      ),
      data: (teacher) {
        if (teacher == null) {
          return Scaffold(
            appBar: AppBar(leading: BackButton(onPressed: () => context.pop())),
            body: const Center(child: Text('الأستاذ غير موجود')),
          );
        }
        return _TeacherProfileView(teacher: teacher);
      },
    );
  }
}

class _TeacherProfileView extends StatelessWidget {
  final Teacher teacher;
  const _TeacherProfileView({required this.teacher});

  @override
  Widget build(BuildContext context) {
    final t = teacher;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildHeader(context, t),
          SliverToBoxAdapter(child: _buildBody(context, t)),
        ],
      ),
      bottomNavigationBar: _buildCTA(context, t),
    );
  }

  Widget _buildHeader(BuildContext context, Teacher t) {
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
                  _TeacherAvatar(initial: t.initial, size: 78),
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
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                            ),
                            if (t.isVerified) ...[
                              const SizedBox(width: 7),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('موثّق',
                                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppColors.primaryDark)),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('${t.subject} · ${t.yearsExperience} سنوات خبرة',
                          style: const TextStyle(fontSize: 13, color: Color(0xFFCFE6EA))),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                            const SizedBox(width: 3),
                            Text('${t.rating}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                            Text(' · ${t.reviewCount} تقييم',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF9DB2B8))),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatCard(value: '${t.pricePerHour.toInt()}', sub: 'أوقية/ساعة'),
              const SizedBox(width: 10),
              _StatCard(value: '${t.totalSessions}+', sub: 'جلسة مكتملة'),
              const SizedBox(width: 10),
              _StatCard(value: '${t.attendanceRate.toInt()}%', sub: 'نسبة الحضور',
                  valueColor: AppColors.statusActive),
            ],
          ),
          const SizedBox(height: 20),

          if (t.bio.isNotEmpty) ...[
            const Text('نبذة',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 7),
            Text(t.bio,
              style: const TextStyle(fontSize: 13, height: 1.7, color: AppColors.textSecondary)),
            const SizedBox(height: 20),
          ],

          const Text('المواد',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: t.subjects.map((s) => _Chip(label: s)).toList(),
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('الأوقات المتاحة · اليوم',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              GestureDetector(
                onTap: () {},
                child: const Text('عرض الأسبوع',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
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
                  child: const Center(
                    child: Text('لا توجد أوقات متاحة اليوم',
                      style: TextStyle(fontSize: 13, color: AppColors.textHint)),
                  ),
                )
              : Row(
                  children: t.availableSlots.take(3).map((slot) {
                    final isBooked = slot.isBooked;
                    final hour = slot.dateTime.hour;
                    final minute = slot.dateTime.minute;
                    final period = hour >= 12 ? 'م' : 'ص';
                    final h = hour > 12 ? hour - 12 : hour;
                    final timeStr = '$h:${minute.toString().padLeft(2, '0')} $period';
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          decoration: BoxDecoration(
                            color: isBooked ? AppColors.surfaceAlt : AppColors.surface,
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                              color: isBooked ? AppColors.border : AppColors.primary,
                              width: isBooked ? 1 : 1.5,
                            ),
                          ),
                          child: Text(timeStr,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700,
                              color: isBooked ? AppColors.textMuted : AppColors.primary,
                              decoration: isBooked ? TextDecoration.lineThrough : null,
                            )),
                        ),
                      ),
                    );
                  }).toList(),
                ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildCTA(BuildContext context, Teacher t) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 30),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text('${t.pricePerHour.toInt()}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const Text('أوقية/ساعة',
                style: TextStyle(fontSize: 10, color: AppColors.textHint)),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: AppButton(
              label: 'طلب جلسة',
              onTap: () => context.push('/request-session/${t.id}'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherAvatar extends StatelessWidget {
  final String initial;
  final double size;
  const _TeacherAvatar({required this.initial, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      alignment: Alignment.center,
      child: Text(initial,
        style: TextStyle(fontSize: size * 0.38, fontWeight: FontWeight.w700, color: AppColors.primary)),
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
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                color: valueColor ?? AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(fontSize: 10, color: AppColors.textHint)),
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
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
    );
  }
}
