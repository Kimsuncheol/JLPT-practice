import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/data/models/app_state.dart';
import 'package:jlpt_practice/data/models/grammar_point.dart';
import 'package:jlpt_practice/data/models/mock_test.dart';
import 'package:jlpt_practice/data/models/vocabulary.dart';
import 'package:jlpt_practice/features/grammar/grammar_providers.dart';
import 'package:jlpt_practice/features/test/mock_test_result_screen.dart';
import 'package:jlpt_practice/features/test/mock_test_screen.dart';

void main() {
  testWidgets(
    'answering through both sections reaches a result screen with a '
    'per-section breakdown',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          appControllerProvider.overrideWith(_FakeAppController.new),
          grammarCatalogProvider.overrideWith((ref) async => _grammarPoints),
        ],
      );
      addTearDown(container.dispose);
      await container.read(appControllerProvider.future);

      final router = GoRouter(
        initialLocation: '/test/n5',
        routes: [
          GoRoute(path: '/test/n5', builder: (_, _) => const MockTestScreen()),
          GoRoute(
            path: '/test/n5/result',
            builder: (_, _) => const MockTestResultScreen(),
          ),
          GoRoute(
            path: '/home',
            builder: (_, _) => const Scaffold(body: Text('Home')),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // 10 vocabulary questions + 10 grammar questions.
      const firstChoiceKey = ValueKey('mock_test_choice_0');
      for (var i = 0; i < 20; i++) {
        expect(find.byKey(firstChoiceKey), findsOneWidget);
        await tester.tap(find.byKey(firstChoiceKey));
        await tester.pump(const Duration(milliseconds: 1500));
        await tester.pumpAndSettle();
      }
      // Flush the result screen's delayed AdService.recordCompletedSession
      // call so no Timer is left pending when the test tears down.
      await tester.pump(const Duration(seconds: 1));

      expect(tester.takeException(), isNull);
      expect(find.text('Test complete'), findsOneWidget);
      expect(find.text('Section results'), findsOneWidget);
      expect(find.text('Vocabulary'), findsOneWidget);
      expect(find.text('Grammar'), findsOneWidget);

      final result = container
          .read(appControllerProvider)
          .requireValue
          .lastMockTestResult!;
      expect(result.total, 20);
      expect(
        result.sectionFor(TestSectionType.vocabulary)!.total,
        10,
      );
      expect(result.sectionFor(TestSectionType.grammar)!.total, 10);
    },
  );
}

class _FakeAppController extends AppController {
  @override
  Future<AppState> build() async {
    return AppState(
      vocabulary: List.generate(10, _vocabulary),
      progress: const {},
      onboardingComplete: true,
      selectedLevel: 'N5',
      languageCode: 'system',
      meaningLanguage: 'en',
      dailyGoal: 10,
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

  @override
  Future<void> recordMockTestResult(
    MockTestResult result, {
    required List<dynamic> vocabularyQuestions,
  }) async {
    state = AsyncData(state.requireValue.copyWith(lastMockTestResult: result));
  }
}

Vocabulary _vocabulary(int index) => Vocabulary(
  id: 'vocab_$index',
  word: '単語$index',
  reading: 'たんご$index',
  furigana: 'たんご$index',
  romaji: 'tango$index',
  meanings: {
    'en': ['word $index'],
  },
  partOfSpeech: 'word',
  jlptLevel: 'N5',
  tags: const ['JLPT'],
  example: VocabularyExample(
    sentence: '文$index。',
    reading: '',
    translations: {'en': 'Sentence $index.'},
    quizSentence: '文＿＿。',
    answer: 'こたえ$index',
  ),
);

final _grammarPoints = List.generate(
  10,
  (index) => GrammarPoint(
    id: 'N5_grammar_$index',
    level: 'N5',
    rank: index,
    title: '文法$index',
    summary: 'Grammar meaning $index',
    explanation: 'Explanation $index',
    formation: 'Formation $index',
    summaryKo: '문법 뜻 $index',
    examples: [
      GrammarExample(
        japanese: '例文$index',
        romaji: 'reibun$index',
        english: 'Example $index',
      ),
    ],
  ),
);
