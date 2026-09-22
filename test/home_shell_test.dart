import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/app/theme/app_theme.dart';
import 'package:jlpt_practice/data/models/app_state.dart';
import 'package:jlpt_practice/features/dashboard/home_shell.dart';

void main() {
  testWidgets('home has four destinations and no review action', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [GoRoute(path: '/home', builder: (_, _) => const HomeShell())],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appControllerProvider.overrideWith(() => _FakeAppController()),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(find.text('Review'), findsNothing);
    expect(find.text('Reviews due'), findsNothing);
  });

  testWidgets('learning settings does not display the learning language', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [GoRoute(path: '/home', builder: (_, _) => const HomeShell())],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appControllerProvider.overrideWith(() => _FakeAppController()),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    final tile = find.widgetWithText(ListTile, 'Learning settings');
    expect(tile, findsOneWidget);
    expect(tester.widget<ListTile>(tile).subtitle, isNull);
  });

  testWidgets('level chip opens level selection', (tester) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const HomeShell()),
        GoRoute(
          path: '/settings/levels',
          builder: (_, _) => const Scaffold(body: Text('Level selection')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appControllerProvider.overrideWith(() => _FakeAppController()),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ActionChip, 'N5'));
    await tester.pumpAndSettle();

    expect(find.text('Level selection'), findsOneWidget);
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
}
