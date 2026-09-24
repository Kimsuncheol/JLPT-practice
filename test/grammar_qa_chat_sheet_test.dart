import 'package:flutter/material.dart';
import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/data/models/grammar_point.dart';
import 'package:jlpt_practice/features/grammar/grammar_qa_chat_sheet.dart';
import 'package:jlpt_practice/features/grammar/grammar_qa_service.dart';
import 'package:jlpt_practice/features/offline_ai/offline_ai_controller.dart';

void main() {
  testWidgets(
    'grammar chat suggestions and composer use the existing service',
    (tester) async {
      final service = _GrammarService();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            grammarQaServiceProvider.overrideWith((ref) async => service),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => FilledButton(
                  onPressed: () => showGrammarQaChatSheet(
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
      await tester.tap(find.text('When do I use this?').first);
      await tester.pumpAndSettle();
      expect(service.questions, ['When do I use this?']);
      final chat = tester.widget<AiChatWidget>(find.byType(AiChatWidget));
      expect(
        chat.controller.messages.map((message) => message.text),
        contains('Use it for superlatives.'),
      );

      await tester.enterText(find.byType(TextField).last, 'Another example?');
      await tester.tap(find.byTooltip('Send'));
      await tester.pumpAndSettle();
      expect(service.questions, ['When do I use this?', 'Another example?']);
      expect(
        chat.controller.messages.map((message) => message.text),
        contains('Another example?'),
      );
      expect(tester.takeException(), isNull);
    },
  );
}

class _GrammarService extends GrammarQaService {
  _GrammarService() : super(_UnusedOfflineAiController());

  final List<String> questions = [];

  @override
  Future<String> ask({
    required GrammarPoint grammar,
    required String question,
    required String languageCode,
  }) async {
    questions.add(question);
    return 'Use it for superlatives.';
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
