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
    this.part = 0,
    this.rank = 0,
    this.itemType = '',
    this.source = 'app_authored',
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
  final int part;
  final int rank;
  final String itemType;
  final String source;

  String localizedExplanation(String language) =>
      language == 'ko' && explanationKo.isNotEmpty
      ? explanationKo
      : explanationEn;
}

/// A practice test assembled for one JLPT level and practice number.
/// Catalog-generated vocabulary/grammar and ranked reading/listening variants
/// all carry official item-type metadata and are combined into ten practices.
class GeneratedPracticeSet {
  const GeneratedPracticeSet({
    required this.items,
    required this.vocabularyQuestions,
  });

  final List<MockTestProblem> items;
  final List<QuizQuestion> vocabularyQuestions;
}
