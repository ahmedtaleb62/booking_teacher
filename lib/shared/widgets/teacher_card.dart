import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/teacher.dart';

class TeacherCard extends StatelessWidget {
  final Teacher teacher;
  final VoidCallback onTap;

  const TeacherCard({super.key, required this.teacher, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Avatar(initial: teacher.initial, isOnline: teacher.isOnline, avatarUrl: teacher.avatarUrl),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          teacher.name,
                          style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (teacher.isOnline)
                        Row(
                          children: [
                            Container(
                              width: 7, height: 7,
                              decoration: const BoxDecoration(
                                color: AppColors.online,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text(
                              'متصل',
                              style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w600,
                                color: AppColors.online,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    teacher.subject,
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 3),
                      Text(
                        teacher.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '(${teacher.reviewCount} تقييم)',
                        style: const TextStyle(fontSize: 11, color: AppColors.textHint),
                      ),
                      const Spacer(),
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: '${teacher.pricePerHour.toInt()}',
                              style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            const TextSpan(
                              text: ' أوقية/س',
                              style: TextStyle(
                                fontSize: 10, color: AppColors.textHint,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String initial;
  final bool isOnline;
  final String? avatarUrl;

  const _Avatar({required this.initial, required this.isOnline, this.avatarUrl});

  static const List<Color> _avatarColors = [
    Color(0xFF1B6B7A), Color(0xFF7B61FF), Color(0xFF2D6CDF),
    Color(0xFF1B9E77), Color(0xFFF2994A),
  ];

  Color get _color => _avatarColors[initial.codeUnitAt(0) % _avatarColors.length];

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 54, height: 54,
          decoration: BoxDecoration(
            color: _color,
            borderRadius: BorderRadius.circular(14),
            image: avatarUrl != null
                ? DecorationImage(image: NetworkImage(avatarUrl!), fit: BoxFit.cover)
                : null,
          ),
          alignment: Alignment.center,
          child: avatarUrl == null
              ? Text(initial,
                  style: const TextStyle(
                    color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700,
                  ))
              : null,
        ),
        if (isOnline)
          Positioned(
            bottom: 2, right: 2,
            child: Container(
              width: 11, height: 11,
              decoration: BoxDecoration(
                color: AppColors.online,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
            ),
          ),
      ],
    );
  }
}
