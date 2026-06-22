import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/extensions/l10n_extension.dart';
import '../../../core/services/supabase_service.dart';
import '../../../shared/widgets/app_button.dart';

class TeacherOnboardingScreen extends StatefulWidget {
  const TeacherOnboardingScreen({super.key});
  @override
  State<TeacherOnboardingScreen> createState() => _TeacherOnboardingScreenState();
}

class _TeacherOnboardingScreenState extends State<TeacherOnboardingScreen> {
  final _formKey  = GlobalKey<FormState>();
  final _bioCtrl  = TextEditingController();
  final _priceCtrl = TextEditingController();
  int _yearsExp = 1;
  final Set<String> _selectedSubjects = {};
  bool _loading = false;
  String? _error;

  static const _subjectOptions = [
    'العربية', 'الفرنسية', 'الإنجليزية', 'الرياضيات',
    'التاريخ و الجغرافيا', 'الفلسفة', 'العلوم الطبيعية',
    'التربية الإسلامية', 'التربية المدنية',
  ];
  static const _maxSubjects = 2;

  @override
  void dispose() {
    _bioCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = context.l10n;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSubjects.isEmpty) {
      setState(() => _error = l.onboardingErrNoSubject);
      return;
    }
    if (_selectedSubjects.length > _maxSubjects) {
      setState(() => _error = l.onboardingErrMaxSubjects(_maxSubjects));
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final uid = SupabaseService.userId!;
      await SupabaseService.client.from('teacher_profiles').upsert({
        'id': uid,
        'bio': _bioCtrl.text.trim(),
        'subjects': _selectedSubjects.toList(),
        'price_per_hour': double.parse(_priceCtrl.text.trim()),
        'years_experience': _yearsExp,
        'is_approved': false,
      });
      if (mounted) context.go('/teacher/home');
    } catch (e) {
      setState(() => _error = context.l10n.onboardingErrSave);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.onboardingWelcomeTitle,
                  style: const TextStyle(
                    fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Text(l.onboardingWelcomeBody,
                  style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary, height: 1.6)),
                const SizedBox(height: 28),

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
                  const SizedBox(height: 16),
                ],

                _label(l.onboardingBioLabel),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _bioCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(hintText: l.onboardingBioHint),
                  validator: (v) => (v == null || v.trim().length < 20)
                      ? l.onboardingBioTooShort
                      : null,
                ),
                const SizedBox(height: 20),

                _label(l.onboardingPriceLabel),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    hintText: l.onboardingPriceHint,
                    suffixText: l.dashOugiya,
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return l.onboardingPriceRequired;
                    final n = double.tryParse(v);
                    if (n == null || n <= 0) return l.onboardingPriceInvalid;
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                _label(l.onboardingYearsExp),
                const SizedBox(height: 10),
                Row(
                  children: List.generate(5, (i) {
                    final y = i + 1;
                    final sel = _yearsExp == y;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: GestureDetector(
                          onTap: () => setState(() => _yearsExp = y),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            decoration: BoxDecoration(
                              color: sel ? AppColors.primary : AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: sel ? AppColors.primary : AppColors.border,
                                width: sel ? 1.5 : 1,
                              ),
                            ),
                            child: Text('$y+',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w700,
                                color: sel ? Colors.white : AppColors.textPrimary,
                              )),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 20),

                _label(l.onboardingSubjectsLabel),
                const SizedBox(height: 4),
                Text(
                  l.onboardingSubjectsHint(_selectedSubjects.length, _maxSubjects),
                  style: TextStyle(
                    fontSize: 12,
                    color: _selectedSubjects.length >= _maxSubjects
                        ? AppColors.primary
                        : AppColors.textHint,
                    fontWeight: _selectedSubjects.length >= _maxSubjects
                        ? FontWeight.w700
                        : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8, runSpacing: 8,
                  children: _subjectOptions.map((s) {
                    final sel = _selectedSubjects.contains(s);
                    final maxReached = _selectedSubjects.length >= _maxSubjects && !sel;
                    return GestureDetector(
                      onTap: () => setState(() {
                        if (sel) { _selectedSubjects.remove(s); }
                        else if (!maxReached) { _selectedSubjects.add(s); }
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel
                              ? AppColors.primary
                              : maxReached
                                  ? AppColors.surfaceAlt
                                  : AppColors.surface,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: sel ? AppColors.primary : AppColors.border,
                            width: sel ? 1.5 : 1,
                          ),
                        ),
                        child: Text(s,
                          style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: sel
                                ? Colors.white
                                : maxReached
                                    ? AppColors.textHint
                                    : AppColors.textPrimary,
                          )),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 32),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.accentLight,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: AppColors.primary, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(l.onboardingInfoNote,
                          style: const TextStyle(
                            fontSize: 12, color: AppColors.primary, height: 1.5)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                AppButton(
                  label: l.onboardingSubmitBtn,
                  isLoading: _loading,
                  onTap: _save,
                ),
                const SizedBox(height: 14),
                Center(
                  child: TextButton(
                    onPressed: _loading ? null : () => context.go('/teacher/home'),
                    child: Text(l.onboardingSkipBtn,
                      style: const TextStyle(fontSize: 13, color: AppColors.textHint)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
    style: const TextStyle(
      fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary));
}
