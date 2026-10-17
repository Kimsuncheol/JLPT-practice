import 'package:flutter/material.dart';
import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/app/theme/app_theme.dart';
import 'package:jlpt_practice/data/models/grammar_point.dart';
import 'package:jlpt_practice/features/grammar/grammar_qa_chat_screen.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('grammar chat stays inactive in $brightness mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
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
      );
      await tester.tap(find.text('Open chat'));
      await tester.pumpAndSettle();
      expect(find.text('Grammar Tutor'), findsOneWidget);
      expect(find.byType(AiChatWidget), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.send_rounded),
            )
            .onPressed,
        isNull,
      );
      expect(find.byType(ActionChip), findsNWidgets(3));
      expect(
        tester
            .widgetList<ActionChip>(find.byType(ActionChip))
            .every((chip) => chip.onPressed == null),
        isTrue,
      );
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
