import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/locale_provider.dart';

/// Small AR / FR pill — place anywhere in the widget tree that has ProviderScope.
class LangToggle extends ConsumerWidget {
  final Color activeColor;
  final Color activeFg;
  final Color inactiveFg;
  final Color bg;

  const LangToggle({
    super.key,
    this.activeColor  = AppColors.primary,
    this.activeFg     = Colors.white,
    this.inactiveFg   = const Color(0xFF9DB2B8),
    this.bg           = Colors.transparent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAr = ref.watch(localeProvider).languageCode == 'ar';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Pill(
          label: 'ع',
          selected: isAr,
          activeColor: activeColor,
          activeFg: activeFg,
          inactiveFg: inactiveFg,
          onTap: () => ref.read(localeProvider.notifier).state = const Locale('ar'),
        ),
        const SizedBox(width: 6),
        _Pill(
          label: 'FR',
          selected: !isAr,
          activeColor: activeColor,
          activeFg: activeFg,
          inactiveFg: inactiveFg,
          onTap: () => ref.read(localeProvider.notifier).state = const Locale('fr'),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final Color activeColor;
  final Color activeFg;
  final Color inactiveFg;
  final VoidCallback onTap;

  const _Pill({
    required this.label,
    required this.selected,
    required this.activeColor,
    required this.activeFg,
    required this.inactiveFg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? activeColor : Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? activeFg : inactiveFg,
          ),
        ),
      ),
    );
  }
}
