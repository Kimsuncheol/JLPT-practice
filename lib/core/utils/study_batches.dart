import 'dart:math';

class StudyBatches {
  const StudyBatches._();

  static int count(int wordCount, int dailyGoal) {
    if (wordCount <= 0 || dailyGoal <= 0) return 0;
    return (wordCount / dailyGoal).ceil();
  }

  static List<T> wordsForDay<T>(
    List<T> words, {
    required int day,
    required int dailyGoal,
  }) {
    if (day < 1 || dailyGoal <= 0 || words.isEmpty) return const [];
    final start = (day - 1) * dailyGoal;
    if (start >= words.length) return const [];
    return words.sublist(start, min(start + dailyGoal, words.length));
  }
}
