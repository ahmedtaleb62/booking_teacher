import 'package:flutter/material.dart';
import 'package:teacher_booking/l10n/app_localizations.dart';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
  bool get isArabic => Localizations.localeOf(this).languageCode == 'ar';
}
