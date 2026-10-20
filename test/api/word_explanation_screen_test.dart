import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jlpt_practice/core/api/jlpt_api_client.dart';
import 'package:jlpt_practice/features/vocabulary/word_explanation_screen.dart';
import 'package:jlpt_practice/features/vocabulary/example_furigana_text.dart';
import 'jlpt_word_service_test.dart' show wordResponse;

Widget app(JlptApiClient client) => ProviderScope(
  overrides: [jlptApiClientProvider.overrideWithValue(client)],
  child: const MaterialApp(
    home: WordExplanationScreen(
      word: '準備',
      contextSentence: '旅行の準備',
      level: 'N4',
      language: 'en',
    ),
  ),
);

void main() {
  testWidgets(
    'package chat explains automatically and continues in the same conversation',
    (tester) async {
      final requests = <http.Request>[];
      final client = JlptApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          requests.add(request);
          return _jsonResponse(
            jsonEncode(
              request.url.path == '/api/words/explain'
                  ? wordResponse()
                  : {
                      'reply': 'Use 準備をする.',
                      'follow_up_questions': ['Why?', 'When?', 'How?'],
                    },
            ),
            200,
          );
        }),
      );
      addTearDown(client.close);
      await tester.pumpWidget(app(client));
      await tester.pumpAndSettle();
      expect(find.byType(AiChatWidget), findsOneWidget);
      expect(
        find.byKey(const ValueKey('word_explanation_input')),
        findsNothing,
      );
      expect(requests, hasLength(1));
      expect(requests.single.url.path, '/api/words/explain');
      expect(jsonDecode(requests.single.body), {
        'word': '準備',
        'context': '旅行の準備',
        'level': 'N4',
        'explanation_language': 'English',
      });
      var messages = tester
          .widget<AiChatWidget>(find.byType(AiChatWidget))
          .controller
          .messages;
      expect(messages, hasLength(1));
      expect(messages.every((message) => message.user.id == 'ai'), isTrue);
      expect(messages.last.text, contains('## 準備 · じゅんび'));
      expect(messages.last.text, contains('Original AI examples'));
      expect(messages.last.isMarkdown, isTrue);
      // Both the answer and all three questions arrive before any user action.
      expect(messages.last.customProperties?['followUpQuestions'], [
        'How is it used?',
        'What is 用意?',
        'Another example?',
      ]);
      for (final question in [
        'How is it used?',
        'What is 用意?',
        'Another example?',
      ]) {
        expect(find.widgetWithText(OutlinedButton, question), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('word_explain_send')), findsNothing);

      final question = find.widgetWithText(OutlinedButton, 'How is it used?');
      await tester.ensureVisible(question);
      await tester.tap(question);
      await tester.pumpAndSettle();
      expect(find.byType(WordExplanationScreen), findsOneWidget);
      expect(requests, hasLength(2));
      expect(requests.last.url.path, '/api/tutor/chat');
      final body = jsonDecode(requests.last.body) as Map;
      expect(body['message'], 'How is it used?');
      expect(body['question']['question_text'], contains('準備'));
      expect(body['question']['passage'], contains('Preparation'));
      expect(body['history'], hasLength(2));
      expect(body['history'][1]['content'], contains('Preparation'));
      messages = tester
          .widget<AiChatWidget>(find.byType(AiChatWidget))
          .controller
          .messages;
      expect(messages, hasLength(3));
      expect(messages.last.text, 'Use 準備をする.');
      // Typed follow-ups also use this conversation and the same tutor endpoint.
      await tester.enterText(find.byType(TextField), 'Another use?');
      await tester.tap(find.byKey(const ValueKey('word_chat_send')));
      await tester.pumpAndSettle();
      expect(requests, hasLength(3));
      expect(jsonDecode(requests.last.body)['message'], 'Another use?');
      expect(jsonDecode(requests.last.body)['history'], hasLength(4));
      expect(tester.takeException(), isNull);
    },
  );

  for (final legacy in [false, true]) {
    testWidgets('chat renders example furigana above kanji (legacy: $legacy)', (
      tester,
    ) async {
      final data = wordResponse();
      if (!legacy) {
        data['meanings'][0]['examples'][0]['sentence_furigana'] =
            '{旅行|りょこう}の{準備|じゅんび}をする。';
      }
      final client = JlptApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((_) async => _jsonResponse(jsonEncode(data), 200)),
      );
      addTearDown(client.close);
      await tester.pumpWidget(app(client));
      await tester.pumpAndSettle();
      expect(find.byType(ExampleFuriganaText), findsNWidgets(2));
      for (final pair in [('旅行', 'りょこう'), ('準備', 'じゅんび')]) {
        final unit = find.byWidgetPredicate(
          (widget) =>
              widget is ExampleFuriganaText &&
              widget.segments.single.text == pair.$1,
        );
        final ruby = find.descendant(
          of: unit,
          matching: find.text(pair.$2, findRichText: true),
        );
        final kanji = find.descendant(of: unit, matching: find.text(pair.$1));
        expect(ruby, findsOneWidget);
        expect(kanji, findsOneWidget);
        expect(
          tester.getBottomLeft(ruby).dy,
          lessThanOrEqualTo(tester.getTopLeft(kanji).dy),
        );
      }
      expect(find.text('りょこうのじゅんびをする。', findRichText: true), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('usage comparisons have ruby and omit metadata sections', (
    tester,
  ) async {
    final data = wordResponse();
    data['natural_vs_unnatural'] = [
      {
        'natural_example': '旅行の土産として、地元の和菓子を買った。',
        'natural_example_furigana':
            '{旅行|りょこう}の{土産|みやげ}として、{地元|じもと}の{和菓子|わがし}を{買|か}った。',
        'unnatural_example': '旅行の土産として、地元の和菓子を持ってきた。',
        'unnatural_example_furigana':
            '{旅行|りょこう}の{土産|みやげ}として、{地元|じもと}の{和菓子|わがし}を{持|も}ってきた。',
        'explanation': '買った emphasizes purchasing the gift.',
      },
    ];
    data['approximate_difficulty_label'] = 'Approximate difficulty';
    data['notice'] = 'Study notice';
    data['verified_past_exam_examples'] = [
      {'japanese': 'Old exam text'},
    ];
    final client = JlptApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((_) async => _jsonResponse(jsonEncode(data), 200)),
    );
    addTearDown(client.close);
    await tester.pumpWidget(app(client));
    await tester.pumpAndSettle();
    final messages = tester
        .widget<AiChatWidget>(find.byType(AiChatWidget))
        .controller
        .messages;
    final text = messages.single.text;
    expect(
      text,
      contains('✓ {旅行|りょこう}の{土産|みやげ}として、{地元|じもと}の{和菓子|わがし}を{買|か}った。'),
    );
    expect(
      text,
      contains('✗ {旅行|りょこう}の{土産|みやげ}として、{地元|じもと}の{和菓子|わがし}を{持|も}ってきた。'),
    );
    for (final excluded in [
      'Past-exam',
      'Approximate difficulty',
      'Study notice',
      'Old exam text',
    ]) {
      expect(text, isNot(contains(excluded)));
    }
    final units = find.byType(ExampleFuriganaText);
    expect(units, findsNWidgets(12));
    for (final element in units.evaluate()) {
      final widget = element.widget as ExampleFuriganaText;
      final unit = find.byWidget(widget);
      final segment = widget.segments.single;
      final ruby = find.descendant(
        of: unit,
        matching: find.text(segment.ruby!, findRichText: true),
      );
      final kanji = find.descendant(
        of: unit,
        matching: find.text(segment.text),
      );
      expect(
        tester.getBottomLeft(ruby).dy,
        lessThanOrEqualTo(tester.getTopLeft(kanji).dy),
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failed explanation retries without duplicate messages or a tutor request',
    (tester) async {
      final requests = <http.Request>[];
      final client = JlptApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          requests.add(request);
          return requests.length == 1
              ? _jsonResponse('{}', 503)
              : _jsonResponse(jsonEncode(wordResponse()), 200);
        }),
      );
      addTearDown(client.close);
      await tester.pumpWidget(app(client));
      await tester.pumpAndSettle();
      expect(requests, hasLength(1));
      expect(
        tester
            .widget<AiChatWidget>(find.byType(AiChatWidget))
            .controller
            .messages,
        isEmpty,
      );
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(requests, hasLength(2));
      expect(requests.every((r) => r.url.path == '/api/words/explain'), isTrue);
      expect(requests[0].body, requests[1].body);
      final messages = tester
          .widget<AiChatWidget>(find.byType(AiChatWidget))
          .controller
          .messages;
      expect(messages, hasLength(1));
      expect(messages.single.user.id, 'ai');
      expect(messages.last.text, contains('## 準備 · じゅんび'));
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
    },
  );

  testWidgets('closing while initial explanation loads avoids late UI writes', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    final client = JlptApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((_) => pending.future),
    );
    addTearDown(client.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [jlptApiClientProvider.overrideWithValue(client)],
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const WordExplanationScreen(
                      word: '準備',
                      level: 'N4',
                      language: 'en',
                    ),
                  ),
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
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.byKey(const ValueKey('chat_ai_loading_bubble')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<AiChatWidget>(find.byType(AiChatWidget))
          .controller
          .messages,
      isEmpty,
    );
    await tester.tap(find.byKey(const ValueKey('word_chat_close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    pending.complete(_jsonResponse(jsonEncode(wordResponse()), 200));
    await tester.pumpAndSettle();
    expect(find.text('Open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

http.Response _jsonResponse(String body, int status) => http.Response(
  body,
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
