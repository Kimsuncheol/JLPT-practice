import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/app/theme/app_theme.dart';
import 'package:jlpt_practice/core/services/local_store.dart';
import 'package:jlpt_practice/core/services/tts_service.dart';
import 'package:jlpt_practice/core/utils/system_bar_metrics.dart';
import 'package:jlpt_practice/data/models/app_state.dart';
import 'package:jlpt_practice/data/models/grammar_study_session.dart';
import 'package:jlpt_practice/data/models/study_preferences.dart';
import 'package:jlpt_practice/data/models/study_session.dart';
import 'package:jlpt_practice/data/models/vocabulary.dart';
import 'package:jlpt_practice/features/dashboard/choose_study_screen.dart';
import 'package:jlpt_practice/features/dashboard/dashboard_screen.dart';
import 'package:jlpt_practice/features/vocabulary/study_finish_screen.dart';
import 'package:jlpt_practice/features/vocabulary/cover_tape.dart';
import 'package:jlpt_practice/features/vocabulary/study_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'leaving day 6 shows recent study below streak and reopens day 6',
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
      router.push('/study/day/6');
      await tester.pumpAndSettle();
      final pageView = find.byType(PageView);
      await tester.drag(pageView, Offset(-tester.getSize(pageView).width, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Words · N5'), findsOneWidget);
      expect(find.text('Day 6'), findsOneWidget);
      expect(find.text('2 of 5 words'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('RECENT STUDY')).dy,
        greaterThan(tester.getBottomLeft(find.text('0 day streak')).dy),
      );
      await tester.tap(find.byKey(const ValueKey('recent-study-/study/day/6')));
      await tester.pumpAndSettle();
      expect(tester.widget<StudyScreen>(find.byType(StudyScreen)).day, 6);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('単語27'), findsOneWidget);
      expect(find.text('2 / 5'), findsOneWidget);
    },
  );

  for (final kind in GrammarStudyKind.values) {
    testWidgets('recent grammar opens saved ${kind.name} screen', (
      tester,
    ) async {
      final session = GrammarStudySession(
        level: 'N5',
        part: 6,
        kind: kind,
        grammarId: 'N5_51',
        title: 'Grammar 51',
        updatedAt: DateTime.now(),
      );
      await (await LocalStore.create()).saveGrammarStudySessions({
        'N5': session,
      });
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
      expect(find.text('Grammar · N5'), findsOneWidget);
      expect(find.text('Part 6 · Grammar 51'), findsOneWidget);
      expect(find.text('Previous'), findsOneWidget);
      await tester.tap(find.byKey(ValueKey('recent-study-${session.route}')));
      await tester.pumpAndSettle();
      expect(find.text(session.route), findsOneWidget);
      expect(find.text('Saved grammar screen'), findsOneWidget);
    });
  }

  testWidgets('word, furigana and romaji taps speak the Japanese reading', (
    tester,
  ) async {
    const volumeChannel = MethodChannel(
      'com.kurenai7968.volume_controller.method',
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      volumeChannel,
      (call) async => call.method == 'isMuted' ? false : 0.8,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        volumeChannel,
        null,
      ),
    );
    final speech = _RecordingTtsService();
    final container = ProviderContainer(
      overrides: [
        appControllerProvider.overrideWith(
          () => _ResumeAppController('word_0', 0),
        ),
        ttsServiceProvider.overrideWithValue(speech),
      ],
    );
    addTearDown(container.dispose);
    await container.read(appControllerProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: StudyScreen(day: 1)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    for (final label in ['単語1', 'たんご', 'tango']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
    expect(speech.spoken, ['たんご', 'たんご', 'たんご']);
  });

  for (final scenario in [
    (
      muted: false,
      volume: 0.02,
      message:
          'Your device is unmuted, but its volume is too low. Turn it up to hear the pronunciation.',
    ),
    (
      muted: true,
      volume: 0.8,
      message: 'Your device is muted. Unmute it to hear the pronunciation.',
    ),
  ]) {
    testWidgets(
      'system volume warning distinguishes ${scenario.muted ? 'muted' : 'unmuted low'} volume',
      (tester) async {
        const volumeChannel = MethodChannel(
          'com.kurenai7968.volume_controller.method',
        );
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          volumeChannel,
          (call) async =>
              call.method == 'isMuted' ? scenario.muted : scenario.volume,
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            volumeChannel,
            null,
          ),
        );
        final speech = _RecordingTtsService();
        final container = ProviderContainer(
          overrides: [
            appControllerProvider.overrideWith(
              () => _ResumeAppController('word_0', 0),
            ),
            ttsServiceProvider.overrideWithValue(speech),
          ],
        );
        addTearDown(container.dispose);
        await container.read(appControllerProvider.future);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: StudyScreen(day: 2)),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('単語6'));
        await tester.pumpAndSettle();

        expect(find.text(scenario.message), findsOneWidget);
        expect(speech.spoken, scenario.muted ? isEmpty : ['たんご']);
      },
    );
  }

  testWidgets('automatic pronunciation reads the first word of a new day', (
    tester,
  ) async {
    final speech = _RecordingTtsService();
    final container = ProviderContainer(
      overrides: [
        // The saved session belongs to day 1, so day 2 is studied fresh.
        appControllerProvider.overrideWith(
          () => _ResumeAppController('word_0', 0, autoPlayAudio: true),
        ),
        ttsServiceProvider.overrideWithValue(speech),
      ],
    );
    addTearDown(container.dispose);
    await container.read(appControllerProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: StudyScreen(day: 2)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('単語6'), findsOneWidget);
    expect(speech.events, ['speak:単語6']);
  });

  testWidgets('a new day stays silent while automatic pronunciation is off', (
    tester,
  ) async {
    final speech = _RecordingTtsService();
    final container = ProviderContainer(
      overrides: [
        appControllerProvider.overrideWith(
          () => _ResumeAppController('word_0', 0),
        ),
        ttsServiceProvider.overrideWithValue(speech),
      ],
    );
    addTearDown(container.dispose);
    await container.read(appControllerProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: StudyScreen(day: 2)),
      ),
    );
    await tester.pumpAndSettle();

    expect(speech.events, isEmpty);
  });

  testWidgets('bottom buttons cover the reading, word and meanings with tape', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        appControllerProvider.overrideWith(
          () => _ResumeAppController('word_0', 0, withExamples: true),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(appControllerProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: StudyScreen(day: 2)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(CoverTape), findsNothing);
    expect(find.text('単語6'), findsOneWidget);
    expect(find.text('毎日単語6を使います。'), findsOneWidget);
    expect(find.text('word'), findsOneWidget);

    await tester.tap(find.text('Hide word'));
    await tester.pumpAndSettle();
    expect(find.text('単語6'), findsNothing);
    // The example sentence keeps its text but the word in it is taped.
    expect(find.byType(CoverTape), findsWidgets);
    expect(find.textContaining('を使います。', findRichText: true), findsOneWidget);
    expect(find.textContaining('単語6を使います。', findRichText: true), findsNothing);
    expect(find.text('Show word'), findsOneWidget);

    await tester.tap(find.text('Hide meanings'));
    await tester.pumpAndSettle();
    expect(find.text('word'), findsNothing);
    expect(find.text('I use the word every day.'), findsNothing);

    await tester.tap(find.text('Hide reading'));
    await tester.pumpAndSettle();
    expect(find.text('たんご'), findsNothing);

    await tester.tap(find.text('Show word'));
    await tester.tap(find.text('Show meanings'));
    await tester.tap(find.text('Show reading'));
    await tester.pumpAndSettle();
    expect(find.byType(CoverTape), findsNothing);
    expect(find.text('単語6'), findsOneWidget);
    expect(find.text('word'), findsOneWidget);
  });

  testWidgets('manual hide controls are independent for each word card', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        appControllerProvider.overrideWith(
          () => _ResumeAppController('word_0', 0, withExamples: true),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(appControllerProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: StudyScreen(day: 2)),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hide reading'));
    await tester.tap(find.text('Hide word'));
    await tester.tap(find.text('Hide meanings'));
    await tester.pumpAndSettle();
    expect(find.text('単語6'), findsNothing);
    expect(find.text('たんご'), findsNothing);
    expect(find.text('word'), findsNothing);

    final pageView = find.byType(PageView);
    await tester.drag(pageView, Offset(-tester.getSize(pageView).width, 0));
    await tester.pumpAndSettle();

    expect(find.text('単語7'), findsOneWidget);
    expect(find.text('たんご'), findsOneWidget);
    expect(find.text('word'), findsOneWidget);
    expect(find.text('Hide reading'), findsOneWidget);
    expect(find.text('Hide word'), findsOneWidget);
    expect(find.text('Hide meanings'), findsOneWidget);

    await tester.drag(pageView, Offset(tester.getSize(pageView).width, 0));
    await tester.pumpAndSettle();
    expect(find.text('単語6'), findsNothing);
    expect(find.text('Show reading'), findsOneWidget);
    expect(find.text('Show word'), findsOneWidget);
    expect(find.text('Show meanings'), findsOneWidget);
  });

  testWidgets('identical word and reading use one combined hide control', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        appControllerProvider.overrideWith(
          () => _ResumeAppController('word_0', 0, sameWordAndReading: true),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(appControllerProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: StudyScreen(day: 2)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ことば'), findsOneWidget);
    expect(find.text('kotoba'), findsOneWidget);
    expect(find.text('Hide reading'), findsNothing);
    expect(find.text('Hide word'), findsNothing);
    expect(find.text('Hide word & reading'), findsOneWidget);
    expect(find.text('Auto review').hitTestable(), findsOneWidget);

    await tester.tap(find.text('Hide word & reading'));
    await tester.pumpAndSettle();

    expect(find.text('ことば'), findsNothing);
    expect(find.text('kotoba'), findsNothing);
    expect(find.text('Show word & reading'), findsOneWidget);
    expect(find.byType(CoverTape), findsWidgets);

    await tester.tap(find.text('Show word & reading'));
    await tester.pumpAndSettle();
    expect(find.text('ことば'), findsOneWidget);
    expect(find.text('kotoba'), findsOneWidget);
  });

  testWidgets('action groups loop between hide controls and auto review', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        appControllerProvider.overrideWith(
          () => _ResumeAppController('word_0', 0),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(appControllerProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: StudyScreen(day: 2)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hide word').hitTestable(), findsOneWidget);
    await _showAutoReviewActions(tester);
    expect(find.text('Auto review').hitTestable(), findsOneWidget);
    await _showHideActions(tester);
    expect(find.text('Hide word').hitTestable(), findsOneWidget);

    // Continuing in the other direction reaches auto review again rather
    // than stopping at an edge.
    await _swipeActionCarousel(tester, -1);
    expect(find.text('Auto review').hitTestable(), findsOneWidget);
  });

  testWidgets('auto review reveals each element in the chosen order', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        appControllerProvider.overrideWith(
          () => _ResumeAppController(
            'word_0',
            0,
            autoReviewOrder: const AutoReviewOrder([
              ReviewElement.meanings,
              ReviewElement.word,
              ReviewElement.reading,
            ]),
            completedDays: {2},
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(appControllerProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: StudyScreen(day: 2)),
      ),
    );
    await tester.pumpAndSettle();

    // Step 1: only the meanings are shown.
    expect(find.text('word'), findsOneWidget);
    expect(find.text('単語6'), findsNothing);
    expect(find.text('たんご'), findsNothing);
    expect(find.byType(CoverTape), findsWidgets);

    // Step 2: the word joins them.
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('word'), findsOneWidget);
    expect(find.text('単語6'), findsOneWidget);
    expect(find.text('たんご'), findsNothing);

    // Step 3: the reading completes the card.
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('単語6'), findsOneWidget);
    expect(find.text('たんご'), findsOneWidget);

    // Then the next card starts over at its first element.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('単語7'), findsNothing);
    expect(find.text('word'), findsOneWidget);
    expect(find.text('2 / 5'), findsOneWidget);
  });

  testWidgets('auto review leaves a day that is not finished alone', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        appControllerProvider.overrideWith(
          () => _ResumeAppController(
            'word_0',
            0,
            autoReviewOrder: AutoReviewOrder.defaultOrder,
            completedDays: {1},
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(appControllerProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: StudyScreen(day: 2)),
      ),
    );
    await tester.pumpAndSettle();

    // The auto review tab is shown semi-transparent and does nothing.
    await _showAutoReviewActions(tester);
    final tabOpacity = find.ancestor(
      of: find.text('Auto review').hitTestable(),
      matching: find.byType(Opacity),
    );
    expect(tester.widget<Opacity>(tabOpacity).opacity, lessThan(1));
    await tester.tap(find.text('Auto review').hitTestable());
    await tester.pump();
    expect(
      container.read(appControllerProvider).requireValue.autoReviewEnabled,
      isTrue,
    );

    // Everything is shown and the manual buttons are back; nothing advances.
    await _showHideActions(tester);
    expect(find.text('単語6'), findsOneWidget);
    expect(find.text('word'), findsOneWidget);
    expect(find.text('Pause').hitTestable(), findsNothing);
    expect(find.text('Hide word').hitTestable(), findsOneWidget);
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('1 / 5'), findsOneWidget);
  });

  testWidgets(
    'the auto review tab switches auto review on for a finished day',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          appControllerProvider.overrideWith(
            () => _ResumeAppController('word_0', 0, completedDays: {2}),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(appControllerProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: StudyScreen(day: 2)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hide word'), findsOneWidget);
      await _showAutoReviewActions(tester);
      final tabOpacity = find.ancestor(
        of: find.text('Auto review').hitTestable(),
        matching: find.byType(Opacity),
      );
      expect(tester.widget<Opacity>(tabOpacity).opacity, 1);

      await tester.tap(find.text('Auto review').hitTestable());
      await tester.pumpAndSettle();
      await _showHideActions(tester);
      expect(find.text('Pause').hitTestable(), findsOneWidget);
      expect(find.text('Hide word').hitTestable(), findsNothing);
      expect(find.text('word'), findsNothing);

      await _showAutoReviewActions(tester);
      await tester.tap(find.text('Auto review').hitTestable());
      await tester.pumpAndSettle();
      await _showHideActions(tester);
      expect(find.text('Pause').hitTestable(), findsNothing);
      expect(find.text('Hide word').hitTestable(), findsOneWidget);
    },
  );

  testWidgets('auto review can be paused and resumed', (tester) async {
    final container = ProviderContainer(
      overrides: [
        appControllerProvider.overrideWith(
          () => _ResumeAppController(
            'word_0',
            0,
            autoReviewOrder: AutoReviewOrder.defaultOrder,
            completedDays: {2},
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(appControllerProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: StudyScreen(day: 2)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('単語6'), findsOneWidget);
    expect(find.text('word'), findsNothing);

    await tester.tap(find.text('Pause'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 10));
    expect(find.text('word'), findsNothing);
    expect(find.text('Resume'), findsOneWidget);

    await tester.tap(find.text('Resume'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('word'), findsOneWidget);
  });

  testWidgets('hide meanings only tapes meaning words in the translation', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        appControllerProvider.overrideWith(
          () => _ResumeAppController(
            'word_0',
            0,
            hideMeanings: true,
            withExamples: true,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(appControllerProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: StudyScreen(day: 2)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('word'), findsNothing);
    expect(find.text('I use the word every day.'), findsNothing);
    expect(
      find.textContaining('I use the', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('the word', findRichText: true), findsNothing);
    expect(
      find.textContaining('every day.', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('swiping stops current speech before automatic pronunciation', (
    tester,
  ) async {
    const volumeChannel = MethodChannel(
      'com.kurenai7968.volume_controller.method',
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      volumeChannel,
      (call) async => call.method == 'isMuted' ? false : 0.8,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        volumeChannel,
        null,
      ),
    );
    final speech = _RecordingTtsService();
    final container = ProviderContainer(
      overrides: [
        appControllerProvider.overrideWith(
          () => _ResumeAppController('word_0', 0, autoPlayAudio: true),
        ),
        ttsServiceProvider.overrideWithValue(speech),
      ],
    );
    addTearDown(container.dispose);
    await container.read(appControllerProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: StudyScreen(day: 1)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('単語1'));
    await tester.pumpAndSettle();

    final pageView = find.byType(PageView);
    await tester.drag(pageView, Offset(-tester.getSize(pageView).width, 0));
    await tester.pumpAndSettle();

    expect(find.text('単語2'), findsOneWidget);
    expect(speech.events, ['speak:単語1', 'speak:たんご', 'stop', 'speak:単語2']);
  });

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
    expect(find.byType(Chip), findsNothing);
    expect(controller.savedSessions, isEmpty);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Continue your recent session?'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Continue your recent session?'), findsNothing);
    expect(find.text('3 / 5'), findsOneWidget);
    expect(find.text('単語3'), findsOneWidget);
    expect(find.byType(Chip), findsNothing);
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

    final pageView = find.byType(PageView);
    await tester.drag(pageView, Offset(-tester.getSize(pageView).width, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 / 5'), findsOneWidget);
    expect(find.text('単語7'), findsOneWidget);

    await tester.drag(pageView, Offset(tester.getSize(pageView).width, 0));
    await tester.pumpAndSettle();
    expect(find.text('1 / 5'), findsOneWidget);
    expect(find.text('単語6'), findsOneWidget);
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
    expect(find.text('単語5'), findsOneWidget);

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

  for (final alreadyCompleted in [false, true]) {
    testWidgets(
      'finishing day 6 returns to day selection (completed: $alreadyCompleted)',
      (tester) async {
        final container = _createContainer();
        addTearDown(container.dispose);
        await container.read(appControllerProvider.future);
        final controller =
            container.read(appControllerProvider.notifier)
                as _ResumeAppController;
        if (alreadyCompleted) {
          await controller.completeStudySession('N5', 6);
        }
        final router = _createRouter(initialLocation: '/study/day/6/finish');
        addTearDown(router.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Finish this session'));
        await tester.pumpAndSettle();
        if (!alreadyCompleted) {
          expect(find.text('Finish this study session?'), findsOneWidget);
          await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
          await tester.pumpAndSettle();
        }

        expect(find.text('Day selection'), findsOneWidget);
        // The day list must sit on top of home, otherwise the system back
        // button has nothing to pop to and closes the app.
        expect(router.canPop(), isTrue);
        router.pop();
        await tester.pumpAndSettle();
        expect(find.text('Home'), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.takeException(), isNull);
        final state = container.read(appControllerProvider).requireValue;
        expect(state.completedStudyDays['N5'], contains(6));
        expect(state.studySessions, isEmpty);
      },
    );
  }
}

Future<void> _showAutoReviewActions(WidgetTester tester) =>
    _swipeActionCarousel(tester, 1);

Future<void> _showHideActions(WidgetTester tester) =>
    _swipeActionCarousel(tester, -1);

Future<void> _swipeActionCarousel(WidgetTester tester, double direction) async {
  final carousel = find.byKey(const ValueKey('study-action-carousel'));
  await tester.drag(
    carousel,
    Offset(tester.getSize(carousel).width * direction, 0),
  );
  await tester.pumpAndSettle();
}

class _RecordingTtsService implements TtsService {
  final spoken = <String>[];
  final events = <String>[];

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
    events.add('speak:$text');
  }

  @override
  Future<void> speakDialogue(List<DialogueTurn> turns) async {}

  @override
  Future<void> stop() async => events.add('stop');

  @override
  Future<void> dispose() async {}
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
      path: '/grammar',
      builder: (_, _) => const Scaffold(body: Text('Grammar list')),
    ),
    for (final path in [
      '/grammar/detail/:id',
      '/grammar/tutor/:id',
      '/grammar/part/:level/:part',
    ])
      GoRoute(
        path: path,
        builder: (_, state) => Scaffold(
          body: Column(
            children: [
              const Text('Saved grammar screen'),
              Text(state.uri.path),
            ],
          ),
        ),
      ),
    GoRoute(
      path: '/home',
      builder: (_, _) => const Scaffold(body: Text('Home')),
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
  _ResumeAppController(
    this.wordId,
    this.indexFallback, {
    this.autoPlayAudio = false,
    this.hideMeanings = false,
    this.withExamples = false,
    this.sameWordAndReading = false,
    this.autoReviewOrder,
    this.completedDays = const {},
  });

  final String wordId;
  final int indexFallback;
  final bool autoPlayAudio;
  final bool hideMeanings;
  final bool withExamples;
  final bool sameWordAndReading;
  final AutoReviewOrder? autoReviewOrder;
  final Set<int> completedDays;
  final int autoReviewSeconds = 2;
  final List<StudySession> savedSessions = [];

  @override
  Future<AppState> build() async {
    return AppState(
      vocabulary: List.generate(
        30,
        (index) => sameWordAndReading && index == 5
            ? _sameReadingWord(index)
            : _word(index, withExamples),
      ),
      progress: const {},
      onboardingComplete: true,
      selectedLevel: 'N5',
      languageCode: 'system',
      meaningLanguageMode: 'en',
      meaningLanguage: 'en',
      dailyGoal: 5,
      showFurigana: true,
      autoPlayAudio: autoPlayAudio,
      hideMeanings: hideMeanings,
      autoReviewEnabled: autoReviewOrder != null,
      autoReviewOrder: autoReviewOrder ?? AutoReviewOrder.defaultOrder,
      autoReviewSeconds: autoReviewSeconds,
      completedStudyDays: {'N5': completedDays},
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
  Future<void> setAutoReviewEnabled(bool value) async =>
      state = AsyncData(state.requireValue.copyWith(autoReviewEnabled: value));

  @override
  Future<void> setHideWord(bool value) async =>
      state = AsyncData(state.requireValue.copyWith(hideWord: value));

  @override
  Future<void> setHideMeanings(bool value) async =>
      state = AsyncData(state.requireValue.copyWith(hideMeanings: value));

  @override
  Future<void> completeStudySession(String level, int day) async {
    final current = state.requireValue;
    state = AsyncData(
      current.copyWith(
        studySessions: {...current.studySessions}..remove(level),
        completedStudyDays: {
          ...current.completedStudyDays,
          level: {...?current.completedStudyDays[level], day},
        },
      ),
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

Vocabulary _word(int index, [bool withExample = false]) => Vocabulary(
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
  example: withExample
      ? VocabularyExample(
          sentence: '毎日単語${index + 1}を使います。',
          reading: 'まいにち',
          translations: const {'en': 'I use the word every day.'},
          quizSentence: '',
          answer: '',
        )
      : const VocabularyExample(
          sentence: '',
          reading: '',
          translations: {},
          quizSentence: '',
          answer: '',
        ),
  rank: index + 1,
);

Vocabulary _sameReadingWord(int index) => Vocabulary(
  id: 'word_$index',
  word: 'ことば',
  reading: 'ことば',
  furigana: 'ことば',
  romaji: 'kotoba',
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
);
