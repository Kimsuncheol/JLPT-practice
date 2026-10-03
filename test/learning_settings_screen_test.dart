import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/app/theme/app_theme.dart';
import 'package:jlpt_practice/data/models/app_state.dart';
import 'package:jlpt_practice/data/models/study_preferences.dart';
import 'package:jlpt_practice/features/settings/example_font_size_screen.dart';
import 'package:jlpt_practice/features/settings/eye_comfort_screen.dart';
import 'package:jlpt_practice/features/vocabulary/example_furigana_text.dart';
import 'package:jlpt_practice/features/settings/learning_language_screen.dart';
import 'package:jlpt_practice/features/settings/learning_settings_screen.dart';
import 'package:jlpt_practice/features/settings/tts_volume_screen.dart';
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
          path: '/settings/tts-volume',
          builder: (_, _) => const TtsVolumeScreen(),
        ),
        GoRoute(
          path: '/settings/example-font-size',
          builder: (_, _) => const ExampleFontSizeScreen(),
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
    for (final label in ['Language', 'Reading & pronunciation', 'Display']) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Auto review'), findsNothing);
    expect(find.text('Review'), findsNothing);
    expect(find.text('Hide and recall'), findsNothing);
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

  testWidgets('wires to volume and eye comfort screens', (tester) async {
    await pump(tester, const LearningSettingsScreen());
    expect(find.byType(Slider), findsNothing);

    for (final (tile, screen) in [
      ('Pronunciation volume', TtsVolumeScreen),
      ('Example sentence size', ExampleFontSizeScreen),
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

  testWidgets('example size slider scales the sentence and its furigana', (
    tester,
  ) async {
    final container = await pump(tester, const ExampleFontSizeScreen());
    AppState state() => container.read(appControllerProvider).requireValue;
    // Text.rich nests its own style under the inherited one, so the size in
    // effect is the innermost one set.
    double? fontSize(String text) {
      double? size;
      void visit(InlineSpan span) {
        if (span is! TextSpan) return;
        size = span.style?.fontSize ?? size;
        span.children?.forEach(visit);
      }

      visit(tester.widget<RichText>(find.text(text, findRichText: true)).text);
      return size;
    }

    expect(state().exampleFontScale, 1);
    expect(find.text('100%'), findsOneWidget);
    final sentenceBefore = fontSize('私')!;
    final rubyBefore = fontSize('わたし')!;
    final rubyRatio = rubyBefore / sentenceBefore;

    await tester.drag(find.byType(Slider), const Offset(300, 0));
    await tester.pumpAndSettle();

    expect(state().exampleFontScale, 1.6);
    expect(find.text('160%'), findsOneWidget);
    expect(fontSize('私'), closeTo(sentenceBefore * 1.6, 0.01));
    expect(fontSize('わたし'), closeTo(rubyBefore * 1.6, 0.01));
    expect(fontSize('わたし')! / fontSize('私')!, closeTo(rubyRatio, 0.001));

    await tester.drag(find.byType(Slider), const Offset(-600, 0));
    await tester.pumpAndSettle();

    expect(state().exampleFontScale, 0.8);
    expect(fontSize('わたし'), closeTo(rubyBefore * 0.8, 0.01));
    expect(
      tester
          .widget<ExampleFuriganaText>(find.byType(ExampleFuriganaText))
          .fontScale,
      0.8,
    );
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
  Future<void> setExampleFontScale(double value) async {
    state = AsyncData(state.requireValue.copyWith(exampleFontScale: value));
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
