import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/app/theme/app_theme.dart';
import 'package:jlpt_practice/data/models/grammar_point.dart';
import 'package:jlpt_practice/features/grammar/grammar_qa_chat_screen.dart';
import 'package:jlpt_practice/features/grammar/grammar_qa_service.dart';
import 'package:jlpt_practice/features/offline_ai/offline_ai_controller.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'grammar chat is a $brightness screen with persistent prompts',
      (tester) async {
        final service = _GrammarService();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              grammarQaServiceProvider.overrideWith((ref) async => service),
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
        expect(find.byType(GrammarQaChatScreen), findsOneWidget);
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.byIcon(Icons.close_rounded), findsOneWidget);
        expect(find.byType(ActionChip), findsNWidgets(3));
        expect(
          find.byKey(const ValueKey('chat_suggestions_container')),
          findsOneWidget,
        );
        final chat = tester.widget<AiChatWidget>(find.byType(AiChatWidget));
        final colors = brightness == Brightness.light
            ? AppTheme.light().colorScheme
            : AppTheme.dark().colorScheme;
        expect(
          chat.messageOptions!.bubbleStyle!.userBubbleColor,
          colors.primaryContainer,
        );
        expect(
          chat.messageOptions!.bubbleStyle!.aiBubbleColor,
          colors.surfaceContainerHigh,
        );

        final firstAnswer = Completer<String>();
        service.nextAnswer = firstAnswer;
        await tester.tap(find.text('When do I use this?').first);
        await tester.pump();
        expect(
          find.byKey(const ValueKey('chat_suggestions_container')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('chat_suggestions_scroll')),
          findsOneWidget,
        );
        expect(find.byType(ActionChip), findsNWidgets(3));
        expect(
          tester
              .widgetList<ActionChip>(find.byType(ActionChip))
              .every((chip) => chip.onPressed == null),
          isTrue,
        );
        firstAnswer.complete('Use it for superlatives.');
        await tester.pumpAndSettle();
        expect(service.questions, ['When do I use this?']);
        expect(find.byType(ActionChip), findsNWidgets(3));
        expect(
          find.byKey(const ValueKey('chat_suggestions_scroll')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('chat_suggestions_container')),
          findsNothing,
        );
        expect(
          chat.controller.messages.map((message) => message.text),
          contains('Use it for superlatives.'),
        );

        final pendingAnswer = Completer<String>();
        service.nextAnswer = pendingAnswer;
        await tester.tap(find.text('Give me another example').first);
        await tester.pump();
        expect(find.byType(ActionChip), findsNWidgets(3));
        expect(
          tester
              .widgetList<ActionChip>(find.byType(ActionChip))
              .every((chip) => chip.onPressed == null),
          isTrue,
        );
        pendingAnswer.complete('Here is another example.');
        await tester.pumpAndSettle();
        expect(find.byType(ActionChip), findsNWidgets(3));

        await tester.enterText(find.byType(TextField).last, 'Another example?');
        await tester.tap(find.byTooltip('Send'));
        await tester.pumpAndSettle();
        expect(service.questions, [
          'When do I use this?',
          'Give me another example',
          'Another example?',
        ]);
        await tester.tap(find.byKey(const ValueKey('grammar_chat_close')));
        await tester.pumpAndSettle();
        expect(find.byType(GrammarQaChatScreen), findsNothing);
        expect(find.text('Open chat'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class _GrammarService extends GrammarQaService {
  _GrammarService() : super(_UnusedOfflineAiController());

  final List<String> questions = [];
  Completer<String>? nextAnswer;

  @override
  Future<String> ask({
    required GrammarPoint grammar,
    required String question,
    required String languageCode,
  }) async {
    questions.add(question);
    final pending = nextAnswer;
    nextAnswer = null;
    return pending == null ? 'Use it for superlatives.' : pending.future;
  }
}

class _UnusedOfflineAiController extends Fake implements OfflineAiController {}

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
