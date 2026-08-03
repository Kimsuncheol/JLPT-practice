import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/data/models/app_state.dart';
import 'package:jlpt_practice/data/models/quiz.dart';
import 'package:jlpt_practice/data/models/vocabulary.dart';
import 'package:jlpt_practice/features/quiz/quiz_result_screen.dart';
import 'package:jlpt_practice/features/test/listening_test_screen.dart';

void main() {
  testWidgets('answering all listening questions reaches the result screen', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [appControllerProvider.overrideWith(_FakeAppController.new)],
    );
    addTearDown(container.dispose);
    await container.read(appControllerProvider.future);

    final router = GoRouter(
      initialLocation: '/test/listening',
      routes: [
        GoRoute(
          path: '/test/listening',
          builder: (_, _) => const ListeningTestScreen(),
        ),
        GoRoute(
          path: '/quiz/result',
          builder: (_, _) => const QuizResultScreen(),
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

    const firstChoiceKey = ValueKey('listening_choice_0');
    for (var i = 0; i < 10; i++) {
      expect(find.byKey(firstChoiceKey), findsOneWidget);
      await tester.tap(find.byKey(firstChoiceKey));
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();
    }
    // Flush the result screen's delayed AdService.recordCompletedSession
    // call so no Timer is left pending when the test tears down.
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
    expect(find.text('Session complete'), findsOneWidget);

    final result = container
        .read(appControllerProvider)
        .requireValue
        .lastQuizResult!;
    expect(result.total, 10);
  });
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
  Future<void> recordQuizResult(
    QuizResult result,
    List<QuizQuestion> questions,
  ) async {
    state = AsyncData(state.requireValue.copyWith(lastQuizResult: result));
  }
}

Vocabulary _vocabulary(int index) => Vocabulary(
  id: 'vocab_$index',
  word: '単語$index',
  reading: 'たんご$index',
  furigana: 'たんご$index',
  romaji: 'tango$index',
  meanings: {
    'en': ['meaning $index'],
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
