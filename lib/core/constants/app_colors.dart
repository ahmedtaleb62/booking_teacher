import 'package:flutter/material.dart';

class AppColors {
  // Brand
  static const Color primary = Color(0xFF1B6B7A);
  static const Color primaryDark = Color(0xFF11313A);
  static const Color accent = Color(0xFF7BE0C0);
  static const Color accentLight = Color(0xFFE7F1F2);

  // Background
  static const Color background = Color(0xFFF6F7F9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF1F2F4);

  // Text
  static const Color textPrimary = Color(0xFF16202C);
  static const Color textSecondary = Color(0xFF516170);
  static const Color textHint = Color(0xFF8A96A3);
  static const Color textMuted = Color(0xFFB8C0C8);

  // Border
  static const Color border = Color(0xFFEDF0F2);
  static const Color borderStrong = Color(0xFFE6E9ED);

  // Status - Session States
  static const Color statusRequested = Color(0xFFF2994A);
  static const Color statusRequestedBg = Color(0xFFFEF3E2);
  static const Color statusRequestedText = Color(0xFFC77A1A);

  static const Color statusApproved = Color(0xFF2D6CDF);
  static const Color statusApprovedBg = Color(0xFFE8F0FE);
  static const Color statusApprovedText = Color(0xFF1E468F);

  static const Color statusPaymentSubmitted = Color(0xFF7B61FF);
  static const Color statusPaymentSubmittedBg = Color(0xFFF0EDFF);
  static const Color statusPaymentSubmittedText = Color(0xFF5B43D6);

  static const Color statusConfirmed = Color(0xFF1B9E77);
  static const Color statusConfirmedBg = Color(0xFFE3F6EF);
  static const Color statusConfirmedText = Color(0xFF0F6B4E);

  static const Color statusActive = Color(0xFF16A34A);
  static const Color statusActiveBg = Color(0xFFDCFCE7);

  static const Color statusCompleted = Color(0xFF8A96A3);
  static const Color statusCompletedBg = Color(0xFFF1F2F4);

  static const Color statusRejected = Color(0xFFC0392B);
  static const Color statusRejectedBg = Color(0xFFFDECEC);
  static const Color statusRejectedText = Color(0xFF9B2D2D);

  static const Color statusDispute = Color(0xFFC0392B);
  static const Color statusDisputeBg = Color(0xFFFDECEC);

  static const Color statusNoShow = Color(0xFFC0392B);

  // Semantic
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFF2994A);
  static const Color error = Color(0xFFC0392B);
  static const Color info = Color(0xFF2D6CDF);

  // Online indicator
  static const Color online = Color(0xFF16A34A);

  // Shadow
  static Color shadow = const Color(0xFF16202C).withValues(alpha: 0.08);
}
