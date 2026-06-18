import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

enum BannerType { info, warning, success, error }

class InfoBanner extends StatelessWidget {
  final String text;
  final BannerType type;

  const InfoBanner({super.key, required this.text, this.type = BannerType.warning});

  Color get _bg {
    switch (type) {
      case BannerType.info:    return AppColors.statusApprovedBg;
      case BannerType.warning: return AppColors.statusRequestedBg;
      case BannerType.success: return AppColors.statusConfirmedBg;
      case BannerType.error:   return AppColors.statusRejectedBg;
    }
  }

  Color get _iconColor {
    switch (type) {
      case BannerType.info:    return AppColors.statusApproved;
      case BannerType.warning: return AppColors.statusRequestedText;
      case BannerType.success: return AppColors.statusConfirmed;
      case BannerType.error:   return AppColors.statusRejected;
    }
  }

  Color get _textColor {
    switch (type) {
      case BannerType.info:    return AppColors.statusApprovedText;
      case BannerType.warning: return AppColors.statusRequestedText;
      case BannerType.success: return AppColors.statusConfirmedText;
      case BannerType.error:   return AppColors.statusRejectedText;
    }
  }

  IconData get _icon {
    switch (type) {
      case BannerType.info:    return Icons.info_outline_rounded;
      case BannerType.warning: return Icons.info_outline_rounded;
      case BannerType.success: return Icons.check_circle_outline_rounded;
      case BannerType.error:   return Icons.warning_amber_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, color: _iconColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 11, color: _textColor, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
