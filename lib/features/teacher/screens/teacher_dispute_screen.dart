import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';

class TeacherDisputeScreen extends StatefulWidget {
  final String disputeId;
  const TeacherDisputeScreen({super.key, required this.disputeId});

  @override
  State<TeacherDisputeScreen> createState() => _TeacherDisputeScreenState();
}

class _TeacherDisputeScreenState extends State<TeacherDisputeScreen> {
  final _response = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _response.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _AppBar(disputeId: widget.disputeId),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  _DisputeHero(),
                  const SizedBox(height: 16),
                  _DisputeDetails(),
                  const SizedBox(height: 16),
                  _StudentComplaint(),
                  const SizedBox(height: 16),
                  _ResponseField(controller: _response),
                  const SizedBox(height: 16),
                  _AdminNote(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          _BottomActions(submitting: _submitting, onSubmit: () => _submitResponse(context), onAttach: () {}),
        ],
      ),
    );
  }

  Future<void> _submitResponse(BuildContext context) async {
    if (_response.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى كتابة ردك أولاً')),
      );
      return;
    }
    setState(() => _submitting = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _submitting = false);
    messenger.showSnackBar(
      const SnackBar(content: Text('تم إرسال ردك — الإدارة ستراجعه'), backgroundColor: Color(0xFF1B6B7A)),
    );
    router.pop();
  }
}

class _AppBar extends StatelessWidget {
  final String disputeId;
  const _AppBar({required this.disputeId});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Text('نزاع #DSP-$disputeId', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _DisputeHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF6CFCF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(color: const Color(0xFFE03E3E), borderRadius: BorderRadius.circular(999)),
            child: const Text('DISPUTE · يحتاج ردّك', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
          const SizedBox(height: 11),
          const Text('فتح الطالب نزاعاً على جلسة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 5),
          const Text(
            'قدّم ردّك وأدلتك خلال 48 ساعة، وإلا تُحسم لصالح الطالب. المبلغ مجمّد حتى القرار.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF7A4A4A), height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _DisputeDetails extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _Row(label: 'سبب النزاع',    value: 'جودة الجلسة'),
          const SizedBox(height: 9),
          _Row(label: 'الطالب',        value: 'سيدنا أحمد'),
          const SizedBox(height: 9),
          _Row(label: 'المبلغ المجمّد', value: '425 أوقية', valueColor: const Color(0xFFE03E3E)),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _Row({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textHint)),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: valueColor ?? AppColors.textPrimary)),
      ],
    );
  }
}

class _StudentComplaint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('شكوى الطالب', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          SizedBox(height: 7),
          Text('«انقطعت الجلسة بعد 15 دقيقة ولم يعد الأستاذ.»',
              style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.7)),
        ],
      ),
    );
  }
}

class _ResponseField extends StatelessWidget {
  final TextEditingController controller;
  const _ResponseField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: 4,
      style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: 'اكتب ردّك واشرح ما حدث من جهتك…',
        hintStyle: const TextStyle(fontSize: 12.5, color: AppColors.textHint),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.borderStrong),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(13),
      ),
    );
  }
}

class _AdminNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0EDFF),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: const Color(0xFF7B61FF), borderRadius: BorderRadius.circular(10)),
            alignment: Alignment.center,
            child: const Text('إ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('القرار النهائي بيد', style: TextStyle(fontSize: 11, color: Color(0xFF8A78D6))),
              Text('الإدارة — بعد سماع الطرفين',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  final bool submitting;
  final VoidCallback onSubmit;
  final VoidCallback onAttach;
  const _BottomActions({required this.submitting, required this.onSubmit, required this.onAttach});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.only(
        left: 22, right: 22, top: 13,
        bottom: MediaQuery.of(context).padding.bottom + 13,
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onAttach,
              icon: const Icon(Icons.attach_file_rounded, size: 16),
              label: const Text('إرفاق دليل', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                side: const BorderSide(color: AppColors.borderStrong),
                foregroundColor: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: ElevatedButton(
              onPressed: submitting ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                backgroundColor: AppColors.primaryDark,
                foregroundColor: Colors.white,
              ),
              child: submitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('إرسال الرد', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
