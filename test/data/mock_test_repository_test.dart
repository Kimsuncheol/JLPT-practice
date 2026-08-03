import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/data/models/grammar_point.dart';
import 'package:jlpt_practice/data/models/mock_test.dart';
import 'package:jlpt_practice/data/repositories/mock_test_repository.dart';

GrammarPoint _point({
  required String id,
  required String level,
  required int rank,
  required String summary,
  String summaryKo = '',
}) => GrammarPoint(
  id: id,
  level: level,
  rank: rank,
  title: 'title-$id',
  summary: summary,
  explanation: 'explanation-$id',
  formation: 'formation-$id',
  summaryKo: summaryKo.isEmpty ? '$summary-ko' : summaryKo,
  examples: const [
    GrammarExample(japanese: '日本語', romaji: 'nihongo', english: 'Japanese'),
  ],
);

void main() {
  late List<GrammarPoint> catalog;

  setUp(() {
    catalog = [
      for (var i = 1; i <= 8; i++)
        _point(id: 'N5_$i', level: 'N5', rank: i, summary: 'summary-$i'),
      _point(id: 'N4_1', level: 'N4', rank: 1, summary: 'other-level'),
    ];
  });

  group('MockTestRepository.buildGrammarSection', () {
    test('filters strictly by level', () {
      final repository = MockTestRepository();
      final questions = repository.buildGrammarSection(
        catalog,
        level: 'N5',
        language: 'en',
        count: 20,
      );
      expect(questions, hasLength(8));
      expect(
        questions.every((question) => question.grammarPoint.level == 'N5'),
        isTrue,
      );
    });

    test('caps the result at the requested count', () {
      final repository = MockTestRepository();
      final questions = repository.buildGrammarSection(
        catalog,
        level: 'N5',
        language: 'en',
        count: 3,
      );
      expect(questions, hasLength(3));
    });

    test('choices contain the correct answer exactly once, no duplicates', () {
      final repository = MockTestRepository();
      final questions = repository.buildGrammarSection(
        catalog,
        level: 'N5',
        language: 'en',
        count: 8,
      );
      for (final question in questions) {
        expect(question.choices.toSet(), hasLength(question.choices.length));
        expect(
          question.choices.where((choice) => choice == question.correctAnswer),
          hasLength(1),
        );
      }
    });

    test('correctAnswer follows the requested language', () {
      final repository = MockTestRepository();
      final enQuestions = repository.buildGrammarSection(
        catalog,
        level: 'N5',
        language: 'en',
        count: 8,
      );
      final koQuestions = repository.buildGrammarSection(
        catalog,
        level: 'N5',
        language: 'ko',
        count: 8,
      );
      for (final question in enQuestions) {
        expect(
          question.correctAnswer,
          question.grammarPoint.localizedSummary('en'),
        );
      }
      for (final question in koQuestions) {
        expect(
          question.correctAnswer,
          question.grammarPoint.localizedSummary('ko'),
        );
      }
    });
  });

  group('MockTestResult aggregates', () {
    test('total/correct/accuracy sum across sections', () {
      const result = MockTestResult(
        sections: [
          MockTestSectionResult(
            type: TestSectionType.vocabulary,
            total: 10,
            correct: 8,
            incorrectIds: ['v1', 'v2'],
          ),
          MockTestSectionResult(
            type: TestSectionType.grammar,
            total: 10,
            correct: 6,
            incorrectIds: ['g1', 'g2', 'g3', 'g4'],
          ),
        ],
        duration: Duration(minutes: 4),
      );
      expect(result.total, 20);
      expect(result.correct, 14);
      expect(result.incorrect, 6);
      expect(result.accuracy, closeTo(0.7, 0.0001));
      expect(
        result.sectionFor(TestSectionType.vocabulary)!.correct,
        8,
      );
      expect(result.sectionFor(TestSectionType.grammar)!.incorrect, 4);
    });

    test('accuracy is zero when there are no questions', () {
      const result = MockTestResult(sections: [], duration: Duration.zero);
      expect(result.accuracy, 0);
      expect(result.sectionFor(TestSectionType.vocabulary), isNull);
    });
  });
}
