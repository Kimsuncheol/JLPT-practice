import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/theme/app_theme.dart';
import 'package:jlpt_practice/features/vocabulary/study_quiz_selection_screen.dart';

void main() {
  testWidgets('quiz choices fit a compact phone', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const StudyQuizSelectionScreen(day: 1),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Fill-in-the-blank game'), findsOneWidget);
    expect(find.text('Sentence Reordering'), findsOneWidget);
    expect(
      find.text('Pick how you want to practice today’s words.'),
      findsOneWidget,
    );
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      AppTheme.light().scaffoldBackgroundColor,
    );
    expect(
      tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
      AppTheme.light().scaffoldBackgroundColor,
    );
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.systemOverlayStyle?.statusBarColor, Colors.transparent);
    expect(appBar.systemOverlayStyle?.statusBarIconBrightness, Brightness.dark);
    final closeButton = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.close_rounded),
        matching: find.byType(IconButton),
      ),
    );
    expect(closeButton.style?.side?.resolve({}), BorderSide.none);
    expect(tester.takeException(), isNull);
  });

  testWidgets('status icons remain visible in dark mode', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const StudyQuizSelectionScreen(day: 1),
      ),
    );
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.systemOverlayStyle?.statusBarColor, Colors.transparent);
    expect(
      appBar.systemOverlayStyle?.statusBarIconBrightness,
      Brightness.light,
    );
  });

  testWidgets('visible route follows selection push and quiz pop', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/finish',
      routes: [
        GoRoute(
          path: '/finish',
          builder: (_, _) => const Scaffold(body: Text('Finish')),
        ),
        GoRoute(
          path: '/selection',
          builder: (_, _) => const StudyQuizSelectionScreen(day: 1),
        ),
        GoRoute(
          path: '/quiz',
          builder: (_, _) => const Scaffold(body: Text('Quiz')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    router.push('/selection');
    await tester.pumpAndSettle();
    final entering = router.routerDelegate.state.uri.path;
    router.push('/quiz');
    await tester.pumpAndSettle();
    final playing = router.routerDelegate.state.uri.path;
    router.pop();
    await tester.pumpAndSettle();
    final returning = router.routerDelegate.state.uri.path;
    expect(
      [entering, playing, returning],
      ['/selection', '/quiz', '/selection'],
    );
  });
}
