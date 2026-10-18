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
    testWidgets(
      'grammar chat automatically explains the lesson in $brightness mode',
      (tester) async {
        var requests = 0;
        final response = Completer<http.Response>();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              jlptApiClientProvider.overrideWithValue(
                JlptApiClient(
                  baseUrl: 'https://example.test',
                  client: MockClient((request) async {
                    requests++;
                    expect(request.url.path, '/api/tutor/chat');
                    final data = jsonDecode(request.body) as Map;
                    expect(
                      data['message'],
                      contains('Explain this grammar point'),
                    );
                    expect(
                      data['question']['question_text'],
                      contains(_grammar.title),
                    );
                    expect(data['history'], isEmpty);
                    return response.future;
                  }),
                ),
              ),
            ],
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
        expect(requests, 0);
        await tester.tap(find.text('Open chat'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(requests, 1);
        expect(find.byType(ActionChip), findsNothing);
        expect(find.text('When do I use this?'), findsNothing);
        expect(find.text('Give me another example'), findsNothing);
        expect(
          find.byKey(const ValueKey('chat_ai_loading_bubble')),
          findsOneWidget,
        );
        response.complete(
          http.Response(
            jsonEncode({
              'reply': 'This grammar expresses the superlative.',
              'follow_up_questions': ['Can you explain the formation?'],
            }),
            200,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Grammar Tutor'), findsOneWidget);
        expect(find.byType(AiChatWidget), findsOneWidget);
        expect(
          tester.widget<TextField>(find.byType(TextField)).enabled,
          isTrue,
        );
        expect(
          tester
              .widget<IconButton>(
                find.widgetWithIcon(IconButton, Icons.send_rounded),
              )
              .onPressed,
          isNotNull,
        );
        expect(find.byType(ActionChip), findsNothing);
        expect(requests, 1);
        expect(
          tester
              .widget<AiChatWidget>(find.byType(AiChatWidget))
              .controller
              .messages
              .any(
                (message) =>
                    message.text == 'This grammar expresses the superlative.',
              ),
          isTrue,
        );
        expect(find.text('Can you explain the formation?'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('grammar_chat_close')));
        await tester.pumpAndSettle();
        expect(find.text('Open chat'), findsOneWidget);
      },
    );
  }
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
