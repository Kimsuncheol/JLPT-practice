import 'package:jlpt_practice/data/models/mock_test_problem.dart';

/// Official JLPT item-type blueprint.
///
/// The JLPT publishes the item types and purposes, but actual live exams and
/// stable item counts are not reusable public data. This blueprint therefore
/// validates type coverage rather than claiming to reproduce an undisclosed
/// live test form.
/// Source: https://www.jlpt.jp/e/guideline/testsections.html
class JlptExamPart {
  const JlptExamPart(this.number, this.itemType);

  final int number;
  final String itemType;
}

const jlptExamBlueprint = <String, Map<ProblemSection, List<JlptExamPart>>>{
  'N1': {
    ProblemSection.vocabulary: [
      JlptExamPart(1, 'kanji_reading'),
      JlptExamPart(2, 'context_expression'),
      JlptExamPart(3, 'paraphrase'),
      JlptExamPart(4, 'usage'),
    ],
    ProblemSection.grammar: [
      JlptExamPart(5, 'selecting_grammar_form'),
      JlptExamPart(6, 'sentence_composition'),
      JlptExamPart(7, 'text_grammar'),
    ],
    ProblemSection.reading: [
      JlptExamPart(8, 'short_passage'),
      JlptExamPart(9, 'mid_size_passage'),
      JlptExamPart(10, 'long_passage'),
      JlptExamPart(11, 'integrated_comprehension'),
      JlptExamPart(12, 'thematic_long_passage'),
      JlptExamPart(13, 'information_retrieval'),
    ],
    ProblemSection.listening: [
      JlptExamPart(1, 'task_based_comprehension'),
      JlptExamPart(2, 'key_point_comprehension'),
      JlptExamPart(3, 'general_outline'),
      JlptExamPart(4, 'quick_response'),
      JlptExamPart(5, 'integrated_comprehension'),
    ],
  },
  'N2': {
    ProblemSection.vocabulary: [
      JlptExamPart(1, 'kanji_reading'),
      JlptExamPart(2, 'orthography'),
      JlptExamPart(3, 'word_formation'),
      JlptExamPart(4, 'context_expression'),
      JlptExamPart(5, 'paraphrase'),
      JlptExamPart(6, 'usage'),
    ],
    ProblemSection.grammar: [
      JlptExamPart(7, 'selecting_grammar_form'),
      JlptExamPart(8, 'sentence_composition'),
      JlptExamPart(9, 'text_grammar'),
    ],
    ProblemSection.reading: [
      JlptExamPart(10, 'short_passage'),
      JlptExamPart(11, 'mid_size_passage'),
      JlptExamPart(12, 'integrated_comprehension'),
      JlptExamPart(13, 'thematic_long_passage'),
      JlptExamPart(14, 'information_retrieval'),
    ],
    ProblemSection.listening: [
      JlptExamPart(1, 'task_based_comprehension'),
      JlptExamPart(2, 'key_point_comprehension'),
      JlptExamPart(3, 'general_outline'),
      JlptExamPart(4, 'quick_response'),
      JlptExamPart(5, 'integrated_comprehension'),
    ],
  },
  'N3': {
    ProblemSection.vocabulary: [
      JlptExamPart(1, 'kanji_reading'),
      JlptExamPart(2, 'orthography'),
      JlptExamPart(3, 'context_expression'),
      JlptExamPart(4, 'paraphrase'),
      JlptExamPart(5, 'usage'),
    ],
    ProblemSection.grammar: [
      JlptExamPart(1, 'selecting_grammar_form'),
      JlptExamPart(2, 'sentence_composition'),
      JlptExamPart(3, 'text_grammar'),
    ],
    ProblemSection.reading: [
      JlptExamPart(4, 'short_passage'),
      JlptExamPart(5, 'mid_size_passage'),
      JlptExamPart(6, 'long_passage'),
      JlptExamPart(7, 'information_retrieval'),
    ],
    ProblemSection.listening: [
      JlptExamPart(1, 'task_based_comprehension'),
      JlptExamPart(2, 'key_point_comprehension'),
      JlptExamPart(3, 'general_outline'),
      JlptExamPart(4, 'verbal_expressions'),
      JlptExamPart(5, 'quick_response'),
    ],
  },
  'N4': {
    ProblemSection.vocabulary: [
      JlptExamPart(1, 'kanji_reading'),
      JlptExamPart(2, 'orthography'),
      JlptExamPart(3, 'context_expression'),
      JlptExamPart(4, 'paraphrase'),
      JlptExamPart(5, 'usage'),
    ],
    ProblemSection.grammar: [
      JlptExamPart(1, 'selecting_grammar_form'),
      JlptExamPart(2, 'sentence_composition'),
      JlptExamPart(3, 'text_grammar'),
    ],
    ProblemSection.reading: [
      JlptExamPart(4, 'short_passage'),
      JlptExamPart(5, 'mid_size_passage'),
      JlptExamPart(6, 'information_retrieval'),
    ],
    ProblemSection.listening: [
      JlptExamPart(1, 'task_based_comprehension'),
      JlptExamPart(2, 'key_point_comprehension'),
      JlptExamPart(3, 'verbal_expressions'),
      JlptExamPart(4, 'quick_response'),
    ],
  },
  'N5': {
    ProblemSection.vocabulary: [
      JlptExamPart(1, 'kanji_reading'),
      JlptExamPart(2, 'orthography'),
      JlptExamPart(3, 'context_expression'),
      JlptExamPart(4, 'paraphrase'),
    ],
    ProblemSection.grammar: [
      JlptExamPart(1, 'selecting_grammar_form'),
      JlptExamPart(2, 'sentence_composition'),
      JlptExamPart(3, 'text_grammar'),
    ],
    ProblemSection.reading: [
      JlptExamPart(4, 'short_passage'),
      JlptExamPart(5, 'mid_size_passage'),
      JlptExamPart(6, 'information_retrieval'),
    ],
    ProblemSection.listening: [
      JlptExamPart(1, 'task_based_comprehension'),
      JlptExamPart(2, 'key_point_comprehension'),
      JlptExamPart(3, 'verbal_expressions'),
      JlptExamPart(4, 'quick_response'),
    ],
  },
};

List<JlptExamPart> blueprintParts(String level, ProblemSection section) =>
    jlptExamBlueprint[level]?[section] ?? const [];

class MockBlueprintComparison {
  const MockBlueprintComparison({
    required this.level,
    required this.missing,
    required this.unexpected,
  });

  final String level;
  final List<String> missing;
  final List<String> unexpected;

  bool get matches => missing.isEmpty && unexpected.isEmpty;
}

MockBlueprintComparison compareMockWithOfficialBlueprint(
  String level,
  Iterable<MockTestProblem> problems,
) {
  final expected = <String>{
    for (final section in ProblemSection.values)
      for (final part in blueprintParts(level, section))
        '${section.name}:${part.number}:${part.itemType}',
  };
  final actual = problems
      .where((problem) => problem.level == level)
      .map(
        (problem) =>
            '${problem.section.name}:${problem.part}:${problem.itemType}',
      )
      .toSet();
  return MockBlueprintComparison(
    level: level,
    missing: (expected.difference(actual).toList()..sort()),
    unexpected: (actual.difference(expected).toList()..sort()),
  );
}
