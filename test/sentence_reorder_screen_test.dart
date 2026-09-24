import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/data/models/app_state.dart';
import 'package:jlpt_practice/data/models/vocabulary.dart';
import 'package:jlpt_practice/features/vocabulary/sentence_reorder_screen.dart';

void main() {
  testWidgets('day game accepts ordered taps and shows a result', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        appControllerProvider.overrideWith(_ReorderTestController.new),
      ],
    );
    addTearDown(container.dispose);
    await container.read(appControllerProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SentenceReorderScreen(day: 1)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('문장 뜻'), findsNothing);
    for (var index = 0; index < 3; index++) {
      await tester.tap(find.byKey(ValueKey('available-$index')));
      await tester.pump();
    }
    await tester.tap(find.text('Check answer'));
    await tester.pump();
    expect(find.text('Correct'), findsOneWidget);
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.text('1 / 1'), findsOneWidget);
  });

  testWidgets('X asks before leaving and cancel keeps the game', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        appControllerProvider.overrideWith(_ReorderTestController.new),
      ],
    );
    addTearDown(container.dispose);
    await container.read(appControllerProvider.future);
    final router = _gameRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    router.push('/reorder');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Leave the quiz?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Put the sentence in order'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Leave the quiz?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave'));
    await tester.pumpAndSettle();
    expect(find.text('Quiz selection'), findsOneWidget);
  });

  testWidgets('correct answer advances automatically after feedback', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        appControllerProvider.overrideWith(_ReorderTestController.new),
      ],
    );
    addTearDown(container.dispose);
    await container.read(appControllerProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SentenceReorderScreen(day: 1)),
      ),
    );
    await tester.pumpAndSettle();
    for (var index = 0; index < 3; index++) {
      await tester.tap(find.byKey(ValueKey('available-$index')));
      await tester.pump();
    }
    await tester.tap(find.text('Check answer'));
    await tester.pump();
    expect(find.text('Correct'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2499));
    expect(find.text('Correct'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('1 / 1'), findsOneWidget);
    expect(find.text('Correct'), findsNothing);
  });

  testWidgets('leave dialog pauses automatic advance', (tester) async {
    final container = ProviderContainer(
      overrides: [
        appControllerProvider.overrideWith(_ReorderTestController.new),
      ],
    );
    addTearDown(container.dispose);
    await container.read(appControllerProvider.future);
    final router = _gameRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    router.push('/reorder');
    await tester.pumpAndSettle();
    for (var index = 0; index < 3; index++) {
      await tester.tap(find.byKey(ValueKey('available-$index')));
      await tester.pump();
    }
    await tester.tap(find.text('Check answer'));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Leave the quiz?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(find.text('Correct'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2500));
    expect(find.text('1 / 1'), findsOneWidget);
  });
}

GoRouter _gameRouter() => GoRouter(
  initialLocation: '/selection',
  routes: [
    GoRoute(
      path: '/selection',
      builder: (_, _) => const Scaffold(body: Text('Quiz selection')),
    ),
    GoRoute(
      path: '/reorder',
      builder: (_, _) => const SentenceReorderScreen(day: 1),
    ),
  ],
);

class _ReorderTestController extends AppController {
  @override
  Future<AppState> build() async => const AppState(
    vocabulary: [
      Vocabulary(
        id: 'one',
        word: '行く',
        reading: 'いく',
        furigana: '行く',
        romaji: '',
        meanings: {
          'ko': ['가다'],
        },
        partOfSpeech: 'verb',
        jlptLevel: 'N5',
        tags: [],
        example: VocabularyExample(
          sentence: '私は行く。',
          reading: 'わたしはいく。',
          translations: {'ko': '문장 뜻'},
          quizSentence: '',
          answer: '',
          tokens: ['私', 'は', '行く'],
        ),
      ),
    ],
    progress: {},
    onboardingComplete: true,
    selectedLevel: 'N5',
    languageCode: 'en',
    meaningLanguageMode: 'ko',
    meaningLanguage: 'ko',
    dailyGoal: 1,
    showFurigana: true,
    autoPlayAudio: false,
    themeMode: ThemeMode.light,
    hideMeanings: true,
    notificationsEnabled: false,
    studySeconds: 0,
    quizAnswered: 0,
    quizCorrect: 0,
    currentStreak: 0,
    longestStreak: 0,
  );
}
