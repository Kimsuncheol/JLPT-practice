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
      'grammar chat opens with working controls in $brightness mode',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              jlptApiClientProvider.overrideWithValue(
                JlptApiClient(
                  baseUrl: 'https://example.test',
                  client: MockClient(
                    (_) async => http.Response('{"reply":"ok"}', 200),
                  ),
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
        expect(find.byType(ActionChip), findsNWidgets(3));
        expect(
          tester
              .widgetList<ActionChip>(find.byType(ActionChip))
              .every((chip) => chip.onPressed != null),
          isTrue,
        );
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
