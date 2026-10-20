import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/core/api/jlpt_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/app/theme/app_theme.dart';
import 'package:jlpt_practice/data/models/grammar_point.dart';
import 'package:jlpt_practice/features/grammar/grammar_qa_chat_screen.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('grammar chat opens with working controls in $brightness mode', (
      tester,
    ) async {
      final requests = <http.Request>[];
      final client = JlptApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'reply':
                  '## Meaning and formation\nUse がいちばん to express the superlative.',
              'follow_up_questions': [
                'When is it used?',
                'Compare より?',
                'Another example?',
              ],
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
          child: MaterialApp(
            theme: brightness == Brightness.light
                ? AppTheme.light()
                : AppTheme.dark(),
            home: Scaffold(
              body: Builder(
                builder: (context) => FilledButton(
                  onPressed: () => showGrammarQaChatScreen(
                    context,
                    grammar: _grammar,
                    languageCode: 'en',
                  ),
                  child: const Text('Open chat'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open chat'));
      await tester.pumpAndSettle();
      expect(find.text('Grammar Tutor'), findsOneWidget);
      expect(find.byType(AiChatWidget), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.send_rounded),
            )
            .onPressed,
        isNotNull,
      );
      expect(find.byType(ActionChip), findsNothing);
      expect(
        find.byKey(const ValueKey('chat_suggestions_container')),
        findsNothing,
      );
      expect(requests, hasLength(1));
      expect(requests.single.url.path, '/api/tutor/chat');
      final body = jsonDecode(requests.single.body) as Map;
      expect(body['message'], contains('in detail'));
      expect(body['message'], contains('exactly three'));
      expect(body['question']['question_text'], contains(_grammar.title));
      expect(body['question']['passage'], contains(_grammar.formation));
      expect(body['explanation_language'], 'English');
      expect(body['history'], isEmpty);
      final messages = tester
          .widget<AiChatWidget>(find.byType(AiChatWidget))
          .controller
          .messages;
      expect(messages, hasLength(1));
      expect(messages.single.user.id, 'ai');
      expect(messages.single.text, contains('Meaning and formation'));
      for (final question in [
        'When is it used?',
        'Compare より?',
        'Another example?',
      ]) {
        expect(find.widgetWithText(OutlinedButton, question), findsOneWidget);
      }
      final question = find.widgetWithText(OutlinedButton, 'Another example?');
      await tester.ensureVisible(question);
      await tester.tap(question);
      await tester.pumpAndSettle();
      expect(requests, hasLength(2));
      final followUp = jsonDecode(requests.last.body) as Map;
      expect(followUp['message'], 'Another example?');
      expect(followUp['history'], hasLength(2));
      expect(followUp['question'], body['question']);
      await tester.tap(find.byKey(const ValueKey('grammar_chat_close')));
      await tester.pumpAndSettle();
      expect(find.text('Open chat'), findsOneWidget);
    });
  }
  testWidgets(
    'initial loading has no starter chips and ignores late replies after close',
    (tester) async {
      final pending = Completer<http.Response>();
      var calls = 0;
      final client = JlptApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((_) {
          calls++;
          return pending.future;
        }),
      );
      addTearDown(client.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [jlptApiClientProvider.overrideWithValue(client)],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showGrammarQaChatScreen(
                    context,
                    grammar: _grammar,
                    languageCode: 'ko',
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(calls, 1);
      expect(find.byType(ActionChip), findsNothing);
      expect(
        find.byKey(const ValueKey('chat_suggestions_container')),
        findsNothing,
      );
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      await tester.tap(find.byKey(const ValueKey('grammar_chat_close')));
      await tester.pumpAndSettle();
      pending.complete(
        http.Response(
          jsonEncode({
            'reply': 'Late explanation',
            'follow_up_questions': ['One?', 'Two?', 'Three?'],
          }),
          200,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Open'), findsOneWidget);
      expect(calls, 1);
      expect(tester.takeException(), isNull);
    },
  );
}

const _grammar = GrammarPoint(
  id: 'N5_1',
  level: 'N5',
  rank: 1,
  title: 'A が いちばん～',
  summary: 'Expresses the superlative.',
  explanation: 'Use it to say that something is the most in a group.',
  formation: 'Noun + が + いちばん',
  examples: [
    GrammarExample(
      japanese: '寿司が一番好きです。',
      reading: 'すしがいちばんすきです。',
      english: 'I like sushi the most.',
    ),
  ],
);
