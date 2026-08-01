import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/data/models/app_state.dart';
import 'package:jlpt_practice/data/models/vocabulary.dart';
import 'package:jlpt_practice/features/vocabulary/day_selection_screen.dart';

void main() {
  testWidgets('day grid does not overflow on a compact phone', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appControllerProvider.overrideWith(_FakeAppController.new)],
        child: const MaterialApp(home: DaySelectionScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Day 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeAppController extends AppController {
  @override
  Future<AppState> build() async {
    return AppState(
      vocabulary: List.generate(40, _word),
      progress: const {},
      onboardingComplete: true,
      selectedLevel: 'N5',
      languageCode: 'system',
      meaningLanguage: 'en',
      dailyGoal: 5,
      showFurigana: true,
      autoPlayAudio: false,
      themeMode: ThemeMode.system,
      notificationsEnabled: false,
      studySeconds: 0,
      quizAnswered: 0,
      quizCorrect: 0,
      currentStreak: 0,
      longestStreak: 0,
    );
  }
}

Vocabulary _word(int index) => Vocabulary(
  id: 'word_$index',
  word: '単語',
  reading: 'たんご',
  furigana: 'たんご',
  romaji: 'tango',
  meanings: const {
    'en': ['word'],
  },
  partOfSpeech: 'word',
  jlptLevel: 'N5',
  tags: const ['JLPT'],
  example: const VocabularyExample(
    sentence: '',
    reading: '',
    translations: {},
    quizSentence: '',
    answer: '',
  ),
  rank: index + 1,
);
