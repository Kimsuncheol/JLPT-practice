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

  Future<List<MockTestProblem>> load() async {
    final raw = await rootBundle.loadString(
      'assets/data/jlpt_test_problems_2021_2025.csv',
    );
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
          final correctAnswer =
              allChoices[correctIndex < 0 ? 0 : correctIndex];
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
          );
        })
        .toList(growable: false);
  }
}
