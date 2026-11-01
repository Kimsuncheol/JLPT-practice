import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jlpt_practice/core/api/daily_lesson_service.dart';
import 'package:jlpt_practice/core/services/daily_lesson_refresh.dart';
import 'package:jlpt_practice/features/daily_lessons/daily_lesson_screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('refreshes at each midnight, including year rollover', (
    tester,
  ) async {
    var now = DateTime(2026, 12, 31, 23, 59, 59);
    var calls = 0;
    final refresh = DailyLessonRefresh(
      now: () => now,
      onRefresh: () => calls++,
    );
    addTearDown(refresh.dispose);
    refresh.received(publicationDate: '2026-12-31');
    now = now.add(const Duration(milliseconds: 999));
    await tester.pump(const Duration(milliseconds: 999));
    expect(calls, 0);
    now = DateTime(2027, 1, 1);
    await tester.pump(const Duration(milliseconds: 1));
    expect(calls, 1);
    refresh.received(publicationDate: '2027-01-01');
    now = DateTime(2027, 1, 2);
    await tester.pump(const Duration(days: 1));
    expect(calls, 2);
    refresh.dispose();
  });

  testWidgets('retries late publication and stops once today is fetched', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 27);
    var calls = 0;
    final refresh = DailyLessonRefresh(
      now: () => now,
      onRefresh: () => calls++,
    );
    addTearDown(refresh.dispose);
    refresh.received(publicationDate: '2026-10-26');
    for (var i = 0; i < 4; i++) {
      now = now.add(const Duration(minutes: 15));
      await tester.pump(const Duration(minutes: 15));
    }
    expect(calls, 4);
    refresh.received(publicationDate: '2026-10-27');
    now = now.add(const Duration(hours: 2));
    await tester.pump(const Duration(hours: 2));
    expect(calls, 4);
    refresh.received(publicationDate: '2026-10-27', offline: true);
    now = now.add(const Duration(minutes: 15));
    await tester.pump(const Duration(minutes: 15));
    expect(calls, 5);
    refresh.dispose();
  });

  testWidgets('overnight suspension refreshes immediately on resume', (
    tester,
  ) async {
    var now = DateTime(2026, 10, 27, 23, 59);
    var calls = 0;
    final refresh = DailyLessonRefresh(
      now: () => now,
      onRefresh: () => calls++,
    );
    addTearDown(refresh.dispose);
    refresh.received(publicationDate: '2026-10-27');
    refresh.setActive(false);
    now = DateTime(2026, 10, 28, 8);
    await tester.pump(const Duration(hours: 8, minutes: 1));
    expect(calls, 0);
    refresh.setActive(true);
    expect(calls, 1);
    refresh.received(publicationDate: '2026-10-28');
    refresh.setActive(false);
    now = now.add(const Duration(minutes: 1));
    await tester.pump(const Duration(minutes: 1));
    refresh.setActive(true);
    await tester.pump(const Duration(minutes: 15));
    expect(calls, 1);
    refresh.dispose();
  });

  testWidgets('disposed scheduler leaves no recurring requests', (
    tester,
  ) async {
    final refresh = DailyLessonRefresh(
      now: () => DateTime(2026, 10, 27, 23, 59),
      onRefresh: () => fail('Refresh after disposal'),
    );
    refresh.dispose();
    await tester.pump(const Duration(days: 2));
  });

  testWidgets(
    'Home alone updates at midnight and persists the new lesson for restart',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      var now = DateTime(2026, 10, 27, 23, 59, 59);
      var calls = 0;
      final requests = <Uri>[];
      final service = DailyLessonService(
        client: MockClient((request) async {
          calls++;
          requests.add(request.url);
          return http.Response(
            jsonEncode({
              'articles': [
                {
                  'id': 'day-$calls',
                  'title': 'Daily expression',
                  'date': DailyLessonRefresh.day(now),
                  'url': 'https://example.test/source',
                  'status': 'ready',
                  'lesson': {
                    'expressions': [
                      {'japanese': '毎日', 'translation': '매일'},
                    ],
                  },
                },
              ],
              'page': 1,
              'pages': 1,
              'total': 1,
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(service.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dailyLessonServiceProvider.overrideWithValue(service),
            dailyLessonClockProvider.overrideWithValue(() => now),
          ],
          child: const MaterialApp(
            home: Scaffold(body: LatestExpressionCard()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.text('2026-10-27'), findsOneWidget);
      now = DateTime(2026, 10, 28);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('2026-10-28'), findsOneWidget);
      // The OS suspends timers; the widget refreshes when the app resumes.
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      now = DateTime(2026, 10, 29, 8);
      await tester.pump(const Duration(hours: 32));
      expect(calls, 2);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(calls, 3);
      for (
        var i = 0;
        i < 10 && find.text('2026-10-29').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('2026-10-29'), findsOneWidget);
      expect(
        requests.every(
          (uri) =>
              uri.path == '/api/articles' && uri.queryParameters['page'] == '1',
        ),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      final offline = DailyLessonService(
        client: MockClient((_) async => throw http.ClientException('offline')),
      );
      addTearDown(offline.close);
      final saved = await offline.pages().toList();
      expect(saved.first.saved, isTrue);
      expect(saved.last.value.lessons.first.date, '2026-10-29');
      expect(saved.last.offline, isTrue);
    },
  );
}
