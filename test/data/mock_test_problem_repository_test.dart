import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/data/models/mock_test_problem.dart';
import 'package:jlpt_practice/data/repositories/mock_test_problem_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads and parses every problem row from the CSV asset', () async {
    final problems = await const MockTestProblemRepository().load();

    // Most of the bank is static reading passages; vocabulary and grammar
    // problems are otherwise generated at runtime from the app's own word
    // and grammar-point catalogs (see practice_test_generator.dart). N5 also
    // carries a static set of real vocabulary/grammar mondai imported from a
    // past paper, so it has extra rows beyond the shared 12-per-level
    // reading passages.
    expect(problems.length, 81);
    for (final level in ['N1', 'N2', 'N3', 'N4']) {
      final levelProblems = problems.where((p) => p.level == level).toList();
      expect(
        levelProblems.length,
        12,
        reason: '$level should have 12 reading problems',
      );
      for (final problem in levelProblems) {
        expect(problem.section, ProblemSection.reading);
        expect(problem.passage, isNotEmpty);
      }
    }

    final n5Problems = problems.where((p) => p.level == 'N5').toList();
    expect(n5Problems.length, 33);
    expect(
      n5Problems.where((p) => p.section == ProblemSection.reading).length,
      16,
    );
    expect(
      n5Problems.where((p) => p.section == ProblemSection.vocabulary).length,
      8,
    );
    expect(
      n5Problems.where((p) => p.section == ProblemSection.grammar).length,
      9,
    );

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
