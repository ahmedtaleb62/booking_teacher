import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/l10n_extension.dart';
import '../../../core/services/supabase_service.dart';

class ComplaintScreen extends StatefulWidget {
  const ComplaintScreen({super.key});

  @override
  State<ComplaintScreen> createState() => _ComplaintScreenState();
}

class _ComplaintScreenState extends State<ComplaintScreen> {
  final _messageCtrl = TextEditingController();
  String _type = 'complaint';
  bool _saving = false;
  bool _loadingHistory = true;
  String? _errorMsg;
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final uid = SupabaseService.userId;
    if (uid == null) return;
    try {
      final rows = await SupabaseService.client
          .from('complaints')
          .select('id, type, message, status, admin_note, created_at')
          .eq('user_id', uid)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _history = List<Map<String, dynamic>>.from(rows as List);
          _loadingHistory = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _submit() async {
    final l = context.l10n;
    final message = _messageCtrl.text.trim();
    if (message.isEmpty) {
      setState(() => _errorMsg = l.complaintEmptyError);
      return;
    }

    setState(() { _saving = true; _errorMsg = null; });
    try {
      final uid = SupabaseService.userId;
      await SupabaseService.client.from('complaints').insert({
        'user_id': uid,
        'type': _type,
        'message': message,
      });
      if (mounted) {
        _messageCtrl.clear();
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.complaintSuccessMsg),
            backgroundColor: AppColors.statusConfirmed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        await _loadHistory();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorMsg = l.authErrGeneral;
        });
      }
    }
  }

  Widget _typeOption(String value, String label, IconData icon) {
    final selected = _type == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: selected ? AppColors.primary : AppColors.textHint, size: 22),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: selected ? AppColors.primary : AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _historyCard(Map<String, dynamic> row) {
    final l = context.l10n;
    final isComplaint = row['type'] == 'complaint';
    final isClosed = row['status'] == 'reviewed';
    final adminNote = row['admin_note'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isComplaint ? AppColors.statusRejectedBg : AppColors.statusApprovedBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isComplaint ? l.complaintTypeComplaint : l.complaintTypeSuggestion,
                  style: TextStyle(
                      fontSize: 10.5, fontWeight: FontWeight.w700,
                      color: isComplaint ? AppColors.error : AppColors.statusApproved),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isClosed ? const Color(0xFFF1F5F9) : const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isClosed ? l.complaintStatusClosed : l.complaintStatusPending,
                  style: TextStyle(
                      fontSize: 10.5, fontWeight: FontWeight.w700,
                      color: isClosed ? const Color(0xFF475569) : const Color(0xFF92400E)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(row['message'] as String? ?? '',
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.5)),
          if (isClosed && adminNote != null && adminNote.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.statusApprovedBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.complaintAdminReplyLabel,
                      style: const TextStyle(
                          fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.statusApproved)),
                  const SizedBox(height: 3),
                  Text(adminNote,
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textPrimary, height: 1.5)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
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
        title: Text(l.complaintScreenTitle,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.complaintIntro,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
            const SizedBox(height: 22),

            Row(
              children: [
                _typeOption('complaint', l.complaintTypeComplaint, Icons.report_problem_outlined),
                const SizedBox(width: 12),
                _typeOption('suggestion', l.complaintTypeSuggestion, Icons.lightbulb_outline_rounded),
              ],
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _messageCtrl,
              maxLines: 7,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: l.complaintMessageHint,
                hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 13),
                filled: true,
                fillColor: AppColors.surface,
                alignLabelWithHint: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),

            if (_errorMsg != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.statusRejectedBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_errorMsg!,
                          style: const TextStyle(fontSize: 12, color: AppColors.error)),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(l.complaintSubmitBtn,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),

            if (_loadingHistory) ...[
              const SizedBox(height: 32),
              const Center(child: CircularProgressIndicator()),
            ] else if (_history.isNotEmpty) ...[
              const SizedBox(height: 32),
              Text(l.complaintHistoryTitle,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              ..._history.map(_historyCard),
            ],
          ],
        ),
      ),
    );
  }
}
