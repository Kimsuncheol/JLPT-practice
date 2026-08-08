import 'package:jlpt_practice/data/models/grammar_point.dart';

enum TestSectionType { vocabulary, grammar, reading, listening }

class GrammarQuestion {
  const GrammarQuestion({
    required this.grammarPoint,
    required this.choices,
    required this.correctAnswer,
  });

  final GrammarPoint grammarPoint;
  final List<String> choices;
  final String correctAnswer;
}

class MockTestSectionResult {
  const MockTestSectionResult({
    required this.type,
    required this.total,
    required this.correct,
    required this.incorrectIds,
  });

  final TestSectionType type;
  final int total;
  final int correct;
  final List<String> incorrectIds;

  int get incorrect => total - correct;
}

class MockTestResult {
  const MockTestResult({required this.sections, required this.duration});

  final List<MockTestSectionResult> sections;
  final Duration duration;

  int get total => sections.fold(0, (sum, section) => sum + section.total);
  int get correct =>
      sections.fold(0, (sum, section) => sum + section.correct);
  int get incorrect => total - correct;
  double get accuracy => total == 0 ? 0 : correct / total;

  MockTestSectionResult? sectionFor(TestSectionType type) {
    for (final section in sections) {
      if (section.type == type) return section;
    }
    return null;
  }
}
