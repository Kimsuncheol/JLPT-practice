import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/data/models/jlpt_test_schedule.dart';
import 'package:jlpt_practice/features/test/level_practice_test_screen.dart';
import 'package:jlpt_practice/features/test/mock_test_providers.dart';

void main() {
  testWidgets(
    'lists exam dates for the level and navigates to the test screen on tap',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          jlptTestSchedulesForLevelProvider(
            'N5',
          ).overrideWith((ref) async => _schedules),
        ],
      );
      addTearDown(container.dispose);

      String? pushedLevel;
      String? pushedScheduleId;
      final router = GoRouter(
        initialLocation: '/test/practice/N5',
        routes: [
          GoRoute(
            path: '/test/practice/N5',
            builder: (_, _) => const LevelPracticeTestScreen(level: 'N5'),
          ),
          GoRoute(
            path: '/test/practice/N5/:scheduleId',
            builder: (_, state) {
              pushedLevel = 'N5';
              pushedScheduleId = state.pathParameters['scheduleId'];
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

      expect(find.text('JLPT N5 · December 2025'), findsOneWidget);
      expect(find.text('JLPT N5 · July 2021'), findsOneWidget);

      await tester.tap(find.text('JLPT N5 · December 2025'));
      await tester.pumpAndSettle();

      expect(find.text('Test screen'), findsOneWidget);
      expect(pushedLevel, 'N5');
      expect(pushedScheduleId, '2025-december-n5');
    },
  );
}

final _schedules = [
  JlptTestSchedule(
    id: '2025-december-n5',
    year: 2025,
    session: 'December',
    examDate: DateTime(2025, 12, 7),
    level: 'N5',
    displayName: 'JLPT N5 · December 2025',
  ),
  JlptTestSchedule(
    id: '2021-july-n5',
    year: 2021,
    session: 'July',
    examDate: DateTime(2021, 7, 4),
    level: 'N5',
    displayName: 'JLPT N5 · July 2021',
  ),
];
