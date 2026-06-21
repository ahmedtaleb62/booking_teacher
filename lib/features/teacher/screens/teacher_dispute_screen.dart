import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;
import '../../../core/constants/app_colors.dart';
import '../../../core/providers/sessions_provider.dart';
import '../../../core/services/supabase_service.dart';

class TeacherDisputeScreen extends ConsumerStatefulWidget {
  final String disputeId; // session_id used as dispute identifier
  const TeacherDisputeScreen({super.key, required this.disputeId});
  @override
  ConsumerState<TeacherDisputeScreen> createState() => _TeacherDisputeScreenState();
}

class _TeacherDisputeScreenState extends ConsumerState<TeacherDisputeScreen> {
  final _response = TextEditingController();
  bool _submitting = false;
  bool _uploadingEvidence = false;
  final List<String> _evidenceUrls = [];

  @override
  void dispose() {
    _response.dispose();
    super.dispose();
  }

  Future<void> _attachEvidence() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;

    setState(() => _uploadingEvidence = true);
    try {
      final uid = SupabaseService.userId!;
      final ext = file.path.split('.').last.toLowerCase();
      final fileName = 'disputes/$uid/${widget.disputeId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final bytes = await File(file.path).readAsBytes();
      await SupabaseService.client.storage
          .from('payment-proofs')
          .uploadBinary(fileName, bytes,
              fileOptions: FileOptions(contentType: ext == 'png' ? 'image/png' : 'image/jpeg'));
      setState(() => _evidenceUrls.add(fileName));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('تعذّر رفع الصورة: $e')));
    } finally {
      if (mounted) setState(() => _uploadingEvidence = false);
    }
  }

  Future<void> _submitResponse() async {
    if (_response.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('يرجى كتابة ردّك أولاً')));
      return;
    }
    setState(() => _submitting = true);
    try {
      // Update the dispute with teacher statement + evidence
      await SupabaseService.client
          .from('disputes')
          .update({
            'teacher_statement': _response.text.trim(),
            if (_evidenceUrls.isNotEmpty) 'teacher_evidence': _evidenceUrls,
          })
          .eq('session_id', widget.disputeId);

      // Log event on the session
      await SupabaseService.client.from('session_events').insert({
        'session_id': widget.disputeId,
        'event_type': 'TEACHER_DISPUTE_RESPONSE',
        'actor': 'teacher',
        'actor_id': SupabaseService.userId,
        'note': _response.text.trim(),
      });

      ref.invalidate(teacherSessionsProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال ردّك — الإدارة ستراجعه'),
          backgroundColor: Color(0xFF1B6B7A),
        ),
      );
      if (!mounted) return;
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final disputeAsync = ref.watch(_disputeProvider(widget.disputeId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _AppBar(disputeId: widget.disputeId),
          Expanded(
            child: disputeAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
              error: (e, _) => Center(child: Text('تعذّر التحميل: $e')),
              data: (dispute) => SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    _DisputeHero(status: dispute?['status'] as String? ?? 'open'),
                    const SizedBox(height: 16),
                    _DisputeDetails(dispute: dispute),
                    const SizedBox(height: 16),
                    if (dispute?['student_statement'] != null) ...[
                      _StudentComplaint(statement: dispute!['student_statement'] as String),
                      const SizedBox(height: 16),
                    ],
                    if (dispute?['teacher_statement'] == null) ...[
                      _ResponseField(controller: _response),
                      const SizedBox(height: 16),
                      if (_evidenceUrls.isNotEmpty)
                        _EvidenceList(urls: _evidenceUrls),
                    ] else
                      _AlreadyResponded(statement: dispute!['teacher_statement'] as String),
                    const SizedBox(height: 16),
                    _AdminNote(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
          disputeAsync.when(
            data: (d) => d?['teacher_statement'] == null
                ? _BottomActions(
                    submitting: _submitting,
                    uploadingEvidence: _uploadingEvidence,
                    onSubmit: _submitResponse,
                    onAttach: _attachEvidence,
                  )
                : const SizedBox.shrink(),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// Provider for dispute details
final _disputeProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, sessionId) async {
  final data = await SupabaseService.client
      .from('disputes')
      .select('*, session:session_id(subject, amount, student:student_id(full_name))')
      .eq('session_id', sessionId)
      .maybeSingle();
  return data != null ? Map<String, dynamic>.from(data as Map) : null;
});

// ── App bar ───────────────────────────────────────────────────
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
          Text('نزاع #${disputeId.substring(0, 8).toUpperCase()}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}

class _DisputeHero extends StatelessWidget {
  final String status;
  const _DisputeHero({required this.status});

  @override
  Widget build(BuildContext context) {
    final isOpen = status == 'open';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isOpen ? const Color(0xFFFDECEC) : const Color(0xFFE3F6EF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isOpen ? const Color(0xFFF6CFCF) : const Color(0xFFB7E8D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              color: isOpen ? const Color(0xFFE03E3E) : const Color(0xFF15805F),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              isOpen ? 'DISPUTE · يحتاج ردّك' : 'محلول',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ),
          const SizedBox(height: 11),
          Text(
            isOpen ? 'فتح الطالب نزاعاً على جلسة' : 'تم حل النزاع',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          if (isOpen) ...[
            const SizedBox(height: 5),
            const Text(
              'قدّم ردّك وأدلتك خلال 48 ساعة، وإلا تُحسم لصالح الطالب. المبلغ مجمّد حتى القرار.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF7A4A4A), height: 1.6),
            ),
          ],
        ],
      ),
    );
  }
}

class _DisputeDetails extends StatelessWidget {
  final Map<String, dynamic>? dispute;
  const _DisputeDetails({required this.dispute});

  @override
  Widget build(BuildContext context) {
    final sessionMap = dispute?['session'] as Map? ?? {};
    final studentMap = sessionMap['student'] as Map? ?? {};
    final studentName = (studentMap['full_name'] as String?) ?? '—';
    final subject = (sessionMap['subject'] as String?) ?? '—';
    final frozenAmt = (dispute?['frozen_amount'] as num?)?.toInt() ?? 0;
    final reason = (dispute?['reason'] as String?) ?? '—';

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _Row(label: 'سبب النزاع', value: reason),
          const SizedBox(height: 9),
          _Row(label: 'المادة', value: subject),
          const SizedBox(height: 9),
          _Row(label: 'الطالب', value: studentName),
          const SizedBox(height: 9),
          _Row(label: 'المبلغ المجمّد', value: '$frozenAmt أوقية',
            valueColor: const Color(0xFFE03E3E)),
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
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
          color: valueColor ?? AppColors.textPrimary)),
      ],
    );
  }
}

