import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/core/utils/study_batches.dart';

void main() {
  test('calculates the number of daily batches', () {
    expect(StudyBatches.count(718, 10), 72);
    expect(StudyBatches.count(668, 20), 34);
    expect(StudyBatches.count(0, 10), 0);
  });

  test('returns the correct words for a day', () {
    final words = List.generate(23, (index) => index + 1);

    expect(
      StudyBatches.wordsForDay(words, day: 1, dailyGoal: 10),
      List.generate(10, (index) => index + 1),
    );
    expect(StudyBatches.wordsForDay(words, day: 3, dailyGoal: 10), [
      21,
      22,
      23,
    ]);
  });
}
