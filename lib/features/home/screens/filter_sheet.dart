import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_button.dart';

class FilterSheet extends StatefulWidget {
  const FilterSheet({super.key});
  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  String? _selectedSubject;
  double _minPrice = 200;
  double _maxPrice = 700;
  double _minRating = 4.0;
  bool _onlineOnly = true;

  static const _subjects = ['رياضيات', 'فيزياء', 'كيمياء', 'عربية', 'إنجليزية', 'علوم', 'تاريخ', 'جغرافيا'];
  static const _ratings  = [4.0, 4.5, 4.8, 5.0];

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      maxChildSize: 0.95,
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
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('تصفية النتائج',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  GestureDetector(
                    onTap: () => setState(() {
                      _selectedSubject = null;
                      _minPrice = 200;
                      _maxPrice = 700;
                      _minRating = 4.0;
                      _onlineOnly = false;
                    }),
                    child: const Text('إعادة تعيين',
                      style: TextStyle(fontSize: 13, color: AppColors.textHint, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                children: [
                  // Subject filter
                  _sectionTitle('المادة'),
                  const SizedBox(height: 11),
                  Wrap(
                    spacing: 9, runSpacing: 9,
                    children: _subjects.map((s) {
                      final sel = _selectedSubject == s;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedSubject = sel ? null : s),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
                          decoration: BoxDecoration(
                            color: sel ? AppColors.primary : AppColors.surface,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: sel ? AppColors.primary : AppColors.borderStrong),
                          ),
                          child: Text(s,
                            style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: sel ? Colors.white : AppColors.textPrimary,
                            )),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Price range
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _sectionTitle('نطاق السعر (أوقية/ساعة)'),
                      Text(
                        '${_minPrice.toInt()} – ${_maxPrice.toInt()}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  RangeSlider(
                    values: RangeValues(_minPrice, _maxPrice),
                    min: 100, max: 1000, divisions: 18,
                    activeColor: AppColors.primary,
                    inactiveColor: AppColors.borderStrong,
                    onChanged: (v) => setState(() {
                      _minPrice = v.start;
                      _maxPrice = v.end;
                    }),
                  ),
                  const SizedBox(height: 24),

                  // Rating filter
                  _sectionTitle('الحد الأدنى للتقييم'),
                  const SizedBox(height: 11),
                  Row(
                    children: _ratings.map((r) {
                      final sel = _minRating == r;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _minRating = r),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              decoration: BoxDecoration(
                                color: sel ? AppColors.primary : AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: sel ? AppColors.primary : AppColors.borderStrong),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.star_rounded, size: 14,
                                    color: sel ? Colors.white : const Color(0xFFF59E0B)),
                                  const SizedBox(width: 3),
                                  Text(r == r.truncateToDouble() ? '${r.toInt()}+' : '$r+',
                                    style: TextStyle(
                                      fontSize: 13, fontWeight: FontWeight.w700,
                                      color: sel ? Colors.white : AppColors.textPrimary,
                                    )),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),

                  // Online only toggle
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.borderStrong),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text('المتاحون الآن فقط',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                        ),
                        Switch(
                          value: _onlineOnly,
                          onChanged: (v) => setState(() => _onlineOnly = v),
                          activeThumbColor: AppColors.primary,
                          activeTrackColor: AppColors.accentLight,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  AppButton(
                    label: 'عرض النتائج',
                    onTap: () => Navigator.pop(context),
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

  Widget _sectionTitle(String t) => Text(
    t,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
  );
}
