import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/session_states.dart';
import '../../../core/providers/sessions_provider.dart';
import '../../../core/services/supabase_service.dart';

class TeacherRequestDetailScreen extends ConsumerStatefulWidget {
  final String requestId;
  const TeacherRequestDetailScreen({super.key, required this.requestId});
  @override
  ConsumerState<TeacherRequestDetailScreen> createState() => _TeacherRequestDetailScreenState();
}

class _TeacherRequestDetailScreenState extends ConsumerState<TeacherRequestDetailScreen> {
  bool _approving = false;
  bool _rejecting = false;

  Future<void> _approve() async {
    setState(() => _approving = true);
    try {
      await SupabaseService.client.rpc('teacher_approve_session',
          params: {'p_session_id': widget.requestId});
      if (mounted) {
        ref.invalidate(studentSessionsProvider);
        ref.invalidate(teacherSessionsProvider);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء القبول، حاول مرة أخرى')));
      }
    } finally {
      if (mounted) setState(() => _approving = false);
    }
  }

  Future<void> _reject() async {
    setState(() => _rejecting = true);
    try {
      await SupabaseService.client.rpc('teacher_reject_session',
          params: {'p_session_id': widget.requestId});
      if (mounted) {
        ref.invalidate(studentSessionsProvider);
        ref.invalidate(teacherSessionsProvider);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء الرفض، حاول مرة أخرى')));
      }
    } finally {
      if (mounted) setState(() => _rejecting = false);
    }
  }

  String _formatDate(DateTime dt) {
    final days = ['الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
    final h = dt.hour > 12 ? dt.hour - 12 : dt.hour;
    final period = dt.hour >= 12 ? 'م' : 'ص';
    return '${days[dt.weekday % 7]} $h:${dt.minute.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionProvider(widget.requestId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('تعذّر تحميل الطلب'),
              TextButton(
                onPressed: () => ref.invalidate(sessionProvider(widget.requestId)),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
        data: (session) {
          if (session == null) {
            return const Center(child: Text('الطلب غير موجود'));
          }

          final isStillPending = session.state == SessionState.requested;
          final commissionRate = 0.15;
          final net = session.amount * (1 - commissionRate);

          return Column(
            children: [
              // AppBar
              Container(
                color: AppColors.surface,
                padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        margin: const EdgeInsets.all(12),
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.textPrimary),
                      ),
                    ),
                    const Text('مراجعة الطلب',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      // Status banner
                      if (isStillPending)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3E2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFF8DEB8)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36, height: 36,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF2994A),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(Icons.access_time_rounded, color: Colors.white, size: 18),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('المسؤول الآن',
                                      style: TextStyle(fontSize: 11, color: Color(0xFFB07A2A))),
                                    Text('أنت — الرد على الطلب خلال 24 ساعة',
                                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.statusApprovedBg,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                session.state == SessionState.teacherRejected
                                    ? Icons.cancel_outlined : Icons.check_circle_outline_rounded,
                                color: session.state == SessionState.teacherRejected
                                    ? AppColors.error : AppColors.statusApproved,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                session.state == SessionState.teacherRejected
                                    ? 'تم رفض هذا الطلب' : 'تمت معالجة هذا الطلب',
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 14),

                      // Student card
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.accentLight,
                                borderRadius: BorderRadius.circular(13),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                session.teacherName.isNotEmpty ? session.teacherName[0] : 'ط',
                                style: const TextStyle(color: AppColors.primary,
                                  fontWeight: FontWeight.w700, fontSize: 19),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(session.teacherName.isNotEmpty ? session.teacherName : 'طالب',
                                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary)),
                                const Text('طالب',
                                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Session details
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            _DetailRow(label: 'المادة', value: session.subject),
                            const SizedBox(height: 11),
                            _DetailRow(label: 'الموعد المطلوب', value: _formatDate(session.scheduledAt)),
                            const SizedBox(height: 11),
                            _DetailRow(label: 'المدة', value: '${session.durationMinutes} دقيقة'),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 11),
                              child: Divider(height: 1, color: Color(0xFFF0F1F3)),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('صافي ربحك',
                                  style: TextStyle(fontSize: 13, color: AppColors.textHint)),
                                RichText(
                                  text: TextSpan(
                                    style: const TextStyle(fontFamily: 'IBM Plex Sans Arabic'),
                                    children: [
                                      TextSpan(
                                        text: '${net.toInt()} أوقية ',
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                                          color: Color(0xFF1B9E77)),
                                      ),
                                      TextSpan(
                                        text: '(من ${session.amount.toInt()} − عمولة 15%)',
                                        style: const TextStyle(fontSize: 10, color: AppColors.textHint),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Student note
                      if (session.studentNote != null && session.studentNote!.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('وصف الطلب',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary)),
                              const SizedBox(height: 7),
                              Text(session.studentNote!,
                                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.7)),
                            ],
                          ),
                        ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),

              // Bottom actions — only shown if still pending
              if (isStillPending)
                Container(
                  color: AppColors.surface,
                  padding: EdgeInsets.only(
                    left: 22, right: 22, top: 13,
                    bottom: MediaQuery.of(context).padding.bottom + 13,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _rejecting ? null : () => _showRejectDialog(context),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            side: const BorderSide(color: Color(0xFFE6E9ED)),
                            foregroundColor: AppColors.error,
                          ),
                          child: _rejecting
                              ? const SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.error))
                              : const Text('رفض الطلب',
                                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _approving ? null : _approve,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            backgroundColor: const Color(0xFF1B9E77),
                            foregroundColor: Colors.white,
                            elevation: 8,
                            shadowColor: const Color(0xFF1B9E77).withValues(alpha: 0.5),
                          ),
                          child: _approving
                              ? const SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('قبول الطلب',
                                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showRejectDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('رفض الطلب', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('هل تريد رفض هذا الطلب؟ سيتم إشعار الطالب.',
          style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _reject();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('رفض'),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textHint)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      ],
    );
  }
}
