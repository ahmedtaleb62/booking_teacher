import 'package:flutter/widgets.dart';

/// Canonical list of subjects (stored as Arabic in DB)
const List<String> kSubjects = [
  'الإنجليزية',
  'الفرنسية',
  'العربية',
  'الفلسفة',
  'التربية الإسلامية',
  'التربية المدنية',
  'العلوم الطبيعية',
  'الرياضيات',
  'الفيزياء والكيمياء',
  'التاريخ والجغرافيا',
];

const Map<String, String> _kSubjectsFr = {
  'الإنجليزية':        'Anglais',
  'الفرنسية':          'Français',
  'العربية':           'Arabe',
  'الفلسفة':           'Philosophie',
  'التربية الإسلامية': 'Éd. Islamique',
  'التربية المدنية':   'Éd. Civique',
  'العلوم الطبيعية':   'Sciences Naturelles',
  'الرياضيات':         'Mathématiques',
  'الفيزياء والكيمياء':'Physique-Chimie',
  'التاريخ والجغرافيا':'Histoire-Géo',
};

/// Returns the display name for a subject based on locale.
/// The Arabic key is the canonical value stored in DB.
String translateSubject(String arabicKey, Locale locale) {
  if (locale.languageCode == 'fr') return _kSubjectsFr[arabicKey] ?? arabicKey;
  return arabicKey;
}
