class StudySession {
  const StudySession({
    required this.level,
    required this.day,
    required this.wordId,
    required this.indexFallback,
    required this.dailyGoal,
    required this.updatedAt,
  });

  factory StudySession.fromJson(Map<String, dynamic> json) {
    return StudySession(
      level: json['level'] as String,
      day: json['day'] as int,
      wordId: json['wordId'] as String,
      indexFallback: json['indexFallback'] as int,
      dailyGoal: json['dailyGoal'] as int,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  final String level;
  final int day;
  final String wordId;
  final int indexFallback;
  final int dailyGoal;
  final DateTime updatedAt;

  bool isCompatible({required String level, required int dailyGoal}) =>
      this.level == level && this.dailyGoal == dailyGoal && day > 0;

  int resolveIndex(List<String> wordIds) {
    if (wordIds.isEmpty) return 0;
    final savedWordIndex = wordIds.indexOf(wordId);
    if (savedWordIndex >= 0) return savedWordIndex;
    return indexFallback.clamp(0, wordIds.length - 1);
  }

  Map<String, dynamic> toJson() => {
    'level': level,
    'day': day,
    'wordId': wordId,
    'indexFallback': indexFallback,
    'dailyGoal': dailyGoal,
    'updatedAt': updatedAt.toIso8601String(),
  };
}
