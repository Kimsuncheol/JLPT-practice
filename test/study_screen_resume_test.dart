import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/app/theme/app_theme.dart';
import 'package:jlpt_practice/core/utils/system_bar_metrics.dart';
import 'package:jlpt_practice/data/models/app_state.dart';
import 'package:jlpt_practice/data/models/study_session.dart';
import 'package:jlpt_practice/data/models/vocabulary.dart';
import 'package:jlpt_practice/features/dashboard/choose_study_screen.dart';
import 'package:jlpt_practice/features/dashboard/dashboard_screen.dart';
import 'package:jlpt_practice/features/vocabulary/study_finish_screen.dart';
import 'package:jlpt_practice/features/vocabulary/study_screen.dart';

void main() {
  for (final theme in {
    'light': AppTheme.light(),
    'dark': AppTheme.dark(),
  }.entries) {
    testWidgets(
      'resume modal matches ${theme.key} system bars to its backdrop',
      (tester) async {
        final container = _createContainer();
        addTearDown(container.dispose);
        addTearDown(() => SystemBarMetrics.outerBackgroundColor.value = null);
        await container.read(appControllerProvider.future);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: theme.value,
              home: const StudyScreen(day: 1),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final backgroundColor = theme.value.scaffoldBackgroundColor;
        final dimmedBackground = Color.alphaBlend(
          Colors.black54,
          backgroundColor,
        );
        var overlayStyle = _studyOverlayStyle(tester);
        expect(overlayStyle.statusBarColor, dimmedBackground);
        expect(overlayStyle.systemStatusBarContrastEnforced, isFalse);
        expect(overlayStyle.systemNavigationBarColor, dimmedBackground);
        expect(overlayStyle.systemNavigationBarDividerColor, dimmedBackground);
        expect(overlayStyle.systemNavigationBarContrastEnforced, isFalse);
        expect(SystemBarMetrics.outerBackgroundColor.value, dimmedBackground);

        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        overlayStyle = _studyOverlayStyle(tester);
        expect(overlayStyle.statusBarColor, backgroundColor);
        expect(overlayStyle.systemStatusBarContrastEnforced, isFalse);
        expect(overlayStyle.systemNavigationBarColor, backgroundColor);
        expect(overlayStyle.systemNavigationBarDividerColor, backgroundColor);
        expect(overlayStyle.systemNavigationBarContrastEnforced, isFalse);
        expect(SystemBarMetrics.outerBackgroundColor.value, isNull);
      },
    );
  }

  testWidgets('study screen keeps the system navigation bar visible', (
    tester,
  ) async {
    final platformCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        platformCalls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final container = _createContainer();
    addTearDown(container.dispose);
    await container.read(appControllerProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: StudyScreen(day: 1)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      platformCalls.where(
        (call) =>
            call.method == 'SystemChrome.setEnabledSystemUIMode' &&
            call.arguments == SystemUiMode.edgeToEdge.toString(),
      ),
      hasLength(1),
    );
  });

  testWidgets('direct study-day route waits for state before prompting', (
    tester,
  ) async {
    final container = _createContainer();
    addTearDown(container.dispose);
    final router = _createRouter(initialLocation: '/study/day/1');
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Continue your recent session?'), findsOneWidget);
    expect(find.text('1 / 5'), findsOneWidget);
  });

  testWidgets('asks inside study screen before restoring the saved word', (
    tester,
  ) async {
    final container = _createContainer();
    addTearDown(container.dispose);
    await container.read(appControllerProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: StudyScreen(day: 1)),
      ),
    );
    await tester.pumpAndSettle();

    final controller =
        container.read(appControllerProvider.notifier) as _ResumeAppController;
    expect(find.text('Continue your recent session?'), findsOneWidget);
    expect(find.text('1 / 5'), findsOneWidget);
    expect(find.text('単語1'), findsOneWidget);
    expect(controller.savedSessions, isEmpty);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Continue your recent session?'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Continue your recent session?'), findsNothing);
    expect(find.text('3 / 5'), findsOneWidget);
    expect(find.text('単語3'), findsOneWidget);
    expect(controller.savedSessions.last.wordId, 'word_2');
  });

  testWidgets(
    'dashboard opens study before prompting and decline chooses day',
    (tester) async {
      final container = _createContainer();
      addTearDown(container.dispose);
      await container.read(appControllerProvider.future);
      final router = _createRouter();
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Study'));
      await tester.pumpAndSettle();

      expect(find.text('Resume learning'), findsOneWidget);
      await tester.tap(find.text('Resume learning'));
      await tester.pumpAndSettle();

      expect(find.text('Continue your recent session?'), findsOneWidget);
      expect(find.text('1 / 5'), findsOneWidget);
      expect(find.text('単語1'), findsOneWidget);
      expect(find.text('Choose another day'), findsOneWidget);

      await tester.tap(find.text('Choose another day'));
      await tester.pumpAndSettle();

      expect(find.text('Day selection'), findsOneWidget);
      final state = container.read(appControllerProvider).requireValue;
      expect(state.studySessions['N5']!.wordId, 'word_2');
    },
  );

  testWidgets('opening another day starts fresh without a resume prompt', (
    tester,
  ) async {
    final container = _createContainer();
    addTearDown(container.dispose);
    await container.read(appControllerProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: StudyScreen(day: 2)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Continue your recent session?'), findsNothing);
    expect(find.text('1 / 5'), findsOneWidget);
    expect(find.text('単語6'), findsOneWidget);
    final controller =
        container.read(appControllerProvider.notifier) as _ResumeAppController;
    expect(controller.savedSessions.last.day, 2);
    expect(controller.savedSessions.last.wordId, 'word_5');
  });

  testWidgets('finishing asks for confirmation before clearing the session', (
    tester,
  ) async {
    final container = _createContainer(wordId: 'word_4', indexFallback: 4);
    addTearDown(container.dispose);
    await container.read(appControllerProvider.future);
    final router = _createRouter(initialLocation: '/study/day/1');
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('5 / 5'), findsOneWidget);

    final pageView = find.byType(PageView);
    await tester.drag(pageView, Offset(-tester.getSize(pageView).width, 0));
    await tester.pumpAndSettle();

    expect(find.text('Great work!'), findsOneWidget);
    await tester.tap(find.text('Finish this session'));
    await tester.pumpAndSettle();

    expect(find.text('Finish this study session?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Finish this study session?'), findsNothing);
    expect(find.text('Great work!'), findsOneWidget);
  });
}

