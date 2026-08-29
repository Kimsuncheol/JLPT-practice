import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/app/theme/app_theme.dart';
import 'package:jlpt_practice/data/models/app_state.dart';
import 'package:jlpt_practice/features/settings/appearance_screen.dart';
import 'package:jlpt_practice/features/settings/settings_screen.dart';

void main() {
  testWidgets('uses adaptive foreground colors in dark mode', (tester) async {
    final container = ProviderContainer(
      overrides: [
        appControllerProvider.overrideWith(() => _FakeAppController()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const AppearanceScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scheme = AppTheme.dark().colorScheme;
    final selectedTile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'Light'),
    );
    final unselectedTile = tester.widget<ListTile>(
      find.widgetWithText(ListTile, 'System'),
    );

    expect(selectedTile.textColor, scheme.onPrimaryContainer);
    expect(selectedTile.iconColor, scheme.onPrimaryContainer);
    expect(unselectedTile.textColor, scheme.onSurface);
    expect(unselectedTile.iconColor, scheme.onSurface);
  });

  testWidgets('opens appearance from settings', (tester) async {
    final container = ProviderContainer(
      overrides: [
        appControllerProvider.overrideWith(() => _FakeAppController()),
      ],
    );
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SettingsScreen()),
        GoRoute(
          path: '/settings/appearance',
          builder: (_, _) => const AppearanceScreen(),
        ),
      ],
    );
    addTearDown(container.dispose);
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

    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();

    expect(find.byType(AppearanceScreen), findsOneWidget);
    expect(find.text('System'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
  });

  testWidgets('selects system, light, and dark appearance modes', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        appControllerProvider.overrideWith(() => _FakeAppController()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const AppearanceScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('System'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();

    expect(
      container.read(appControllerProvider).requireValue.themeMode,
      ThemeMode.dark,
    );
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });
}

class _FakeAppController extends AppController {
  @override
  Future<AppState> build() async => _state;

  @override
  Future<void> setThemeMode(ThemeMode value) async {
    state = AsyncData(state.requireValue.copyWith(themeMode: value));
  }

  static const _state = AppState(
    vocabulary: [],
    progress: {},
    onboardingComplete: true,
    selectedLevel: 'N5',
    languageCode: 'en',
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
}
