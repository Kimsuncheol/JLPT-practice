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
import 'package:jlpt_practice/features/vocabulary/example_furigana_text.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('grammar chat opens with working controls in $brightness mode', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <http.Request>[];
      final client = JlptApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            jsonEncode({
              'reply':
                  '## Meaning and formation\nUse とか for examples.\n\n[[example:1]]'
                  '${requests.length == 1 ? '\n\n[[example:2]]' : ''}',
              'examples': requests.length == 1
                  ? [
                      {
                        'japanese': '週末は映画とか買い物とか楽しいことをしたいです。',
                        'sentence_furigana':
                            '{週末|しゅうまつ}は{映画|えいが}とか{買|か}い{物|もの}とか{楽|たの}しいことをしたいです。',
                        'translation': '주말에는 영화를 보거나 쇼핑을 하는 등 재미있는 일을 하고 싶어요.',
                      },
                      {
                        'japanese': '彼女は英語とかフランス語とかいろいろな言葉を話せます。',
                        'sentence_furigana':
                            '{彼女|かのじょ}は{英語|えいご}とかフランス{語|ご}とかいろいろな{言葉|ことば}を{話|はな}せます。',
                        'translation': '그녀는 영어, 프랑스어 등 다양한 언어를 구사할 수 있습니다.',
                      },
                    ]
                  : [
                      {
                        'japanese': '日本語が一番好きです。',
                        'sentence_furigana': '{日本語|にほんご}が{一番|いちばん}{好|す}きです。',
                        'translation': 'I like Japanese the most.',
                      },
                    ],
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
      expect(body['message'], contains('structured examples array'));
      expect(body['structured_examples'], isTrue);
      expect((body['message'] as String).runes.length, lessThanOrEqualTo(500));
      expect(body['question']['question_text'], contains(_grammar.title));
      expect(body['question']['passage'], contains(_grammar.formation));
      expect(body['question']['passage'], contains('{寿司|すし}が{一番好|いちばんす}きです。'));
      expect(body['explanation_language'], 'English');
      expect(body['history'], isEmpty);
      final messages = tester
          .widget<AiChatWidget>(find.byType(AiChatWidget))
          .controller
          .messages;
      expect(messages, hasLength(1));
      expect(messages.single.user.id, 'ai');
      expect(messages.single.text, contains('Meaning and formation'));
      final units = find.byType(ExampleFuriganaText);
      expect(units, findsNWidgets(2));
      for (final element in units.evaluate()) {
        final widget = element.widget as ExampleFuriganaText;
        final unit = find.byWidget(widget);
        var offset = 0;
        for (final segment in widget.segments) {
          if (segment.ruby != null) {
            final ruby = find.descendant(
              of: unit,
              matching: find.byKey(ValueKey('example-ruby-$offset')),
            );
            final kanji = find.descendant(
              of: unit,
              matching: find.text(segment.text),
            );
            expect(ruby, findsOneWidget);
            expect(
              tester.getBottomLeft(ruby).dy,
              lessThanOrEqualTo(tester.getTopLeft(kanji).dy),
            );
          }
          offset += segment.text.length;
        }
      }
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
      expect(find.byType(ExampleFuriganaText), findsWidgets);
      expect(find.text('にほんご', findRichText: true), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('grammar_chat_close')));
      await tester.pumpAndSettle();
      expect(find.text('Open chat'), findsOneWidget);
    });
  }
  testWidgets(
    'old unstructured replies fail visibly and manual retry renders validated examples',
    (tester) async {
      var calls = 0;
      final client = JlptApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          calls++;
          return http.Response(
            jsonEncode({
              'reply': calls == 1
                  ? '映画えいが and incomplete readings'
                  : '[[example:1]]',
              if (calls > 1)
                'examples': [
                  {
                    'japanese': '映画を見ます。',
                    'sentence_furigana': '{映画|えいが}を{見|み}ます。',
                    'translation': 'I watch a movie.',
                  },
                ],
              'follow_up_questions': ['Why?', 'When?', 'How?'],
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
            home: GrammarQaChatScreen(grammar: _grammar, languageCode: 'en'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(
        find.text(
          'The AI service returned an incomplete response. Please try again.',
        ),
        findsOneWidget,
      );
      expect(find.byType(ExampleFuriganaText), findsNothing);
      await tester.tap(find.widgetWithText(TextButton, 'Try again'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.byType(ExampleFuriganaText), findsOneWidget);
      expect(find.text('I watch a movie.'), findsOneWidget);
      final messages = tester
          .widget<AiChatWidget>(find.byType(AiChatWidget))
          .controller
          .messages;
      expect(messages, hasLength(1));
      expect(messages.single.user.id, 'ai');
      expect(tester.takeException(), isNull);
    },
  );

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
