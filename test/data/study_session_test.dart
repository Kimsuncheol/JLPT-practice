import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/data/models/study_session.dart';

void main() {
  final session = StudySession(
    level: 'N5',
    day: 3,
    wordId: 'word_12',
    indexFallback: 2,
    dailyGoal: 10,
    updatedAt: DateTime.utc(2026, 8, 2),
  );

  test('restores by stable word id before using the saved index', () {
    expect(session.resolveIndex(['word_10', 'word_11', 'word_12']), 2);
    expect(session.resolveIndex(['word_12', 'word_10', 'word_11']), 0);
  });

  test('clamps the fallback when the saved word is unavailable', () {
    final staleSession = StudySession(
      level: 'N5',
      day: 3,
      wordId: 'removed_word',
      indexFallback: 20,
      dailyGoal: 10,
      updatedAt: DateTime.utc(2026, 8, 2),
    );

    expect(staleSession.resolveIndex(['one', 'two', 'three']), 2);
  });

  test('daily-goal changes invalidate the old batch cursor', () {
    expect(session.isCompatible(level: 'N5', dailyGoal: 10), isTrue);
    expect(session.isCompatible(level: 'N5', dailyGoal: 20), isFalse);
    expect(session.isCompatible(level: 'N4', dailyGoal: 10), isFalse);
  });

  test('round trips through JSON', () {
    final restored = StudySession.fromJson(session.toJson());

    expect(restored.level, session.level);
    expect(restored.day, session.day);
    expect(restored.wordId, session.wordId);
    expect(restored.indexFallback, session.indexFallback);
    expect(restored.dailyGoal, session.dailyGoal);
    expect(restored.updatedAt, session.updatedAt);
  });
}
