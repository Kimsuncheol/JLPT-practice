import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/app/theme/app_theme.dart';
import 'package:jlpt_practice/data/models/app_state.dart';
import 'package:jlpt_practice/features/dashboard/home_shell.dart';

void main() {
  testWidgets('review is a dashboard action and not a bottom destination', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const HomeShell()),
        GoRoute(
          path: '/review',
          builder: (_, _) => const Scaffold(body: Text('Review route')),
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

    expect(find.byType(NavigationDestination), findsNWidgets(3));
    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Review'),
      ),
      findsNothing,
    );
    expect(find.text('Review'), findsOneWidget);

    await tester.ensureVisible(find.text('Review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();

    expect(find.text('Review route'), findsOneWidget);
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
