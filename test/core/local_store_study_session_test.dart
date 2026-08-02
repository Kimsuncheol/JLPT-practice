import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/core/services/local_store.dart';
import 'package:jlpt_practice/data/models/study_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('persists resumable study sessions by JLPT level', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.create();
    final session = StudySession(
      level: 'N5',
      day: 4,
      wordId: 'word_33',
      indexFallback: 3,
      dailyGoal: 10,
      updatedAt: DateTime.utc(2026, 8, 2),
    );

    await store.saveStudySessions({'N5': session});
    final restored = (await LocalStore.create()).loadStudySessions()['N5'];

    expect(restored, isNotNull);
    expect(restored!.day, 4);
    expect(restored.wordId, 'word_33');
    expect(restored.indexFallback, 3);
  });

  test('learning-data reset removes resumable sessions', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.create();
    await store.saveStudySessions({
      'N5': StudySession(
        level: 'N5',
        day: 1,
        wordId: 'word_1',
        indexFallback: 0,
        dailyGoal: 10,
        updatedAt: DateTime.utc(2026, 8, 2),
      ),
    });

    await store.clearLearningData();

    expect(store.loadStudySessions(), isEmpty);
  });

  test('ignores malformed resumable-session data', () async {
    SharedPreferences.setMockInitialValues({'studySessions': '{bad json'});
    final store = await LocalStore.create();

    expect(store.loadStudySessions(), isEmpty);
  });
}
