import 'dart:convert';
import 'package:jlpt_practice/core/api/tutor_example.dart';
import 'package:jlpt_practice/core/api/jlpt_api_client.dart';
import 'package:jlpt_practice/data/models/grammar_point.dart';
import 'package:jlpt_practice/data/models/mock_test_problem.dart';

class TutorTurn {
  const TutorTurn({required this.isUser, required this.text});
  final bool isUser;
  final String text;
}

class TutorReply {
  const TutorReply({required this.text, this.followUpQuestions = const []});
  final String text;
  final List<String> followUpQuestions;
}

List<String> _followUpQuestions(Object? value) {
  if (value is! List) return const [];
  return List.unmodifiable(
    value
        .whereType<String>()
        .map((text) => text.trim())
        .where((text) => text.isNotEmpty && text.runes.length <= 500)
        .toSet()
        .take(3),
  );
}

class JlptTutorService {
  const JlptTutorService(this.client);
  final JlptApiClient client;

  Future<TutorReply> fetchReply({
    required bool practiceItem,
    required String level,
    required String language,
    required Map<String, dynamic> context,
    required String message,
    required List<TutorTurn> history,
    bool structuredExamples = false,
  }) async {
    final text = message.trim();
    if (text.isEmpty || text.runes.length > 500) {
      throw const JlptApiException('aiRequestInvalid');
    }
    final recent = history
        .where((turn) => turn.text.trim().isNotEmpty)
        .toList();
    final payload = <String, dynamic>{
      'level': level,
      if (structuredExamples) 'structured_examples': true,
      'explanation_language': explanationLanguage(language),
      'question': context,
      'message': text,
      'history': [
        for (final turn in recent.skip(
          recent.length > 6 ? recent.length - 6 : 0,
        ))
          {
            'role': turn.isUser ? 'user' : 'assistant',
            'content': boundedText(turn.text, 500),
          },
      ],
    };
    final messages = payload['history'] as List;
    while (utf8.encode(jsonEncode(payload)).length > 16000 &&
        messages.isNotEmpty) {
      messages.removeRange(0, messages.length >= 2 ? 2 : 1);
    }
    final response = await client.request(
      practiceItem ? '/api/tutor' : '/api/tutor/chat',
      body: payload,
    );
    final reply = response['reply'];
    if (reply is! String || reply.trim().isEmpty || reply.length > 20000) {
      throw const JlptApiException('aiResponseInvalid');
    }
    return TutorReply(
      text: _renderExamples(
        reply.trim(),
        response['examples'],
        required: structuredExamples,
      ),
      followUpQuestions: _followUpQuestions(response['follow_up_questions']),
    );
  }

  Future<String> reply({
    required bool practiceItem,
    required String level,
    required String language,
    required Map<String, dynamic> context,
    required String message,
    required List<TutorTurn> history,
  }) async => (await fetchReply(
    practiceItem: practiceItem,
    level: level,
    language: language,
    context: context,
    message: message,
    history: history,
  )).text;

  /// Current tutor endpoints return only reply text. Ask the same service for
  /// a small structured list, without delaying or replacing the main answer.
  Future<List<String>> suggestFollowUps({
    required bool practiceItem,
    required String level,
    required String language,
    required Map<String, dynamic> context,
    required List<TutorTurn> history,
  }) async {
    final raw = await reply(
      practiceItem: practiceItem,
      level: level,
      language: language,
      context: context,
      history: history,
      message:
          'Suggest three short follow-up questions that I, the learner, can ask '
          'about your previous answer and this lesson. Write them in ${explanationLanguage(language)}. '
          'Return only a JSON array of three question strings. Do not answer the questions.',
    );
    var json = raw.trim();
    if (json.startsWith('```')) {
      json = json
          .replaceFirst(RegExp(r'^```(?:json)?\s*'), '')
          .replaceFirst(RegExp(r'\s*```$'), '');
    }
    try {
      return _followUpQuestions(jsonDecode(json));
    } on FormatException {
      return const [];
    }
  }
}

Map<String, dynamic> grammarTutorContext(
  GrammarPoint grammar,
  String language,
) {
  final examples = grammar.examples
      .take(2)
      .map((e) {
        final marked = e.sentenceSegments
            .map((s) => s.ruby == null ? s.text : '{${s.text}|${s.ruby}}')
            .join();
        return '$marked ${e.translation(language)}';
      })
      .join('\n');
  return {
    'id': boundedText(grammar.id, 80),
    'question_text': boundedText(
      '${grammar.title}\n${grammar.localizedSummary(language)}',
      500,
    ),
    'passage': boundedText(
      [
        grammar.localizedFormation(language),
        grammar.localizedExplanation(language),
        examples,
      ].join('\n'),
      800,
    ),
  };
}

Map<String, dynamic> practiceTutorContext(
  MockTestProblem problem,
  String selected,
  String language, {
  List<String>? optionExplanations,
  String? supportingSentence,
}) {
  final index = problem.choices.indexOf(problem.correctAnswer);
  if (problem.choices.length != 4 ||
      index < 0 ||
      problem.choices.any((option) => option.runes.length > 200) ||
      selected.runes.length > 200) {
    throw const JlptApiException('aiRequestInvalid');
  }
  return {
    'id': boundedText(problem.id, 80),
    'passage': boundedText(problem.passage, 800),
    'question_text': boundedText(problem.question, 500),
    'options': problem.choices,
    'correct_index': index,
    'correct_answer': problem.correctAnswer,
    'selected_answer': selected,
    if (supportingSentence != null)
      'supporting_sentence': boundedText(supportingSentence, 350),
    // Attach stored explanations only to their corresponding options.
    'option_explanations':
        optionExplanations != null && optionExplanations.length == 4
        ? optionExplanations.map((text) => boundedText(text, 400)).toList()
        : [
            for (var i = 0; i < 4; i++)
              i == index
                  ? boundedText(
                      problem.localizedExplanation(
                        language == 'Korean' ? 'ko' : language,
                      ),
                      600,
                    )
                  : '',
          ],
  };
}

String _renderExamples(String reply, Object? raw, {required bool required}) {
  try {
    if (raw == null && !required) return reply;
    if (raw is! List || raw.length > 4 || (required && raw.isEmpty)) {
      throw const FormatException();
    }
    final examples = raw.map((value) {
      if (value is! Map<String, dynamic>) throw const FormatException();
      return TutorExample.fromJson(value);
    }).toList();
    final marker = RegExp(r'\[\[example:([^\]]*)\]\]');
    final matches = marker.allMatches(reply).toList();
    final expected = {for (var i = 1; i <= examples.length; i++) '$i'};
    if (matches.length != examples.length ||
        matches.map((m) => m.group(1)).toSet().length != examples.length ||
        matches.any((m) => !expected.contains(m.group(1))) ||
        reply.replaceAll(marker, '').contains('[[example:')) {
      throw const FormatException();
    }
    return reply.replaceAllMapped(
      marker,
      (m) => examples[int.parse(m.group(1)!) - 1].markdownBlock,
    );
  } on FormatException {
    throw const JlptApiException('aiResponseInvalid');
  }
}
