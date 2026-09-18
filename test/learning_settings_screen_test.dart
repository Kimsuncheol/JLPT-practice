import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/app/theme/app_theme.dart';
import 'package:jlpt_practice/data/models/app_state.dart';
import 'package:jlpt_practice/features/settings/learning_language_screen.dart';
import 'package:jlpt_practice/features/settings/learning_settings_screen.dart';
import 'package:jlpt_practice/shared/eye_comfort_overlay.dart';

void main() {
  Future<ProviderContainer> pump(WidgetTester tester, Widget home) async {
    final container = ProviderContainer(
      overrides: [
        appControllerProvider.overrideWith(() => _FakeAppController()),
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

  testWidgets('opens the learning language screen', (tester) async {
    await pump(tester, const LearningSettingsScreen());

    await tester.tap(find.text('Learning language'));
    await tester.pumpAndSettle();

    expect(find.byType(LearningLanguageScreen), findsOneWidget);
  });

  testWidgets('slider is disabled until eye comfort mode is on', (
    tester,
  ) async {
    final container = await pump(tester, const LearningSettingsScreen());

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
  Future<AppState> build() async => const AppState(
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
  Future<void> setEyeComfortEnabled(bool value) async {
    state = AsyncData(state.requireValue.copyWith(eyeComfortEnabled: value));
  }

  @override
  Future<void> setEyeComfortLevel(double value) async {
    state = AsyncData(state.requireValue.copyWith(eyeComfortLevel: value));
  }
}
