import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/l10n_extension.dart';
import '../../../core/providers/payment_methods_provider.dart';
import '../../../core/services/course_service.dart';
import '../../../shared/widgets/app_button.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  final String type;   // 'course' or 'package'
  final String itemId;
  final double priceMonthly;
  final double? priceYearly;
  final String title;

  const SubscriptionScreen({
    super.key,
    required this.type,
    required this.itemId,
    required this.priceMonthly,
    this.priceYearly,
    required this.title,
  });

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  int _selectedMethod = 0;
  String _selectedPlan = 'monthly';
  File? _proofImage;
  bool _loading = false;
  String? _error;

  bool get _isPackage => widget.type == 'package';

  double get _effectiveYearlyPrice => widget.priceYearly ?? (widget.priceMonthly * 10);
  double get _quarterlyPrice => widget.priceMonthly * 3;

  double get _amount {
    if (_isPackage) return widget.priceYearly ?? widget.priceMonthly;
    switch (_selectedPlan) {
      case 'yearly': return _effectiveYearlyPrice;
      case 'quarterly': return _quarterlyPrice;
      default: return widget.priceMonthly;
    }
  }

  String get _planType => _isPackage ? 'yearly' : _selectedPlan;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file != null) setState(() { _proofImage = File(file.path); _error = null; });
  }

  Future<void> _submit(String methodKey) async {
    final l = context.l10n;
    if (_proofImage == null) {
      setState(() => _error = l.subscriptionErrNoProof);
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final subId = await CourseService.createSubscription(
        type: widget.type,
        courseId: widget.type == 'course' ? widget.itemId : null,
        packageId: widget.type == 'package' ? widget.itemId : null,
        amount: _amount,
        planType: _planType,
        localProofPath: _proofImage!.path,
      );
      if (mounted) context.pushReplacement('/subscription-pending/$subId');
    } catch (e) {
      if (mounted) setState(() => _error = l.subscriptionErrGeneral(e.toString()));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
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
        title: Text(l.subscriptionTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildItemCard(l),
            const SizedBox(height: 16),
            if (!_isPackage) ...[
              _buildPlanSelector(l),
              const SizedBox(height: 20),
            ],
            methodsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox.shrink(),
              data: (methods) => _buildPaymentMethods(l, methods),
            ),
            const SizedBox(height: 20),
            _buildProofUpload(l),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.statusRejectedBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13))),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            methodsAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (methods) {
                final method = methods.isNotEmpty ? methods[_selectedMethod] : null;
                return AppButton(
                  label: _loading ? l.subscriptionSubmitting : l.subscriptionConfirm,
                  isLoading: _loading,
                  onTap: (method == null)
                      ? null
                      : () => _submit(method.method),
                );
              },
            ),
            const SizedBox(height: 12),
            Text(
              l.subscriptionReviewNote,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: AppColors.textHint),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanSelector(dynamic l) {
    final monthly   = widget.priceMonthly;
    final quarterly = _quarterlyPrice;
    final yearly    = _effectiveYearlyPrice;
    final saving    = ((monthly * 12 - yearly) / (monthly * 12) * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.subscriptionChoosePlan,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: _planOption(l,
            label: l.subscriptionPlanMonthly,
            price: '${monthly.toStringAsFixed(0)} ${l.dashOugiya}',
            sub: l.subscriptionPerMonthLabel,
            plan: 'monthly',
          )),
          const SizedBox(width: 8),
          Expanded(child: _planOption(l,
            label: l.subscriptionPlanQuarterly,
            price: '${quarterly.toStringAsFixed(0)} ${l.dashOugiya}',
            sub: l.subscriptionPerQuarterLabel,
            plan: 'quarterly',
          )),
          const SizedBox(width: 8),
          Expanded(child: _planOption(l,
            label: l.subscriptionPlanYearly,
            price: '${yearly.toStringAsFixed(0)} ${l.dashOugiya}',
            sub: l.subscriptionSavePct(saving),
            plan: 'yearly',
            highlight: true,
          )),
        ]),
      ],
    );
  }

  Widget _planOption(dynamic l, {
    required String label,
    required String price,
    required String sub,
    required String plan,
    bool highlight = false,
  }) {
    final selected = _selectedPlan == plan;
    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = plan),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentLight : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 18, height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.textHint,
                    width: selected ? 5 : 1.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected ? AppColors.primary : AppColors.textPrimary)),
            ]),
            const SizedBox(height: 8),
            Text(price,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppColors.primary : AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(sub,
                style: TextStyle(
                    fontSize: 11,
                    color: highlight && !selected
                        ? AppColors.statusConfirmed
                        : AppColors.textHint,
                    fontWeight: highlight ? FontWeight.w600 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }

  Widget _buildItemCard(dynamic l) {
    final isPackage = widget.type == 'package';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isPackage ? const Color(0xFF7B61FF) : AppColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Icon(
              isPackage ? Icons.layers_rounded : Icons.play_circle_outline_rounded,
              color: Colors.white, size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPackage ? l.subscriptionTypePackage : l.subscriptionTypeCourse,
                  style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.75)),
                ),
                Text(widget.title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_amount.toStringAsFixed(0),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
              Text(_planType == 'yearly'
                  ? l.subscriptionPerYear
                  : _planType == 'quarterly'
                      ? l.subscriptionPerQuarter
                      : l.subscriptionPerMonth,
                  style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.75))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethods(dynamic l, List<PaymentMethod> methods) {
    if (methods.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Text(l.subscriptionNoMethods,
            style: const TextStyle(color: AppColors.textHint, fontSize: 13)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.subscriptionPaymentMethodLabel,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        ...methods.asMap().entries.map((e) {
          final i = e.key;
          final m = e.value;
          final selected = i == _selectedMethod;
          return GestureDetector(
            onTap: () => setState(() => _selectedMethod = i),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: selected ? AppColors.accentLight : AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? AppColors.primary : AppColors.textHint,
                        width: selected ? 5 : 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.label,
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        if (m.number.isNotEmpty)
                          Text(l.subscriptionAccountNumber(m.number),
                              style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
                        if (m.holder.isNotEmpty)
                          Text(l.subscriptionHolder(m.holder),
                              style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildProofUpload(dynamic l) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.subscriptionProofTitle,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            width: double.infinity,
            height: 140,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _proofImage != null ? AppColors.primary : AppColors.borderStrong,
                width: _proofImage != null ? 1.5 : 1,
              ),
            ),
            child: _proofImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(_proofImage!, fit: BoxFit.cover,
                        width: double.infinity, height: double.infinity),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.upload_rounded, size: 32, color: AppColors.textHint),
                      const SizedBox(height: 8),
                      Text(l.subscriptionProofHint,
                          style: const TextStyle(fontSize: 13, color: AppColors.textHint)),
                      const SizedBox(height: 4),
                      const Text('JPG, PNG, WEBP',
                          style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
