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
          final choices = [
            cell(row, 'choice_a'),
            cell(row, 'choice_b'),
            cell(row, 'choice_c'),
            cell(row, 'choice_d'),
          ];
          const letters = ['A', 'B', 'C', 'D'];
          final correctIndex = letters.indexOf(cell(row, 'correct_answer'));
          return MockTestProblem(
            id: cell(row, 'id'),
            level: cell(row, 'level'),
            section: _sectionFromString(cell(row, 'section')),
            passage: cell(row, 'passage'),
            question: cell(row, 'question'),
            choices: choices,
            correctAnswer: choices[correctIndex < 0 ? 0 : correctIndex],
            explanationEn: cell(row, 'explanation_en'),
            explanationKo: cell(row, 'explanation_ko'),
          );
        })
        .toList(growable: false);
  }
}
