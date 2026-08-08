import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/data/models/mock_test_problem.dart';
import 'package:jlpt_practice/data/models/jlpt_exam_blueprint.dart';
import 'package:jlpt_practice/data/repositories/grammar_repository.dart';
import 'package:jlpt_practice/data/repositories/vocabulary_repository.dart';
import 'package:jlpt_practice/features/test/practice_test_generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generates 12 vocabulary + 12 grammar problems from the real catalogs, '
      'deterministic per seed and varied across practices', () async {
    final vocabulary = await const VocabularyRepository().load();
    final grammarPoints = await const GrammarRepository().load();

    GeneratedPracticeSet build(int seed) => buildGeneratedPracticeSet(
      vocabulary: vocabulary,
      grammarPoints: grammarPoints,
      level: 'N5',
      meaningLanguage: 'en',
      seed: seed,
    );

    final julySet = build(stablePracticeSeed('2023-july-n5'));
    final decemberSet = build(stablePracticeSeed('2023-december-n5'));
    final julyAgain = build(stablePracticeSeed('2023-july-n5'));

    expect(julySet.items.length, 24);
    expect(
      julySet.items.where((i) => i.section == ProblemSection.vocabulary).length,
      12,
    );
    expect(
      julySet.items.where((i) => i.section == ProblemSection.grammar).length,
      12,
    );
    expect(julySet.vocabularyQuestions.length, 12);

    // Same seed reproduces the same selection.
    expect(
      julySet.items.map((i) => i.id).toList(),
      julyAgain.items.map((i) => i.id).toList(),
    );

    // Different practices draw a different selection of words/grammar.
    expect(
      julySet.items.map((i) => i.id).toSet(),
      isNot(decemberSet.items.map((i) => i.id).toSet()),
    );

    for (final item in julySet.items) {
      expect(item.level, 'N5');
      expect(item.choices, hasLength(4));
      expect(item.choices, contains(item.correctAnswer));
      expect(item.part, greaterThan(0));
      expect(item.rank, greaterThan(0));
      expect(item.itemType, isNotEmpty);
    }
    for (final section in [ProblemSection.vocabulary, ProblemSection.grammar]) {
      final actualParts = julySet.items
          .where((item) => item.section == section)
          .map((item) => item.part)
          .toSet();
      expect(
        actualParts,
        blueprintParts('N5', section).map((part) => part.number).toSet(),
      );
    }
  });
}
