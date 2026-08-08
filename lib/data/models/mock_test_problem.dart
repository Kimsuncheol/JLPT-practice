import 'package:jlpt_practice/data/models/quiz.dart';

enum ProblemSection { vocabulary, grammar, reading, listening }

String sectionPathSegment(ProblemSection section) => switch (section) {
  ProblemSection.vocabulary => 'vocabulary',
  ProblemSection.grammar => 'grammar',
  ProblemSection.reading => 'reading',
  ProblemSection.listening => 'listening',
};

ProblemSection? sectionFromPathSegment(String value) => switch (value) {
  'vocabulary' => ProblemSection.vocabulary,
  'grammar' => ProblemSection.grammar,
  'reading' => ProblemSection.reading,
  'listening' => ProblemSection.listening,
  _ => null,
};

class MockTestProblem {
  const MockTestProblem({
    required this.id,
    required this.level,
    required this.section,
    required this.passage,
    required this.question,
    required this.choices,
    required this.correctAnswer,
    required this.explanationEn,
    required this.explanationKo,
  });

  final String id;
  final String level;
  final ProblemSection section;
  final String passage;
  final String question;
  final List<String> choices;
  final String correctAnswer;
  final String explanationEn;
  final String explanationKo;

  String localizedExplanation(String language) =>
      language == 'ko' && explanationKo.isNotEmpty
      ? explanationKo
      : explanationEn;
}

/// A practice test assembled for one JLPT level and one scheduled sitting:
/// vocabulary and grammar problems are generated from the app's own word and
/// grammar-point catalogs (seeded per sitting so each date gets a different
/// selection), while reading and listening problems come from the static
/// problem bank.
class GeneratedPracticeSet {
  const GeneratedPracticeSet({
    required this.items,
    required this.vocabularyQuestions,
  });

  final List<MockTestProblem> items;
  final List<QuizQuestion> vocabularyQuestions;
}
