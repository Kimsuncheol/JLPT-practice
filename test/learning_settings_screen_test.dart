import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/app/theme/app_theme.dart';
import 'package:jlpt_practice/data/models/app_state.dart';
import 'package:jlpt_practice/data/models/study_preferences.dart';
import 'package:jlpt_practice/data/models/study_session.dart';
import 'package:jlpt_practice/features/settings/auto_review_screen.dart';
import 'package:jlpt_practice/features/settings/eye_comfort_screen.dart';
import 'package:jlpt_practice/features/settings/learning_language_screen.dart';
import 'package:jlpt_practice/features/settings/learning_settings_screen.dart';
import 'package:jlpt_practice/features/settings/recall_cover_screen.dart';
import 'package:jlpt_practice/features/settings/tts_volume_screen.dart';
import 'package:jlpt_practice/features/settings/tts_settings_screen.dart';
import 'package:jlpt_practice/shared/eye_comfort_overlay.dart';

void main() {
  Future<ProviderContainer> pump(
    WidgetTester tester,
    Widget home, {
    _FakeAppController? controller,
  }) async {
    final container = ProviderContainer(
      overrides: [
        appControllerProvider.overrideWith(
          () => controller ?? _FakeAppController(),
        ),
      ],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => home),
        GoRoute(
          path: '/settings/learning-language',
          builder: (_, _) => const LearningLanguageScreen(),
        ),
        GoRoute(
          path: '/settings/recall-cover',
          builder: (_, _) => const RecallCoverScreen(),
        ),
        GoRoute(
          path: '/settings/auto-review',
          builder: (_, _) => const AutoReviewScreen(),
        ),
        GoRoute(
          path: '/settings/tts',
          builder: (_, _) => const TtsSettingsScreen(),
        ),
        GoRoute(
          path: '/settings/tts-volume',
          builder: (_, _) => const TtsVolumeScreen(),
        ),
        GoRoute(
          path: '/settings/eye-comfort',
          builder: (_, _) => const EyeComfortScreen(),
        ),
      ],
    );
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
    return container;
  }

  testWidgets('settings are labeled by group', (tester) async {
    await pump(tester, const LearningSettingsScreen());
    for (final label in [
      'Language',
      'Reading & pronunciation',
      'Review',
      'Display',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('auto review screen picks the reveal order and speed', (
    tester,
  ) async {
    final container = await pump(tester, const LearningSettingsScreen());
    ProviderContainer read() => container;
    AppState state() => read().read(appControllerProvider).requireValue;
    expect(find.text('Off'), findsWidgets);

    await tester.tap(find.text('Auto review'));
    await tester.pumpAndSettle();
    expect(find.byType(AutoReviewScreen), findsOneWidget);
    // All 3! = 6 ordered combinations are offered, the first being
    // word -> meanings -> reading.
    expect(find.byType(RadioListTile<AutoReviewOrder>), findsNWidgets(6));
    expect(find.text('Word → Meanings → Reading'), findsOneWidget);
    expect(find.text('Reading → Meanings → Word'), findsOneWidget);

    await tester.tap(find.text('Use auto review'));
    await tester.scrollUntilVisible(
      find.text('Reading → Word → Meanings'),
      200,
    );
    await tester.tap(find.text('Reading → Word → Meanings'));
    await tester.scrollUntilVisible(find.text('5 sec'), 200);
    await tester.tap(find.text('5 sec'));
    await tester.pumpAndSettle();
    expect(state().autoReviewEnabled, isTrue);
    expect(state().autoReviewOrder.id, 'reading-word-meanings');
    expect(state().autoReviewSeconds, 5);
  });

  testWidgets('auto review is disabled while a study day is unfinished', (
    tester,
  ) async {
    await pump(
      tester,
      const LearningSettingsScreen(),
      controller: _FakeAppController(
        studySession: StudySession(
          level: 'N5',
          day: 2,
          wordId: 'word_0',
          indexFallback: 0,
          dailyGoal: 10,
          updatedAt: DateTime(2026),
        ),
      ),
    );

    final tile = find.widgetWithText(ListTile, 'Auto review');
    expect(tester.widget<ListTile>(tile).enabled, isFalse);
    final opacity = find.ancestor(of: tile, matching: find.byType(Opacity));
    expect(tester.widget<Opacity>(opacity).opacity, lessThan(1));

    await tester.tap(find.text('Auto review'));
    await tester.pumpAndSettle();
    expect(find.byType(LearningSettingsScreen), findsOneWidget);
    expect(find.byType(AutoReviewScreen), findsNothing);
  });

  testWidgets('opens the learning language screen', (tester) async {
    await pump(tester, const LearningSettingsScreen());

    await tester.tap(find.text('Learning language'));
    await tester.pumpAndSettle();

    expect(find.byType(LearningLanguageScreen), findsOneWidget);
  });

  testWidgets('furigana and automatic pronunciation live here', (tester) async {
    final container = await pump(tester, const LearningSettingsScreen());

    expect(find.text('Show furigana'), findsOneWidget);
    expect(find.text('Automatic pronunciation'), findsOneWidget);

    await tester.tap(find.text('Automatic pronunciation'));
    await tester.pumpAndSettle();
    expect(
      container.read(appControllerProvider).requireValue.autoPlayAudio,
      isTrue,
    );
    await tester.tap(find.text('Show furigana'));
    await tester.pumpAndSettle();
    expect(
      container.read(appControllerProvider).requireValue.showFurigana,
      isFalse,
    );
  });

  testWidgets('wires to recall, voice, volume and eye comfort screens', (
    tester,
  ) async {
    await pump(tester, const LearningSettingsScreen());
    expect(find.byType(Slider), findsNothing);

    for (final (tile, screen) in [
      ('Hide and recall', RecallCoverScreen),
      ('Japanese Voice & TTS Settings', TtsSettingsScreen),
      ('Pronunciation volume', TtsVolumeScreen),
      ('Eye comfort mode', EyeComfortScreen),
    ]) {
      await tester.scrollUntilVisible(find.text(tile), 200);
      await tester.tap(find.text(tile));
      await tester.pumpAndSettle();
      expect(find.byType(screen), findsOneWidget, reason: tile);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('Japanese voice selection is stored in app state', (
    tester,
  ) async {
    final container = await pump(tester, const TtsSettingsScreen());
    AppState state() => container.read(appControllerProvider).requireValue;

    expect(state().ttsVoiceId, 'f1');
    expect(find.text('Aoi'), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_outline_rounded), findsNWidgets(5));

    await tester.tap(find.text('Sora'));
    await tester.pumpAndSettle();

    expect(state().ttsVoiceId, 'm4');
  });

  testWidgets('recall cover screen edits word and meaning covers', (
    tester,
  ) async {
    final container = await pump(tester, const RecallCoverScreen());
    AppState state() => container.read(appControllerProvider).requireValue;

    await tester.tap(find.text('Hide word'));
    await tester.tap(find.text('Hide meanings'));
    await tester.pumpAndSettle();
    expect(state().hideWord, isTrue);
    expect(state().hideMeanings, isTrue);
    expect(find.byType(RadioListTile<MeaningCoverMode>), findsNothing);
  });

  testWidgets('volume screen switches between system and slider', (
    tester,
  ) async {
    final container = await pump(tester, const TtsVolumeScreen());
    AppState state() => container.read(appControllerProvider).requireValue;

    expect(state().ttsVolumeMode, TtsVolumeMode.system);
    expect(find.byType(Slider), findsNothing);

    await tester.tap(find.text('Custom level'));
    await tester.pumpAndSettle();
    expect(state().ttsVolumeMode, TtsVolumeMode.slider);
    expect(find.byType(Slider), findsOneWidget);

    await tester.drag(find.byType(Slider), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(state().ttsVolume, lessThan(1));

    await tester.tap(find.text('System volume'));
    await tester.pumpAndSettle();
    expect(state().ttsVolumeMode, TtsVolumeMode.system);
    expect(find.byType(Slider), findsNothing);
  });

  testWidgets('slider is disabled until eye comfort mode is on', (
    tester,
  ) async {
    final container = await pump(tester, const EyeComfortScreen());

    expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNull);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(
      container.read(appControllerProvider).requireValue.eyeComfortEnabled,
      isTrue,
    );
    expect(tester.widget<Slider>(find.byType(Slider)).onChanged, isNotNull);

    await tester.drag(find.byType(Slider), const Offset(300, 0));
    await tester.pumpAndSettle();

    expect(
      container.read(appControllerProvider).requireValue.eyeComfortLevel,
      greaterThan(0.5),
    );
  });

  testWidgets('overlay tints the child only when enabled', (tester) async {
    final container = await pump(
      tester,
      const EyeComfortOverlay(child: Text('study')),
    );
    final tint = find.descendant(
      of: find.byType(EyeComfortOverlay),
      matching: find.byType(IgnorePointer),
    );
    expect(tint, findsNothing);

    await container
        .read(appControllerProvider.notifier)
        .setEyeComfortEnabled(true);
    await tester.pumpAndSettle();

    expect(find.text('study'), findsOneWidget);
    expect(tint, findsOneWidget);
  });
}

class _FakeAppController extends AppController {
  _FakeAppController({this.studySession});

  final StudySession? studySession;

  @override
  Future<AppState> build() async => AppState(
    vocabulary: [],
    progress: {},
    onboardingComplete: true,
    selectedLevel: 'N5',
    languageCode: 'en',
    meaningLanguageMode: 'en',
    meaningLanguage: 'en',
    dailyGoal: 10,
    showFurigana: true,
    autoPlayAudio: false,
    themeMode: ThemeMode.light,
    notificationsEnabled: false,
    studySeconds: 0,
    quizAnswered: 0,
    quizCorrect: 0,
    currentStreak: 0,
    longestStreak: 0,
    studySessions: studySession == null ? const {} : {'N5': studySession!},
  );

  @override
  Future<void> setShowFurigana(bool value) async {
    state = AsyncData(state.requireValue.copyWith(showFurigana: value));
  }

  @override
  Future<void> setAutoPlayAudio(bool value) async {
    state = AsyncData(state.requireValue.copyWith(autoPlayAudio: value));
  }

  @override
  Future<void> setHideWord(bool value) async {
    state = AsyncData(state.requireValue.copyWith(hideWord: value));
  }

  @override
  Future<void> setHideMeanings(bool value) async {
    state = AsyncData(state.requireValue.copyWith(hideMeanings: value));
  }

  @override
  Future<void> setMeaningCoverMode(MeaningCoverMode value) async {
    state = AsyncData(state.requireValue.copyWith(meaningCoverMode: value));
  }

  @override
  Future<void> setTtsVolumeMode(TtsVolumeMode value) async {
    state = AsyncData(state.requireValue.copyWith(ttsVolumeMode: value));
  }

  @override
  Future<void> setTtsVolume(double value) async {
    state = AsyncData(state.requireValue.copyWith(ttsVolume: value));
  }

  @override
  Future<void> setTtsVoiceId(String value) async {
    state = AsyncData(state.requireValue.copyWith(ttsVoiceId: value));
  }

  @override
  Future<void> setAutoReviewEnabled(bool value) async {
    state = AsyncData(state.requireValue.copyWith(autoReviewEnabled: value));
  }

  @override
  Future<void> setAutoReviewOrder(AutoReviewOrder value) async {
    state = AsyncData(state.requireValue.copyWith(autoReviewOrder: value));
  }

  @override
  Future<void> setAutoReviewSeconds(int value) async {
    state = AsyncData(state.requireValue.copyWith(autoReviewSeconds: value));
  }

  @override
  Future<void> setEyeComfortEnabled(bool value) async {
    state = AsyncData(state.requireValue.copyWith(eyeComfortEnabled: value));
  }

  @override
  Future<void> setEyeComfortLevel(double value) async {
    state = AsyncData(state.requireValue.copyWith(eyeComfortLevel: value));
  }
}
