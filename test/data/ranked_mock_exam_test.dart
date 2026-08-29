import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/data/models/jlpt_exam_blueprint.dart';
import 'package:jlpt_practice/data/models/mock_test_problem.dart';
import 'package:jlpt_practice/data/repositories/grammar_repository.dart';
import 'package:jlpt_practice/data/repositories/mock_test_problem_repository.dart';
import 'package:jlpt_practice/data/repositories/vocabulary_repository.dart';
import 'package:jlpt_practice/features/test/practice_test_generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('legacy and ranked banks coexist', () async {
    final legacy = await const MockTestProblemRepository().load();
    final ranked = await const RankedMockTestProblemRepository().load();

    expect(legacy, isNotEmpty);
    expect(ranked, isNotEmpty);
    expect(ranked.every((item) => item.part > 0 && item.rank > 0), isTrue);
    expect(ranked.every((item) => item.itemType.isNotEmpty), isTrue);
    expect(
      ranked.every((item) => item.source != 'official_practice_reference'),
      isTrue,
    );
    expect(
      ranked.where(
        (item) =>
            item.level == 'N5' && item.section == ProblemSection.listening,
      ),
      isNotEmpty,
    );
  });

  test('every N1-N5 mock matches the official item-type blueprint', () async {
    final bank = await const RankedMockTestProblemRepository().load();
    final vocabulary = await const VocabularyRepository().load();
    final grammar = await const GrammarRepository().load();

    for (final level in ['N1', 'N2', 'N3', 'N4', 'N5']) {
      final generated = buildGeneratedPracticeSet(
        vocabulary: vocabulary,
        grammarPoints: grammar,
        level: level,
        meaningLanguage: 'en',
        seed: stablePracticeSeed('$level-part-1'),
      );
      final staticProblems = selectRankedStaticProblems(
        bank,
        level: level,
        practiceNumber: 1,
      );
      final comparison = compareMockWithOfficialBlueprint(level, [
        ...generated.items,
        ...staticProblems,
      ]);

      expect(
        comparison.matches,
        isTrue,
        reason:
            '$level missing=${comparison.missing} '
            'unexpected=${comparison.unexpected}',
      );
    }
  });

  test('reading and listening provide ten distinct practice sets', () async {
    final bank = await const RankedMockTestProblemRepository().load();

    for (final level in ['N1', 'N2', 'N3', 'N4', 'N5']) {
      final practices = List.generate(
        10,
        (index) => selectRankedStaticProblems(
          bank,
          level: level,
          practiceNumber: index + 1,
        ),
      );

      for (final section in [
        ProblemSection.reading,
        ProblemSection.listening,
      ]) {
        final signatures = practices
            .map(
              (items) => items
                  .where((item) => item.section == section)
                  .map((item) => item.id)
                  .join('|'),
            )
            .toSet();
        expect(signatures, hasLength(10), reason: '$level ${section.name}');
        for (final practice in practices) {
          expect(
            practice.where((item) => item.section == section).length,
            blueprintParts(level, section).length,
          );
        }
      }
    }
  });
}
