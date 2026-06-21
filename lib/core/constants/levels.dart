class LevelGroup {
  final String title;
  final List<String> levels;
  const LevelGroup(this.title, this.levels);
}

class AppLevels {
  static const groups = [
    LevelGroup('ابتدائية', [
      'سنة أولى ابتدائي',
      'سنة ثانية ابتدائي',
      'سنة ثالثة ابتدائي',
      'سنة رابعة ابتدائي',
      'سنة خامسة ابتدائي',
      'سنة سادسة (Concours)',
    ]),
    LevelGroup('إعدادية', [
      'سنة أولى إعدادي',
      'سنة ثانية إعدادي',
      'سنة ثالثة إعدادي',
      'سنة رابعة (Brevet)',
    ]),
    LevelGroup('ثانوية', [
      'سنة خامسة ثانوي',
      'سنة سادسة ثانوي',
      'BAC C',
      'BAC D',
      'BAC LO',
      'BAC LA',
      'BAC TGM',
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
