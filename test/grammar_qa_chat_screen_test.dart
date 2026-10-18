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
      final requests = <Map<String, dynamic>>[];
      final introduction = Completer<http.Response>();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            jlptApiClientProvider.overrideWithValue(
              JlptApiClient(
                baseUrl: 'https://example.test',
                client: MockClient((request) async {
                  requests.add(
                    jsonDecode(request.body) as Map<String, dynamic>,
                  );
                  return requests.length == 1
                      ? introduction.future
                      : http.Response(
                          '{"reply":"Follow-up answer","follow_up_questions":["Another example?"]}',
                          200,
                        );
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
      await tester.tap(find.text('Open chat'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(requests, hasLength(1));
      expect(
        requests.single['message'],
        contains('Explain this grammar point'),
      );
      expect(requests.single['explanation_language'], 'English');
      expect(
        (requests.single['question'] as Map)['passage'],
        contains(_grammar.explanation),
      );
      expect(find.byType(ActionChip), findsNothing);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      introduction.complete(
        http.Response(
          '{"reply":"Grammar explanation","follow_up_questions":["Another example?"]}',
          200,
        ),
      );
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
        find.text('Grammar explanation', findRichText: true),
        findsOneWidget,
      );
      await tester.tap(find.text('Another example?'));
      await tester.pumpAndSettle();
      expect(requests, hasLength(2));
      expect(requests.last['message'], 'Another example?');
      expect(requests.last['history'], hasLength(2));
      await tester.tap(find.byKey(const ValueKey('grammar_chat_close')));
      await tester.pumpAndSettle();
      expect(find.text('Open chat'), findsOneWidget);
    });
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