class _StudentComplaint extends StatelessWidget {
  final String statement;
  const _StudentComplaint({required this.statement});

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
        children: [
          const Text('شكوى الطالب',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 7),
          Text('«$statement»',
            style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.7)),
        ],
      ),
    );
  }
}

class _AlreadyResponded extends StatelessWidget {
  final String statement;
  const _AlreadyResponded({required this.statement});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFE3F6EF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFB7E8D8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ردّك المُرسَل',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF15805F))),
          const SizedBox(height: 7),
          Text(statement,
            style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.7)),
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

class _EvidenceList extends StatelessWidget {
  final List<String> urls;
  const _EvidenceList({required this.urls});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('الأدلة المرفقة (${urls.length})',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: urls.map((u) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F6EF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.attach_file_rounded, size: 13, color: Color(0xFF15805F)),
                  SizedBox(width: 4),
                  Text('صورة', style: TextStyle(fontSize: 11, color: Color(0xFF15805F))),
                ],
              ),
            )).toList(),
          ),
        ],
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
      child: const Row(
        children: [
          Icon(Icons.shield_outlined, color: Color(0xFF7B61FF), size: 20),
          SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('القرار النهائي بيد',
                style: TextStyle(fontSize: 11, color: Color(0xFF8A78D6))),
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
  final bool uploadingEvidence;
  final VoidCallback onSubmit;
  final VoidCallback onAttach;
  const _BottomActions({
    required this.submitting, required this.uploadingEvidence,
    required this.onSubmit, required this.onAttach,
  });

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
              onPressed: uploadingEvidence ? null : onAttach,
              icon: uploadingEvidence
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.textSecondary))
                  : const Icon(Icons.attach_file_rounded, size: 16),
              label: const Text('إرفاق دليل',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
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
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('إرسال الرد',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
