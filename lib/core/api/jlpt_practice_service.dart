import 'package:jlpt_practice/core/api/jlpt_api_client.dart';
import 'package:jlpt_practice/data/models/mock_test_problem.dart';

class AiPracticeQuestion {
  const AiPracticeQuestion({
    required this.problem,
    required this.explanations,
    this.supportingSentence,
  });
  final MockTestProblem problem;
  final List<String> explanations;
  final String? supportingSentence;
}

class JlptPracticeService {
  const JlptPracticeService(this.client);
  final JlptApiClient client;

  Future<List<AiPracticeQuestion>> generate({
    required String level,
    required String category,
    required String language,
    int count = 3,
    String? topic,
  }) async {
    if (!['vocabulary', 'grammar', 'reading'].contains(category) ||
        count < 1 ||
        count > (category == 'reading' ? 3 : 5)) {
      throw const JlptApiException('aiRequestInvalid');
    }
    final single = topic != null;
    final data = await client.request(
      single ? '/api/practice/question' : '/api/practice/generate',
      body: {
        'level': level,
        'category': category,
        if (single)
          'topic': boundedText(topic, 200)
        else ...{
          'question_count': count,
          'explanation_language': explanationLanguage(language),
        },
      },
    );
    try {
      if (data['level'] != level || data['category'] != category) {
        throw const FormatException();
      }
      if (!single &&
          (data['explanation_language'] != explanationLanguage(language) ||
              data['question_count'] != count)) {
        throw const FormatException();
      }
      final passage = data['passage'] as String? ?? '';
      if (!single && category == 'reading' && passage.trim().isEmpty) {
        throw const FormatException();
      }
      final items = single ? [data] : data['questions'] as List;
      if (items.length != (single ? 1 : count)) throw const FormatException();
      return [
        for (final (index, raw) in items.indexed)
          _parse(
            raw as Map<String, dynamic>,
            index: index,
            level: level,
            category: category,
            language: language,
            passage: passage,
            single: single,
          ),
      ];
    } catch (_) {
      throw const JlptApiException('aiResponseInvalid');
    }
  }

  AiPracticeQuestion _parse(
    Map<String, dynamic> item, {
    required int index,
    required String level,
    required String category,
    required String language,
    required String passage,
    required bool single,
  }) {
    final question = item[single ? 'question' : 'question_text'] as String;
    final options = (item['options'] as List).cast<String>();
    final correct = item['correct_index'];
    final explanations = single
        ? List<String>.filled(4, item['explanation'] as String)
        : (item['option_explanations'] as List).cast<String>();
    if (question.trim().isEmpty ||
        options.length != 4 ||
        options.map((s) => s.trim()).toSet().length != 4 ||
        options.any((s) => s.trim().isEmpty || s.runes.length > 200) ||
        correct is! int ||
        correct < 0 ||
        correct > 3 ||
        explanations.length != 4 ||
        explanations.any((s) => s.trim().isEmpty) ||
        (!single && item['correct_answer'] != options[correct])) {
      throw const FormatException();
    }
    final explanation = explanations[correct];
    return AiPracticeQuestion(
      problem: MockTestProblem(
        id: single ? 'ai-topic-$index' : item['id'] as String,
        level: level,
        section: sectionFromPathSegment(category)!,
        passage: passage,
        question: question,
        choices: List.unmodifiable(options),
        correctAnswer: options[correct],
        explanationEn: explanation,
        explanationKo: !single && explanationLanguage(language) == 'Korean'
            ? explanation
            : '',
        source: 'ai_generated',
      ),
      explanations: List.unmodifiable(explanations),
      supportingSentence: item['supporting_sentence'] as String?,
    );
  }
}
