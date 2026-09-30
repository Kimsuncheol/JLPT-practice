import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/data/models/app_state.dart';
import 'package:jlpt_practice/features/dashboard/home_tab_provider.dart';
import 'package:jlpt_practice/features/settings/levels_screen.dart';

void main() {
  testWidgets('switching from N5 to N4 returns to the home dashboard', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/settings/levels',
      routes: [
        GoRoute(
          path: '/settings/levels',
          builder: (_, _) => const LevelsScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (_, _) => const Scaffold(body: Text('Home dashboard')),
        ),
      ],
    );
    addTearDown(router.dispose);

    final container = ProviderContainer(
      overrides: [appControllerProvider.overrideWith(_FakeAppController.new)],
    );
    addTearDown(container.dispose);
    container.read(homeTabIndexProvider.notifier).select(homeTabSettings);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('N4').last);
    await tester.pumpAndSettle();

    expect(find.text('Switch to N4?'), findsOneWidget);
    expect(
      container.read(appControllerProvider).requireValue.selectedLevel,
      'N5',
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Switch'));
    await tester.pumpAndSettle();

    expect(
      container.read(appControllerProvider).requireValue.selectedLevel,
      'N4',
    );
    expect(container.read(homeTabIndexProvider), homeTabDashboard);
    expect(find.text('Home dashboard'), findsOneWidget);
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
  Future<void> setLevel(String value) async {
    state = AsyncData(state.requireValue.copyWith(selectedLevel: value));
  }
}
