import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/data/models/mock_test_problem.dart';
import 'package:jlpt_practice/features/test/level_practice_test_screen.dart';

void main() {
  testWidgets(
    'lists Practice 1 through 10 and navigates to the selected practice',
    (tester) async {
      String? pushedPracticeId;
      final router = GoRouter(
        initialLocation: '/test/practice/N5/reading',
        routes: [
          GoRoute(
            path: '/test/practice/N5/reading',
            builder: (_, _) => const LevelPracticeTestScreen(
              level: 'N5',
              section: ProblemSection.reading,
            ),
          ),
          GoRoute(
            path: '/test/practice/N5/reading/:practiceId',
            builder: (_, state) {
              pushedPracticeId = state.pathParameters['practiceId'];
              return const Scaffold(body: Text('Test screen'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      expect(find.text('Practice 1'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Practice 10'),
        300,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('Practice 10'), findsOneWidget);

      await tester.tap(find.text('Practice 10'));
      await tester.pumpAndSettle();

      expect(find.text('Test screen'), findsOneWidget);
      expect(pushedPracticeId, 'practice-10');
    },
  );
}
