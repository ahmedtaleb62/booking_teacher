import 'package:flutter/widgets.dart';

class LevelGroup {
  final String title;
  final List<String> levels;
  const LevelGroup(this.title, this.levels);
}

const Map<String, String> _kGroupsFr = {
  'ابتدائية':                  'Primaire',
  'إعدادية':                   'Collège',
  'ثانوية — السنة 5':          'Lycée — 5ème année',
  'ثانوية — السنة 6':          'Lycée — 6ème année',
  'ثانوية — BAC (السنة 7)':    'Lycée — BAC (7ème année)',
};

const Map<String, String> _kLevelsFr = {
  '1AF — أولى أساسي':              '1AF — 1ère Fondamentale',
  '2AF — ثانية أساسي':             '2AF — 2ème Fondamentale',
  '3AF — ثالثة أساسي':             '3AF — 3ème Fondamentale',
  '4AF — رابعة أساسي':             '4AF — 4ème Fondamentale',
  '5AF — خامسة أساسي':             '5AF — 5ème Fondamentale',
  '6AF — سادسة أساسي':             '6AF — 6ème Fondamentale',
  '1AS — أولى إعدادي':             '1AS — 1ère Collège',
  '2AS — ثانية إعدادي':            '2AS — 2ème Collège',
  '3AS — ثالثة إعدادي':            '3AS — 3ème Collège',
  '4AS — رابعة إعدادي (Brevet)':   '4AS — 4ème Collège (Brevet)',
  '5C — خامسة علوم':               '5C — 5ème Sciences',
  '5D — خامسة رياضيات':            '5D — 5ème Mathématiques',
  '5LA — خامسة آداب عربية':        '5LA — 5ème Lettres Arabes',
  '5LO — خامسة آداب أصلية':        '5LO — 5ème Lettres Orig.',
  '6C — سادسة علوم':               '6C — 6ème Sciences',
  '6D — سادسة رياضيات':            '6D — 6ème Mathématiques',
  '6LO — سادسة آداب أصلية':        '6LO — 6ème Lettres Orig.',
  '6LA — سادسة آداب عربية':        '6LA — 6ème Lettres Arabes',
  '7C — سابعة علوم':               '7C — Terminale Sciences',
  '7D — سابعة رياضيات':            '7D — Terminale Maths',
  '7LO — سابعة آداب أصلية':        '7LO — Terminale Lettres Orig.',
  '7LA — سابعة آداب عربية':        '7LA — Terminale Lettres Arabes',
  '7TGM — سابعة تسيير':            '7TGM — Terminale Gestion',
};

String translateLevel(String arabicKey, Locale locale) {
  if (locale.languageCode == 'fr') return _kLevelsFr[arabicKey] ?? arabicKey;
  return arabicKey;
}

String translateLevelGroup(String arabicTitle, Locale locale) {
  if (locale.languageCode == 'fr') return _kGroupsFr[arabicTitle] ?? arabicTitle;
  return arabicTitle;
}

class AppLevels {
  static const groups = [
    LevelGroup('ابتدائية', [
      '1AF — أولى أساسي',
      '2AF — ثانية أساسي',
      '3AF — ثالثة أساسي',
      '4AF — رابعة أساسي',
      '5AF — خامسة أساسي',
      '6AF — سادسة أساسي',
    ]),
    LevelGroup('إعدادية', [
      '1AS — أولى إعدادي',
      '2AS — ثانية إعدادي',
      '3AS — ثالثة إعدادي',
      '4AS — رابعة إعدادي (Brevet)',
    ]),
    LevelGroup('ثانوية — السنة 5', [
      '5C — خامسة علوم',
      '5D — خامسة رياضيات',
      '5LA — خامسة آداب عربية',
      '5LO — خامسة آداب أصلية',
    ]),
    LevelGroup('ثانوية — السنة 6', [
      '6C — سادسة علوم',
      '6D — سادسة رياضيات',
      '6LO — سادسة آداب أصلية',
      '6LA — سادسة آداب عربية',
    ]),
    LevelGroup('ثانوية — BAC (السنة 7)', [
      '7C — سابعة علوم',
      '7D — سابعة رياضيات',
      '7LO — سابعة آداب أصلية',
      '7LA — سابعة آداب عربية',
      '7TGM — سابعة تسيير',
    ]),
  ];

  static List<String> get all =>
      groups.expand((g) => g.levels).toList();

  static String? groupOf(String level) {
    for (final g in groups) {
      if (g.levels.contains(level)) return g.title;
    }
    return null;
  }
}
