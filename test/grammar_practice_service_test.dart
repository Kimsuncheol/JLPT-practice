import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/data/models/grammar_point.dart';
import 'package:jlpt_practice/features/grammar/grammar_practice_service.dart';
import 'package:jlpt_practice/features/offline_ai/offline_ai_controller.dart';

void main() {
  test(
    'practice tutor sends grammar and recent conversation to Gemma',
    () async {
      final controller = _RecordingController();
      final service = GrammarPracticeService(controller);
      final answer = await service.reply(
        grammar: _grammar,
        message: '寿司が一番好きです。',
        languageCode: 'en',
        history: const [
          GrammarPracticeTurn(isUser: true, text: 'Give me a practice task'),
          GrammarPracticeTurn(isUser: false, text: 'Write a sentence.'),
        ],
      );

      expect(answer, 'Good sentence.');
      expect(
        controller.system,
        contains('assess whether it uses the target grammar'),
      );
      final input = jsonDecode(controller.input!) as Map<String, dynamic>;
      expect(input['title'], _grammar.title);
      expect(input['message'], '寿司が一番好きです。');
      expect(input['practiceTask'], isFalse);
      expect(input['conversation'], [
        {'role': 'user', 'text': 'Give me a practice task'},
        {'role': 'assistant', 'text': 'Write a sentence.'},
      ]);
    },
  );

  test(
    'practice task requests explanation, examples, then a learner example',
    () async {
      final controller = _RecordingController();
      await GrammarPracticeService(controller).reply(
        grammar: _grammar,
        message: 'Give me a practice task',
        languageCode: 'en',
        history: const [],
        practiceTask: true,
      );

      final input = jsonDecode(controller.input!) as Map<String, dynamic>;
      expect(input['practiceTask'], isTrue);
      expect(
        controller.system,
        contains('briefly explain the target grammar point'),
      );
      expect(controller.system, contains('two'));
      expect(controller.system, contains('ask'));
      expect(
        controller.system,
        contains('create another Japanese example sentence'),
      );
    },
  );
}

class _RecordingController extends Fake implements OfflineAiController {
  String? system;
  String? input;

  @override
  Future<String> generate(String system, String input) async {
    this.system = system;
    this.input = input;
    return ' Good sentence. ';
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
