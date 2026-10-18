import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jlpt_practice/core/api/jlpt_api_client.dart';
import 'package:jlpt_practice/features/test/ai_practice_screen.dart';

void main() {
  testWidgets('focused generation shows server failure and can be retried', (
    tester,
  ) async {
    var calls = 0;
    final client = JlptApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        calls++;
        expect(request.url.path, '/api/practice/question');
        expect(jsonDecode(request.body)['topic'], 'は');
        if (calls == 1) return http.Response('model unavailable', 502);
        return http.Response(
          jsonEncode({
            'level': 'N5',
            'category': 'grammar',
            'question': 'わたし（ ）学生です。',
            'options': ['は', 'を', 'に', 'で'],
            'correct_index': 0,
            'explanation': 'Use は.',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    addTearDown(client.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [jlptApiClientProvider.overrideWithValue(client)],
        child: const MaterialApp(
          home: AiPracticeScreen(level: 'N5', topic: 'は'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ai_generate_practice')));
    await tester.pumpAndSettle();
    final retry = find.text('Try again');
    await tester.scrollUntilVisible(retry, 150);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.byKey(const ValueKey('ai_choice_0')), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
  });

  testWidgets(
    'generated session scores locally and shows per-option feedback',
    (tester) async {
      var calls = 0;
      final client = JlptApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          calls++;
          expect(request.url.path, '/api/practice/generate');
          return http.Response(
            jsonEncode({
              'level': 'N5',
              'category': 'grammar',
              'question_count': 3,
              'explanation_language': 'English',
              'questions': List.generate(
                3,
                (i) => {
                  'id': 'id-$i',
                  'question_text': 'わたし（ ）学生です。',
                  'options': ['は', 'を', 'に', 'で'],
                  'correct_index': 0,
                  'correct_answer': 'は',
                  'option_explanations': [
                    'Topic marker',
                    'Object marker',
                    'Destination',
                    'Location',
                  ],
                },
              ),
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(client.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [jlptApiClientProvider.overrideWithValue(client)],
          child: const MaterialApp(home: AiPracticeScreen(level: 'N5')),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.tap(find.byKey(const ValueKey('ai_generate_practice')));
      await tester.pumpAndSettle();
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(ValueKey('ai_choice_${i == 1 ? 1 : 0}')));
        await tester.pumpAndSettle();
        expect(find.text('は: Topic marker'), findsOneWidget);
        final next = find.byKey(const ValueKey('ai_practice_next'));
        await tester.scrollUntilVisible(next, 200);
        await tester.tap(next);
        await tester.pumpAndSettle();
      }
      expect(find.text('2 / 3'), findsOneWidget);
      expect(calls, 1);
    },
  );
}
