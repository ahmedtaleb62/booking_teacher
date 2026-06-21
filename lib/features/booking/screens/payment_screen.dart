import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/session_states.dart';
import '../../../core/providers/payment_methods_provider.dart';
import '../../../core/providers/sessions_provider.dart';
import '../../../core/services/session_service.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/info_banner.dart';

class PaymentScreen extends ConsumerStatefulWidget {
  final String sessionId;
  const PaymentScreen({super.key, required this.sessionId});
  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen> {
  int _selectedIndex = 0;
  File? _proofImage;
  bool _loading = false;
  String? _error;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file != null) setState(() { _proofImage = File(file.path); _error = null; });
  }

  Future<void> _submit(String methodKey) async {
    if (_proofImage == null) {
      setState(() => _error = 'يرجى رفع صورة إثبات الدفع أولاً');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await SessionService.uploadAndSubmitPayment(
        sessionId: widget.sessionId,
        method: methodKey,
        localFilePath: _proofImage!.path,
      );
      if (mounted) context.pushReplacement('/payment-submitted/${widget.sessionId}');
    } catch (e) {
      setState(() => _error = 'حدث خطأ: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionProvider(widget.sessionId));
    final methodsAsync = ref.watch(paymentMethodsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.textPrimary),
          ),
          onPressed: () => context.pop(),
        ),
        title: const Text('الدفع'),
      ),
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('تعذّر تحميل الجلسة')),
        data: (session) {
          if (session == null) return const Center(child: Text('الجلسة غير موجودة'));

          // Guard: already submitted — waiting for admin review
          if (session.state == SessionState.paymentSubmitted) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.statusPaymentSubmittedBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shield_outlined,
                        size: 36, color: AppColors.statusPaymentSubmitted),
                    ),
                    const SizedBox(height: 16),
                    const Text('تم إرسال إثبات الدفع',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    const Text('الإدارة تراجع الإثبات وستُبلَّغ فور التأكيد.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
                  ],
                ),
              ),
            );
          }

          final isRejected = session.state == SessionState.paymentRejected;

          return methodsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('تعذّر تحميل طرق الدفع'),
                  TextButton(
                    onPressed: () => ref.invalidate(paymentMethodsProvider),
                    child: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            ),
            data: (methods) {
              if (methods.isEmpty) {
                return const Center(child: Text('لا توجد طرق دفع متاحة، تواصل مع الإدارة'));
              }

              if (_selectedIndex >= methods.length) _selectedIndex = 0;
              final method = methods[_selectedIndex];

              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDECEC),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(_error!,
                          style: const TextStyle(fontSize: 13, color: Color(0xFFC0392B))),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Context banner
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                      decoration: BoxDecoration(
                        color: isRejected ? const Color(0xFFFEF2F2) : AppColors.statusApprovedBg,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: isRejected
                              ? const Color(0xFFFCA5A5)
                              : AppColors.statusApproved.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 30, height: 30,
                            decoration: BoxDecoration(
                              color: isRejected ? const Color(0xFFDC2626) : AppColors.statusApproved,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isRejected ? Icons.refresh_rounded : Icons.check_rounded,
                              color: Colors.white, size: 16,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              isRejected
                                  ? (session.payment?.rejectReason?.isNotEmpty == true
                                      ? 'السبب: ${session.payment!.rejectReason!} — ارفع إثباتاً جديداً.'
                                      : 'رُفض الإثبات السابق — ارفع إثباتاً جديداً.')
                                  : 'وافق الأستاذ على طلبك ✦ أكمل الدفع لتأكيد الحجز.',
                              style: TextStyle(
                                fontSize: 12,
                                color: isRejected ? const Color(0xFF7F1D1D) : AppColors.statusApprovedText,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Amount card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Text('المبلغ المطلوب',
                            style: TextStyle(fontSize: 12, color: Color(0xFF9DB2B8))),
                          const SizedBox(height: 4),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '${session.amount.toInt()} ',
                                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: Colors.white),
                                ),
                                const TextSpan(
                                  text: 'أوقية',
                                  style: TextStyle(fontSize: 15, color: AppColors.accent, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('${session.subject} · ${session.durationMinutes} دقيقة',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF9DB2B8))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Payment method tabs
                    const Text('اختر وسيلة الدفع',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 9),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(methods.length, (i) {
                          final sel = i == _selectedIndex;
                          return Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedIndex = i),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                decoration: BoxDecoration(
                                  color: sel ? AppColors.primary : AppColors.surface,
                                  borderRadius: BorderRadius.circular(11),
                                  border: Border.all(
                                    color: sel ? AppColors.primary : AppColors.border,
                                    width: sel ? 1.5 : 1),
                                ),
                                child: Text(methods[i].label,
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                                    color: sel ? Colors.white : AppColors.textPrimary)),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Account details
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('رقم ${method.label}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                                  const SizedBox(height: 3),
                                  Text(method.number,
                                    style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary, letterSpacing: 1)),
                                ],
                              ),
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: method.number));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('تم نسخ الرقم'), duration: Duration(seconds: 1)),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentLight,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.copy_rounded, size: 14, color: AppColors.primary),
                                      SizedBox(width: 5),
                                      Text('نسخ',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('اسم المستفيد',
                                style: TextStyle(fontSize: 12, color: AppColors.textHint)),
                              Text(method.holder,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Upload proof
                    const Text('إثبات الدفع',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 9),
                    GestureDetector(
                      onTap: _pickImage,
                      child: _proofImage != null
                          ? Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.file(_proofImage!, height: 160, width: double.infinity, fit: BoxFit.cover),
                                ),
                                Positioned(
                                  top: 8, left: 8,
                                  child: GestureDetector(
                                    onTap: () => setState(() => _proofImage = null),
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                                      child: const Icon(Icons.close, color: Colors.white, size: 14),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Container(
                              height: 100,
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.borderStrong, width: 1.5),
                              ),
                              child: const Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.upload_rounded, color: AppColors.primary, size: 28),
                                  SizedBox(height: 6),
                                  Text('ارفع صورة لقطة التحويل',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
                                  SizedBox(height: 2),
                                  Text('PNG · JPG حتى 5MB',
                                    style: TextStyle(fontSize: 11, color: AppColors.textHint)),
                                ],
                              ),
                            ),
                    ),
                    const SizedBox(height: 18),

                    const InfoBanner(
                      text: 'لا تدفع لأي رقم آخر. الدفع خارج هذه الأرقام لا تضمنه المنصة.',
                      type: BannerType.error,
                    ),
                    const SizedBox(height: 18),

                    AppButton(
                      label: 'أرسلت الدفع — تأكيد',
                      isLoading: _loading,
                      onTap: () => _submit(method.method),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
