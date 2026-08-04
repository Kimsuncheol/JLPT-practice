import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/data/models/mock_test_problem.dart';
import 'package:jlpt_practice/data/repositories/mock_test_problem_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads and parses every reading problem row from the CSV asset', () async {
    final problems = await const MockTestProblemRepository().load();

    // The CSV only holds the static reading passages now; vocabulary and
    // grammar problems are generated at runtime from the app's own word and
    // grammar-point catalogs (see practice_test_generator.dart).
    expect(problems.length, 60);
    for (final problem in problems) {
      expect(problem.section, ProblemSection.reading);
      expect(problem.passage, isNotEmpty);
    }
    for (final level in ['N1', 'N2', 'N3', 'N4', 'N5']) {
      expect(
        problems.where((p) => p.level == level).length,
        12,
        reason: '$level should have 12 reading problems',
      );
    }

    for (final problem in problems) {
      expect(problem.choices, hasLength(4));
      expect(problem.choices, contains(problem.correctAnswer));
      expect(problem.question, isNotEmpty);
      expect(problem.explanationEn, isNotEmpty);
      expect(problem.explanationKo, isNotEmpty);
    }

    final ids = problems.map((p) => p.id).toSet();
    expect(ids.length, problems.length, reason: 'ids should be unique');
  });
}
