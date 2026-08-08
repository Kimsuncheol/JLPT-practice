import 'package:flutter/services.dart';
import 'package:jlpt_practice/data/models/mock_test_problem.dart';
import 'package:jlpt_practice/data/repositories/csv_utils.dart';

ProblemSection _sectionFromString(String value) => switch (value) {
  'grammar' => ProblemSection.grammar,
  'reading' => ProblemSection.reading,
  'listening' => ProblemSection.listening,
  _ => ProblemSection.vocabulary,
};

class MockTestProblemRepository {
  const MockTestProblemRepository();

  Future<List<MockTestProblem>> load() =>
      _loadProblems('assets/data/jlpt_test_problems_2021_2025.csv');
}

/// Ranked bank used by the app. The legacy repository above remains available
/// so the source/reference questions stay inspectable and testable.
class RankedMockTestProblemRepository {
  const RankedMockTestProblemRepository();

  Future<List<MockTestProblem>> load() =>
      _loadProblems('assets/data/jlpt_ranked_mock_questions.csv');
}

Future<List<MockTestProblem>> _loadProblems(String assetPath) async {
  final raw = await rootBundle.loadString(assetPath);
  final rows = parseCsvRows(raw);
  if (rows.isEmpty) return const [];
  final cell = csvCellReader(rows.first);

  return rows
      .skip(1)
      .map((row) {
        const letters = ['A', 'B', 'C', 'D'];
        final allChoices = [
          cell(row, 'choice_a'),
          cell(row, 'choice_b'),
          cell(row, 'choice_c'),
          cell(row, 'choice_d'),
        ];
        final correctIndex = letters.indexOf(cell(row, 'correct_answer'));
        final correctAnswer = allChoices[correctIndex < 0 ? 0 : correctIndex];
        // Some question types (e.g. listening quick-response) only have
        // 3 choices; drop empty trailing cells rather than render a blank,
        // unanswerable option.
        final choices = allChoices
            .where((choice) => choice.isNotEmpty)
            .toList(growable: false);
        return MockTestProblem(
          id: cell(row, 'id'),
          level: cell(row, 'level'),
          section: _sectionFromString(cell(row, 'section')),
          passage: cell(row, 'passage'),
          question: cell(row, 'question'),
          choices: choices,
          correctAnswer: correctAnswer,
          explanationEn: cell(row, 'explanation_en'),
          explanationKo: cell(row, 'explanation_ko'),
          part: int.tryParse(cell(row, 'part')) ?? 0,
          rank: int.tryParse(cell(row, 'rank')) ?? 0,
          itemType: cell(row, 'item_type'),
          source: cell(row, 'source').isEmpty ? 'legacy' : cell(row, 'source'),
        );
      })
      .toList(growable: false);
}
