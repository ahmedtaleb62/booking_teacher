import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/levels.dart';
import '../../../core/constants/subjects.dart';
import '../../../core/extensions/l10n_extension.dart';
import '../../../core/providers/teachers_provider.dart';
import '../../../shared/widgets/app_button.dart';

class FilterSheet extends ConsumerStatefulWidget {
  const FilterSheet({super.key});
  @override
  ConsumerState<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<FilterSheet> {
  String? _subject;
  String? _level;
  double  _minPrice = 0;
  double  _maxPrice = 2000;
  bool    _onlineOnly = false;

  static const _subjects = kSubjects;

  @override
  void initState() {
    super.initState();
    _subject    = ref.read(teacherSubjectFilterProvider);
    _level      = ref.read(teacherLevelFilterProvider);
    _minPrice   = ref.read(teacherMinPriceProvider);
    _maxPrice   = ref.read(teacherMaxPriceProvider);
    _onlineOnly = ref.read(teacherOnlineOnlyProvider);
  }

  void _reset() => setState(() {
    _subject    = null;
    _level      = null;
    _minPrice   = 0;
    _maxPrice   = 2000;
    _onlineOnly = false;
  });

  void _apply() {
    ref.read(teacherSubjectFilterProvider.notifier).state = _subject;
    ref.read(teacherLevelFilterProvider.notifier).state   = _level;
    ref.read(teacherMinPriceProvider.notifier).state      = _minPrice;
    ref.read(teacherMaxPriceProvider.notifier).state      = _maxPrice;
    ref.read(teacherOnlineOnlyProvider.notifier).state    = _onlineOnly;
    Navigator.pop(context);
  }

  bool get _hasFilters =>
      _subject != null || _level != null || _minPrice > 0 ||
      _maxPrice < 2000 || _onlineOnly;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.96,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                width: 42, height: 5,
                margin: const EdgeInsets.only(top: 10, bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFD5DBE0),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
              child: Row(
                children: [
                  Text(l.filterTitle,
                      style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary)),
                  const Spacer(),
                  if (_hasFilters)
                    GestureDetector(
                      onTap: _reset,
                      child: Text(l.filterReset,
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.error,
                              fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                children: [

                  // ── Subject ───────────────────────────────────────
                  _sectionTitle(l.filterSubject),
                  const SizedBox(height: 11),
                  Wrap(
                    spacing: 9, runSpacing: 9,
                    children: _subjects.map((s) {
                      final sel = _subject == s;
                      return _chip(
                        label: translateSubject(s, Localizations.localeOf(context)),
                        selected: sel,
                        onTap: () => setState(
                            () => _subject = sel ? null : s),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // ── Level (grouped) ───────────────────────────────
                  _sectionTitle(l.filterLevel),
                  const SizedBox(height: 12),
                  ...AppLevels.groups.map((group) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(group.title,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textHint,
                              letterSpacing: 0.3)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: group.levels.map((lvl) {
                          final sel = _level == lvl;
                          return _chip(
                            label: lvl,
                            selected: sel,
                            onTap: () => setState(
                                () => _level = sel ? null : lvl),
                            small: true,
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                    ],
                  )),
                  const SizedBox(height: 8),

                  // ── Price range ───────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _sectionTitle(l.filterPriceRange),
                      Text(
                        '${_minPrice.toInt()} – ${_maxPrice >= 2000 ? "∞" : _maxPrice.toInt()}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  RangeSlider(
                    values: RangeValues(_minPrice, _maxPrice),
                    min: 0, max: 2000, divisions: 40,
                    activeColor: AppColors.primary,
                    inactiveColor: AppColors.borderStrong,
                    onChanged: (v) => setState(() {
                      _minPrice = v.start;
                      _maxPrice = v.end;
                    }),
                  ),
                  const SizedBox(height: 24),

                  // ── Online only ───────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderStrong),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(l.filterOnlineOnly,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary)),
                        ),
                        Switch(
                          value: _onlineOnly,
                          onChanged: (v) =>
                              setState(() => _onlineOnly = v),
                          activeThumbColor: AppColors.primary,
                          activeTrackColor: AppColors.accentLight,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  AppButton(
                    label: l.filterShowResults,
                    onTap: _apply,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool small = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: EdgeInsets.symmetric(
            horizontal: small ? 12 : 15,
            vertical: small ? 7 : 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: selected ? AppColors.primary : AppColors.borderStrong),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: small ? 12 : 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textPrimary)),
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(t,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary));
}
