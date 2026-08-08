import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/features/test/question_type_screen.dart';

void main() {
  testWidgets('lists vocabulary, grammar and reading, navigating to the right '
      'section path for each', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final pushed = <String>[];
    final router = GoRouter(
      initialLocation: '/test/practice/N5',
      routes: [
        GoRoute(
          path: '/test/practice/N5',
          builder: (_, _) => const QuestionTypeScreen(level: 'N5'),
        ),
        GoRoute(
          path: '/test/practice/N5/:section',
          builder: (_, state) {
            pushed.add(state.pathParameters['section'] ?? '');
            return const Scaffold(body: Text('Test screen'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('N5 Practice'), findsOneWidget);
    expect(find.text('Vocabulary'), findsOneWidget);
    expect(find.text('Grammar'), findsOneWidget);
    expect(find.text('Reading'), findsOneWidget);

    await tester.tap(find.text('Grammar'));
    await tester.pumpAndSettle();
    expect(find.text('Test screen'), findsOneWidget);
    expect(pushed, ['grammar']);
  });
}
