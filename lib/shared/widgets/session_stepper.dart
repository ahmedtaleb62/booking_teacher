import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/session_states.dart';

class SessionStepper extends StatelessWidget {
  final SessionState currentState;

  const SessionStepper({super.key, required this.currentState});

  static const _steps = [
    ('REQUESTED', 'طلب'),
    ('TEACHER_APPROVED', 'موافقة'),
    ('PAYMENT_CONFIRMED', 'دفع'),
    ('CONFIRMED_BOOKING', 'مؤكّد'),
    ('ACTIVE_SESSION', 'مباشر'),
  ];

  int get _currentIndex {
    final key = currentState.englishKey;
    switch (key) {
      case 'REQUESTED':         return 0;
      case 'TEACHER_APPROVED':
      case 'AWAITING_PAYMENT':
      case 'PAYMENT_SUBMITTED': return 1;
      case 'PAYMENT_CONFIRMED': return 2;
      case 'CONFIRMED_BOOKING': return 3;
      case 'ACTIVE_SESSION':    return 4;
      case 'COMPLETED':         return 5;
      default:                  return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final idx = _currentIndex;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: List.generate(_steps.length * 2 - 1, (i) {
              if (i.isOdd) {
                final stepIdx = i ~/ 2;
                final done = idx > stepIdx;
                return Expanded(
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: done ? AppColors.statusConfirmed : AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }
              final stepIdx = i ~/ 2;
              final done = idx > stepIdx;
              final active = idx == stepIdx;
              return _StepDot(done: done, active: active);
            }),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(_steps.length * 2 - 1, (i) {
              if (i.isOdd) return const Expanded(child: SizedBox());
              final stepIdx = i ~/ 2;
              final done = idx > stepIdx;
              final active = idx == stepIdx;
              final label = _steps[stepIdx].$2;
              return SizedBox(
                width: 42,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: active || done ? FontWeight.w700 : FontWeight.w500,
                    color: done
                        ? AppColors.statusConfirmed
                        : active
                            ? AppColors.primary
                            : AppColors.textMuted,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final bool done;
  final bool active;
  const _StepDot({required this.done, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26, height: 26,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done
            ? AppColors.statusConfirmed
            : active
                ? AppColors.primary
                : AppColors.surface,
        border: Border.all(
          color: done || active ? Colors.transparent : AppColors.border,
          width: 2,
        ),
        boxShadow: active
            ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.2), blurRadius: 8, spreadRadius: 2)]
            : null,
      ),
      child: (done || active)
          ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
          : null,
    );
  }
}