SystemUiOverlayStyle _studyOverlayStyle(WidgetTester tester) {
  return tester
      .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      )
      .singleWhere((region) => region.value.systemNavigationBarColor != null)
      .value;
}

GoRouter _createRouter({String initialLocation = '/'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => const Scaffold(body: DashboardScreen()),
    ),
    GoRoute(
      path: '/study/choose',
      builder: (_, _) => const ChooseStudyScreen(),
    ),
    GoRoute(
      path: '/study',
      builder: (_, _) => const Scaffold(body: Text('Day selection')),
    ),
    GoRoute(
      path: '/study/day/:day',
      builder: (_, state) =>
          StudyScreen(day: int.parse(state.pathParameters['day']!)),
    ),
    GoRoute(
      path: '/study/day/:day/finish',
      builder: (_, state) =>
          StudyFinishScreen(day: int.parse(state.pathParameters['day']!)),
    ),
  ],
);

ProviderContainer _createContainer({
  String wordId = 'word_2',
  int indexFallback = 2,
}) => ProviderContainer(
  overrides: [
    appControllerProvider.overrideWith(
      () => _ResumeAppController(wordId, indexFallback),
    ),
  ],
);

class _ResumeAppController extends AppController {
  _ResumeAppController(this.wordId, this.indexFallback);

  final String wordId;
  final int indexFallback;
  final List<StudySession> savedSessions = [];

  @override
  Future<AppState> build() async {
    return AppState(
      vocabulary: List.generate(10, _word),
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
      studySessions: {
        'N5': StudySession(
          level: 'N5',
          day: 1,
          wordId: wordId,
          indexFallback: indexFallback,
          dailyGoal: 5,
          updatedAt: DateTime.utc(2026, 8, 2),
        ),
      },
    );
  }

  @override
  Future<void> saveStudySession(StudySession session) async {
    savedSessions.add(session);
    final current = state.requireValue;
    state = AsyncData(
      current.copyWith(
        studySessions: {...current.studySessions, session.level: session},
      ),
    );
  }
}

Vocabulary _word(int index) => Vocabulary(
  id: 'word_$index',
  word: '単語${index + 1}',
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
