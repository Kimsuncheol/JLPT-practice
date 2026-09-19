import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/data/models/mock_test_problem.dart';
import 'package:jlpt_practice/data/repositories/mock_test_problem_repository.dart';
import 'package:jlpt_practice/features/grammar/grammar_providers.dart';
import 'package:jlpt_practice/features/test/practice_test_generator.dart';

final mockTestProblemRepositoryProvider = Provider(
  (ref) => const RankedMockTestProblemRepository(),
);

final mockTestProblemsProvider =
    FutureProvider.family<List<MockTestProblem>, String>((ref, level) async {
      final problems = await ref.read(mockTestProblemRepositoryProvider).load();
      return problems
          .where((problem) => problem.level == level)
          .toList(growable: false);
    });

typedef PracticeTestKey = ({String level, int practiceNumber});

final generatedPracticeSetProvider =
    FutureProvider.family<GeneratedPracticeSet, PracticeTestKey>((
      ref,
      key,
    ) async {
      final state = await ref.watch(appControllerProvider.future);
      final grammarPoints = await ref.watch(grammarCatalogProvider.future);
      final readingProblems = await ref.watch(
        mockTestProblemsProvider(key.level).future,
      );
      final generated = buildGeneratedPracticeSet(
        vocabulary: state.vocabulary,
        grammarPoints: grammarPoints,
        level: key.level,
        meaningLanguage: state.meaningLanguage,
        seed: stablePracticeSeed(
          '${key.level}-${practiceSetId(key.practiceNumber)}',
        ),
      );
      return GeneratedPracticeSet(
        items: [
          ...generated.items,
          ...selectRankedStaticProblems(
            readingProblems,
            level: key.level,
            practiceNumber: key.practiceNumber,
          ),
        ],
        vocabularyQuestions: generated.vocabularyQuestions,
      );
    });
