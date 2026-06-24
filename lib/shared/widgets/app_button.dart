import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool isLoading;
  final bool isOutlined;
  final bool isDanger;
  final Color? color;
  final Color? textColor;
  final double? width;
  final EdgeInsets? padding;
  final Widget? leading;

  const AppButton({
    super.key,
    required this.label,
    this.onTap,
    this.isLoading = false,
    this.isOutlined = false,
    this.isDanger = false,
    this.color,
    this.textColor,
    this.width,
    this.padding,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = !isLoading && onTap == null;

    final bg = disabled
        ? const Color(0xFFCDD5DB)
        : isDanger
            ? AppColors.error
            : isOutlined
                ? Colors.transparent
                : (color ?? AppColors.primary);

    final fg = disabled
        ? const Color(0xFF8A96A3)
        : isDanger
            ? Colors.white
            : isOutlined
                ? (textColor ?? AppColors.textSecondary)
                : Colors.white;

    return SizedBox(
      width: width ?? double.infinity,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: padding ?? const EdgeInsets.symmetric(vertical: 16),
            decoration: isOutlined
                ? BoxDecoration(
                    border: Border.all(color: AppColors.borderStrong),
                    borderRadius: BorderRadius.circular(14),
                  )
                : BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: disabled || isOutlined
                        ? null
                        : [
                            BoxShadow(
                              color: bg.withValues(alpha: 0.35),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                  ),
            child: isLoading
                ? Center(
                    child: SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                        color: fg, strokeWidth: 2.5,
                      ),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (leading != null) ...[leading!, const SizedBox(width: 8)],
                      Text(
                        label,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: fg,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
