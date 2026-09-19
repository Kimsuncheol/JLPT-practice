import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/data/models/mock_test_problem.dart';
import 'package:jlpt_practice/data/repositories/mock_test_problem_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads and parses every problem row from the CSV asset', () async {
    final problems = await const MockTestProblemRepository().load();

    // The bank combines a small hand-authored seed set (the original 81
    // rows, all with EN+KO explanations) with a much larger set of real
    // official JLPT questions imported across all five levels and every
    // section, including listening (see AGENTS/README history for how the
    // bank was built). Every level should now have real coverage in every
    // section except N5 listening, whose source material had no answer key.
    expect(problems.length, greaterThanOrEqualTo(526));

    for (final level in ['N1', 'N2', 'N3', 'N4', 'N5']) {
      final levelProblems = problems.where((p) => p.level == level).toList();
      expect(
        levelProblems,
        isNotEmpty,
        reason: '$level should have at least some problems',
      );
      for (final section in [
        ProblemSection.vocabulary,
        ProblemSection.grammar,
        ProblemSection.reading,
      ]) {
        expect(
          levelProblems.where((p) => p.section == section),
          isNotEmpty,
          reason: '$level should have ${section.name} problems',
        );
      }
    }
    // N5 has no listening problems (no official answer key was available
    // for the transcribed sample booklet); every other level does.
    for (final level in ['N1', 'N2', 'N3', 'N4']) {
      expect(
        problems.where(
          (p) => p.level == level && p.section == ProblemSection.listening,
        ),
        isNotEmpty,
        reason: '$level should have listening problems',
      );
    }
    expect(
      problems.where(
        (p) => p.level == 'N5' && p.section == ProblemSection.listening,
      ),
      isEmpty,
    );

    for (final problem in problems) {
      expect(problem.choices.length, inInclusiveRange(2, 4));
      expect(
        problem.choices,
        contains(problem.correctAnswer),
        reason: '${problem.id} correct answer must be one of its choices',
      );
      // Choices should never include a blank cell left over from a
      // shorter-than-4-option question type (e.g. listening quick-response).
      expect(problem.choices, everyElement(isNotEmpty));
      expect(problem.question, isNotEmpty);
      expect(problem.explanationEn, isNotEmpty);
    }

    final ids = problems.map((p) => p.id).toSet();
    expect(ids.length, problems.length, reason: 'ids should be unique');

    // The original hand-curated seed rows (id has no 'off-' prefix) should
    // still carry Korean explanations, since those were authored bilingually.
    final seedRows = problems.where((p) => !p.id.startsWith('off-'));
    expect(seedRows, isNotEmpty);
    for (final problem in seedRows) {
      expect(problem.explanationKo, isNotEmpty);
    }
  });
}
