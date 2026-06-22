import 'package:flutter/material.dart';
import '../../core/constants/session_states.dart';
import '../../core/extensions/l10n_extension.dart';

class SessionStatusBadge extends StatelessWidget {
  final SessionState state;
  final bool large;

  const SessionStatusBadge({super.key, required this.state, this.large = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 14 : 10,
        vertical: large ? 6 : 4,
      ),
      decoration: BoxDecoration(
        color: state.bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        state.localizedLabel(context.l10n),
        style: TextStyle(
          fontSize: large ? 12 : 11,
          fontWeight: FontWeight.w700,
          color: state.color,
        ),
      ),
    );
  }
}
