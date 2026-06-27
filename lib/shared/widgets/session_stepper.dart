import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/session_states.dart';
import '../../core/extensions/l10n_extension.dart';

class SessionStepper extends StatelessWidget {
  final SessionState currentState;

  const SessionStepper({super.key, required this.currentState});

  List<String> _labels(BuildContext context) {
    final l = context.l10n;
    return [l.stepRequest, l.stepApproval, l.stepPayment, l.stepConfirmed, l.stepActive];
  }

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
    final idx    = _currentIndex;
    final labels = _labels(context);
    final count  = labels.length;
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
            children: List.generate(count * 2 - 1, (i) {
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
            children: List.generate(count * 2 - 1, (i) {
              if (i.isOdd) return const Expanded(child: SizedBox());
              final stepIdx = i ~/ 2;
              final done = idx > stepIdx;
              final active = idx == stepIdx;
              return SizedBox(
                width: 42,
                child: Text(
                  labels[stepIdx],
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
