import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/app/theme/app_theme.dart';
import 'package:jlpt_practice/data/models/study_session.dart';
import 'package:jlpt_practice/data/repositories/kanji_repository.dart';
import 'package:jlpt_practice/features/dashboard/recent_study_card.dart';
import 'package:jlpt_practice/features/kanji/kanji_finish_screen.dart';
import 'package:jlpt_practice/features/kanji/kanji_study_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/kanji_test_support.dart';

StudySession _session({
  int day = 1,
  String wordId = 'N5-二',
  int index = 1,
  int dailyGoal = 2,
  DateTime? updatedAt,
}) => StudySession(
  level: 'kanji-N5',
  day: day,
  wordId: wordId,
  indexFallback: index,
  dailyGoal: dailyGoal,
  updatedAt: updatedAt ?? DateTime.utc(2026, 9, 30),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('saving and resuming a kanji day', () {
    testWidgets('opening a day saves its first kanji under the kanji key', (
      tester,
    ) async {
      final controller = KanjiTestAppController();
      await _pumpStudy(tester, controller);

      final saved = controller.savedSessions.single;
      expect(saved.level, 'kanji-N5');
      expect(saved.day, 1);
      expect(saved.wordId, 'N5-一');
      expect(saved.indexFallback, 0);
      expect(saved.dailyGoal, 2);
    });

    testWidgets('moving to the next kanji saves the new position', (
      tester,
    ) async {
      final controller = KanjiTestAppController();
      await _pumpStudy(tester, controller);
      await _flipAndSwipe(tester);

      expect(controller.savedSessions.last.wordId, 'N5-二');
      expect(controller.savedSessions.last.indexFallback, 1);
    });

    testWidgets('reopening the same day continues where it was left', (
      tester,
    ) async {
      await _pumpStudy(
        tester,
        KanjiTestAppController(sessions: {'kanji-N5': _session()}),
      );

      expect(find.text('2 / 2'), findsOneWidget);
    });

    testWidgets('a saved position on another day is ignored', (tester) async {
      await _pumpStudy(
        tester,
        KanjiTestAppController(sessions: {'kanji-N5': _session(day: 2)}),
      );

      expect(find.text('1 / 2'), findsOneWidget);
    });

    testWidgets('a saved position under another daily goal is ignored', (
      tester,
    ) async {
      await _pumpStudy(
        tester,
        KanjiTestAppController(sessions: {'kanji-N5': _session(dailyGoal: 5)}),
      );

      expect(find.text('1 / 2'), findsOneWidget);
    });
  });

  group('leaving a kanji day', () {
    testWidgets('the back button asks first and Cancel stays', (tester) async {
      await _pumpStudy(tester, KanjiTestAppController(), viaHome: true);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Leave kanji study?'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Leave kanji study?'), findsNothing);
      expect(find.text('1 / 2'), findsOneWidget);
    });

    testWidgets('confirming leaves the screen', (tester) async {
      await _pumpStudy(tester, KanjiTestAppController(), viaHome: true);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Leave'));
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('1 / 2'), findsNothing);
    });

    testWidgets('the system back gesture asks too', (tester) async {
      await _pumpStudy(tester, KanjiTestAppController(), viaHome: true);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Leave kanji study?'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
    });

    testWidgets('leaving keeps the saved position for recent study', (
      tester,
    ) async {
      final controller = KanjiTestAppController();
      await _pumpStudy(tester, controller, viaHome: true);
      await _flipAndSwipe(tester);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Leave'));
      await tester.pumpAndSettle();

      expect(controller.savedSessions.last.wordId, 'N5-二');
      expect(controller.completions, isEmpty);
    });

    testWidgets('finishing the day does not ask', (tester) async {
      await _pumpStudy(
        tester,
        KanjiTestAppController(sessions: {'kanji-N5': _session()}),
        viaHome: true,
      );
      await _flipAndSwipe(tester, swipe: false);
      await tester.drag(
        find.byKey(const ValueKey('kanji-pages')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();

      expect(find.text('Leave kanji study?'), findsNothing);
    });
  });

  group('recent study on the home screen', () {
    testWidgets('shows the kanji day the learner left part-way', (
      tester,
    ) async {
      await _pumpRecent(
        tester,
        KanjiTestAppController(sessions: {'kanji-N5': _session()}),
      );

      expect(find.text('Kanji · N5'), findsOneWidget);
      expect(find.text('Day 1'), findsOneWidget);
      expect(find.text('2 of 2 kanji'), findsOneWidget);
      expect(find.text('漢'), findsOneWidget);
    });

    testWidgets('is hidden without a kanji session', (tester) async {
      await _pumpRecent(tester, KanjiTestAppController());

      expect(find.text('RECENT STUDY'), findsNothing);
      expect(find.textContaining('Kanji'), findsNothing);
    });

    testWidgets('ignores a session made under another daily goal', (
      tester,
    ) async {
      await _pumpRecent(
        tester,
        KanjiTestAppController(sessions: {'kanji-N5': _session(dailyGoal: 5)}),
      );

      expect(find.text('RECENT STUDY'), findsNothing);
    });

    testWidgets('tapping it opens the kanji day list, then the kanji day', (
      tester,
    ) async {
      final router = await _pumpRecent(
        tester,
        KanjiTestAppController(sessions: {'kanji-N5': _session(day: 2)}),
      );

      await tester.tap(find.byKey(const ValueKey('recent-study-/kanji/day/2')));
      await tester.pumpAndSettle();

      expect(find.text('Kanji study day 2'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('Kanji day list'), findsOneWidget);
    });

    testWidgets('finishing the day clears it from recent study', (
      tester,
    ) async {
      final controller = KanjiTestAppController(
        sessions: {'kanji-N5': _session()},
      );
      await _pumpStudy(tester, controller);
      await _flipAndSwipe(tester, swipe: false);
      await tester.drag(
        find.byKey(const ValueKey('kanji-pages')),
        const Offset(-500, 0),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();

      expect(controller.completions, [('kanji-N5', 1)]);
    });
  });
}

Future<void> _flipAndSwipe(WidgetTester tester, {bool swipe = true}) async {
  final face = tester.getRect(find.byKey(const ValueKey('kanji-front')));
  await tester.tapAt(face.topCenter + const Offset(0, 24));
  await tester.pumpAndSettle();
  if (!swipe) return;
  await tester.drag(
    find.byKey(const ValueKey('kanji-pages')),
    const Offset(-500, 0),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpStudy(
  WidgetTester tester,
  KanjiTestAppController controller, {
  bool viaHome = false,
}) async {
  const volume = MethodChannel('com.kurenai7968.volume_controller.method');
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    volume,
    (call) async => call.method == 'isMuted' ? false : 0.8,
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      volume,
      null,
    ),
  );
  final container = _container(controller, speech: RecordingTtsService());
  addTearDown(container.dispose);
  await container.read(appControllerProvider.future);
  final router = GoRouter(
    initialLocation: viaHome ? '/home' : '/kanji/day/1',
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('Home')),
      ),
      GoRoute(
        path: '/kanji',
        builder: (_, _) => const Scaffold(body: Text('Kanji day list')),
      ),
      GoRoute(
        path: '/kanji/day/:day',
        builder: (_, state) => KanjiStudyScreen(
          day: int.parse(state.pathParameters['day'] ?? '1'),
        ),
      ),
      GoRoute(
        path: '/kanji/day/:day/finish',
        builder: (_, state) => KanjiFinishScreen(
          day: int.parse(state.pathParameters['day'] ?? '1'),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  if (viaHome) {
    unawaited(router.push('/kanji/day/1'));
    await tester.pumpAndSettle();
  }
}

Future<GoRouter> _pumpRecent(
  WidgetTester tester,
  KanjiTestAppController controller,
) async {
  final container = _container(controller);
  addTearDown(container.dispose);
  final state = await container.read(appControllerProvider.future);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(body: RecentStudyCard(state: state)),
      ),
      GoRoute(
        path: '/kanji',
        builder: (_, _) => const Scaffold(body: Text('Kanji day list')),
      ),
      GoRoute(
        path: '/kanji/day/:day',
        builder: (_, state) => Scaffold(
          body: Text('Kanji study day ${state.pathParameters['day']}'),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

ProviderContainer _container(
  KanjiTestAppController controller, {
  RecordingTtsService? speech,
}) => ProviderContainer(
  overrides: [
    appControllerProvider.overrideWith(() => controller),
    kanjiCatalogProvider.overrideWith((ref) async => kanjiTestCatalog),
    if (speech != null) ttsServiceProvider.overrideWithValue(speech),
  ],
);
