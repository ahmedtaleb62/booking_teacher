import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/session_states.dart';
import '../../../core/constants/subjects.dart';
import '../../../core/extensions/l10n_extension.dart';
import '../../../core/providers/payment_methods_provider.dart';
import '../../../core/providers/sessions_provider.dart';
import '../../../core/services/session_service.dart';
import '../../../core/utils/app_errors.dart';
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
  Uint8List? _proofBytes;
  String _proofExt = 'jpg';
  bool _loading = false;
  String? _error;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    // Read bytes immediately — the cache file may be deleted before submit
    final bytes = await file.readAsBytes();
    final ext = file.path.contains('.') ? file.path.split('.').last.toLowerCase() : 'jpg';
    setState(() { _proofBytes = bytes; _proofExt = ext; _error = null; });
  }

  Future<void> _submit(String methodKey) async {
    final l = context.l10n;
    if (_proofBytes == null) {
      setState(() => _error = l.paymentErrNoProof);
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await SessionService.uploadAndSubmitPayment(
        sessionId:  widget.sessionId,
        method:     methodKey,
        imageBytes: _proofBytes!,
        imageExt:   _proofExt,
      );
      // Invalidate immediately — don't wait for realtime event
      ref.invalidate(sessionProvider(widget.sessionId));
      ref.invalidate(studentSessionsProvider);
      if (mounted) context.pushReplacement('/payment-submitted/${widget.sessionId}');
    } catch (e) {
      setState(() => _error = AppErrors.friendly(e, context.l10n));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
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
        title: Text(l.paymentTitle),
      ),
      body: sessionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(l.sessionLoadError)),
        data: (session) {
          if (session == null) return Center(child: Text(l.sessionNotFound));

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
                    Text(l.paymentProofSentTitle,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(l.paymentProofSentBody,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
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
                  Text(l.commonErrorLoading),
                  TextButton(
                    onPressed: () => ref.invalidate(paymentMethodsProvider),
                    child: Text(l.commonRetry),
                  ),
                ],
              ),
            ),
            data: (methods) {
              if (methods.isEmpty) {
                return Center(child: Text(l.commonNoData));
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
                                      ? '${l.paymentRejectedBanner}: ${session.payment!.rejectReason!}'
                                      : l.paymentRejectedBanner)
                                  : l.paymentAwaitingInstruction,
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

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.primaryDark,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Text(l.paymentAmountLabel,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF9DB2B8))),
                          const SizedBox(height: 4),
                          RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '${session.amount.toInt()} ',
                                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w700, color: Colors.white),
                                ),
                                TextSpan(
                                  text: l.sessionOugiya(''),
                                  style: const TextStyle(fontSize: 15, color: AppColors.accent, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text('${translateSubject(session.subject, Localizations.localeOf(context))} · ${l.sessionMinutes(session.durationMinutes)}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF9DB2B8))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    Text(l.paymentChooseMethod,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
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
                                  Text('${l.paymentHolder} ${method.label}',
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
                                    SnackBar(content: Text(l.commonCopied),
                                      duration: const Duration(seconds: 1)),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentLight,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.copy_rounded, size: 14, color: AppColors.primary),
                                      const SizedBox(width: 5),
                                      Text(l.commonCopy,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                                          color: AppColors.primary)),
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
                              Text(l.paymentAccountName,
                                style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
                              Text(method.holder,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    Text(l.paymentProofSection,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    const SizedBox(height: 9),
                    GestureDetector(
                      onTap: _pickImage,
                      child: _proofBytes != null
                          ? Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.memory(_proofBytes!, height: 160, width: double.infinity, fit: BoxFit.cover),
                                ),
                                Positioned(
                                  top: 8, left: 8,
                                  child: GestureDetector(
                                    onTap: () => setState(() => _proofBytes = null),
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
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.upload_rounded, color: AppColors.primary, size: 28),
                                  const SizedBox(height: 6),
                                  Text(l.paymentProofHint,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                      color: AppColors.primary)),
                                  const SizedBox(height: 2),
                                  Text(l.paymentProofHintSub,
                                    style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                                ],
                              ),
                            ),
                    ),
                    const SizedBox(height: 18),

                    InfoBanner(text: l.paymentWarning, type: BannerType.error),
                    const SizedBox(height: 18),

                    AppButton(
                      label: l.paymentSubmitBtn,
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
