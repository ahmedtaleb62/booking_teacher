import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/course.dart';
import '../../../core/providers/courses_provider.dart';

class MyCoursesScreen extends ConsumerWidget {
  const MyCoursesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subsAsync = ref.watch(mySubscriptionsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 22, 16),
              child: Row(
                children: [
                  const Text('دروسي',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  const Spacer(),
                  subsAsync.when(
                    data: (subs) {
                      final active = subs.where((s) => s.status == SubscriptionStatus.active).length;
                      if (active == 0) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.statusConfirmedBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text('$active نشط',
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.statusConfirmed, fontWeight: FontWeight.w700)),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: subsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textHint),
                      const SizedBox(height: 12),
                      Text('تعذّر التحميل: $e',
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () => ref.invalidate(mySubscriptionsProvider),
                        child: const Text('إعادة المحاولة'),
                      ),
                    ],
                  ),
                ),
                data: (subs) {
                  if (subs.isEmpty) return _buildEmpty(context);
                  return RefreshIndicator(
                    onRefresh: () => ref.refresh(mySubscriptionsProvider.future),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      itemCount: subs.length,
                      itemBuilder: (_, i) => _buildCard(context, subs[i]),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppColors.accentLight,
              borderRadius: BorderRadius.circular(22),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.school_outlined, size: 38, color: AppColors.primary),
          ),
          const SizedBox(height: 18),
          const Text('لا توجد اشتراكات بعد',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('استعرض الدروس والباقات المتاحة\nوابدأ رحلتك التعليمية',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/home'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: const Text('استعرض الدروس',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, Subscription sub) {
    final isActive = sub.status == SubscriptionStatus.active;
    final isPending = sub.status == SubscriptionStatus.pending;
    final isPackage = sub.type == 'package';

    return GestureDetector(
      onTap: () {
        if (isActive) {
          if (isPackage && sub.package != null) {
            context.push('/package/${sub.packageId}');
          } else if (!isPackage && sub.course != null) {
            context.push('/course/${sub.courseId}');
          }
        } else if (isPending) {
          context.push('/subscription-pending/${sub.id}');
        }
      },
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
            // Cover strip
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: isPackage
                    ? (sub.package?.coverColor ?? AppColors.primary)
                    : (sub.course?.coverColor ?? AppColors.primary),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          color: (isPackage
                                  ? (sub.package?.coverColor ?? AppColors.primary)
                                  : (sub.course?.coverColor ?? AppColors.primary))
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          isPackage ? Icons.layers_rounded : Icons.play_circle_outline_rounded,
                          color: isPackage
                              ? (sub.package?.coverColor ?? AppColors.primary)
                              : (sub.course?.coverColor ?? AppColors.primary),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(sub.itemName,
                                style: const TextStyle(
                                    fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            const SizedBox(height: 3),
                            Text(sub.itemSubject,
                                style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: sub.status.bgColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(sub.status.label,
                            style: TextStyle(
                                fontSize: 11, color: sub.status.color, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),

                  // Progress bar (only for active subscriptions)
                  if (isActive && sub.totalLessons > 0) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text('${sub.completedLessons}/${sub.totalLessons} درس',
                            style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                        const Spacer(),
                        Text(
                          '${((sub.completedLessons / sub.totalLessons) * 100).toStringAsFixed(0)}%',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: sub.totalLessons > 0
                            ? sub.completedLessons / sub.totalLessons
                            : 0,
                        backgroundColor: AppColors.surfaceAlt,
                        valueColor: AlwaysStoppedAnimation(
                          sub.course?.coverColor ?? sub.package?.coverColor ?? AppColors.primary,
                        ),
                        minHeight: 6,
                      ),
                    ),
                  ],

                  // Pending info
                  if (isPending) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0EDFF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: Color(0xFF7B61FF), size: 16),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text('إثبات الدفع قيد المراجعة — خلال 24 ساعة',
                                style: TextStyle(fontSize: 11, color: Color(0xFF7B61FF))),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Rejected info + resubscribe CTA
                  if (sub.status == SubscriptionStatus.rejected) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.statusRejectedBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.cancel_outlined, color: AppColors.error, size: 16),
                              SizedBox(width: 8),
                              Text('رُفض الاشتراك', style: TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          if (sub.rejectReason != null) ...[
                            const SizedBox(height: 4),
                            Text(sub.rejectReason!,
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final extra = {
                            'priceMonthly': isPackage ? sub.package?.priceMonthly : sub.course?.priceMonthly,
                            'priceYearly':  isPackage ? null : sub.course?.priceYearly,
                            'title':        sub.itemName,
                          };
                          context.push('/subscribe/${ isPackage ? 'package' : 'course'}/${isPackage ? sub.packageId : sub.courseId}', extra: extra);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        child: const Text('إعادة الاشتراك'),
                      ),
                    ),
                  ],

                  // Expiry
                  if (isActive && sub.expiresAt != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 12, color: AppColors.textHint),
                        const SizedBox(width: 5),
                        Text(
                          'ينتهي في ${_formatDate(sub.expiresAt!)}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                        ),
                      ],
                    ),
                  ],

                  // Expired — renew CTA
                  if (sub.status == SubscriptionStatus.expired) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          final extra = {
                            'priceMonthly': isPackage ? sub.package?.priceMonthly : sub.course?.priceMonthly,
                            'priceYearly':  isPackage ? null : sub.course?.priceYearly,
                            'title':        sub.itemName,
                          };
                          context.push('/subscribe/${isPackage ? 'package' : 'course'}/${isPackage ? sub.packageId : sub.courseId}', extra: extra);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8A96A3),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        child: const Text('تجديد الاشتراك'),
                      ),
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

  String _formatDate(DateTime dt) {
    const months = [
      '', 'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }
}
