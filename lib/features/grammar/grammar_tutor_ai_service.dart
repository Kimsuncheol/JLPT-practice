import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/data/models/grammar_point.dart';
import 'package:jlpt_practice/features/grammar/grammar_tutor_models.dart';

final grammarTutorEvaluatorProvider = FutureProvider<GrammarTutorEvaluator>(
  (_) => FirebaseGrammarTutorEvaluator.create(),
);

abstract class GrammarTutorEvaluator {
  Future<GrammarTutorFeedback> evaluate({
    required GrammarPoint grammar,
    required String sentence,
    required String explanationLanguage,
  });
}

class FirebaseGrammarTutorEvaluator implements GrammarTutorEvaluator {
  FirebaseGrammarTutorEvaluator._(this._model);

  static const _fallbackModel = 'gemini-3.6-flash';

  final GenerativeModel _model;

  static Future<FirebaseGrammarTutorEvaluator> create() async {
    var modelName = _fallbackModel;
    try {
      final config = FirebaseRemoteConfig.instance;
      await config.setDefaults(const {'ai_chat_model': _fallbackModel});
      await config.fetchAndActivate();
      final configured = config.getString('ai_chat_model').trim();
      if (configured.isNotEmpty) modelName = configured;
    } catch (_) {
      // Use the same stable fallback as free conversation.
    }
    return FirebaseGrammarTutorEvaluator._(
      FirebaseAI.googleAI().generativeModel(
        model: modelName,
        generationConfig: GenerationConfig(
          maxOutputTokens: 350,
          temperature: 0.2,
          responseMimeType: 'application/json',
        ),
      ),
    );
  }

  @override
  Future<GrammarTutorFeedback> evaluate({
    required GrammarPoint grammar,
    required String sentence,
    required String explanationLanguage,
  }) async {
    final examples = grammar.examples.map((item) => item.japanese).join('\n');
    final response = await _model.generateContent([
      Content.text('''
You are evaluating one Japanese sentence for a JLPT grammar lesson.
Target: ${grammar.title}
Meaning: ${grammar.summary}
Formation: ${grammar.formation}
Approved examples:
$examples

Learner sentence: $sentence

Return one JSON object only with these fields:
score: integer 0, 1, or 2 (2 correct and natural; 1 target is recognizable but needs correction; 0 target is absent or meaning is broken)
isCorrect: boolean
feedback: one concise explanation in $explanationLanguage
correctedSentence: corrected Japanese sentence, or the original when already correct
Do not assess facts beyond the supplied grammar record.
'''),
    ]);
    final raw = response.text?.trim();
    if (raw == null || raw.isEmpty) {
      throw StateError('The tutor returned empty feedback.');
    }
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return GrammarTutorFeedback(
      score: ((decoded['score'] as num?)?.toInt() ?? 0).clamp(0, 2),
      isCorrect: decoded['isCorrect'] as bool? ?? false,
      feedback: decoded['feedback'] as String? ?? '',
      correctedSentence: decoded['correctedSentence'] as String? ?? sentence,
    );
  }
}
