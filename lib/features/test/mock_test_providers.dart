import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/data/models/jlpt_test_schedule.dart';
import 'package:jlpt_practice/data/models/mock_test_problem.dart';
import 'package:jlpt_practice/data/repositories/jlpt_test_schedule_repository.dart';
import 'package:jlpt_practice/data/repositories/mock_test_problem_repository.dart';
import 'package:jlpt_practice/features/grammar/grammar_providers.dart';
import 'package:jlpt_practice/features/test/practice_test_generator.dart';

final mockTestProblemRepositoryProvider = Provider(
  (ref) => const MockTestProblemRepository(),
);

final mockTestProblemsProvider = FutureProvider.family<List<MockTestProblem>, String>(
  (ref, level) async {
    final problems = await ref.read(mockTestProblemRepositoryProvider).load();
    return problems.where((problem) => problem.level == level).toList(
      growable: false,
    );
  },
);

typedef PracticeTestKey = ({String level, String scheduleId});

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
        seed: key.scheduleId.hashCode,
      );
      return GeneratedPracticeSet(
        items: [...generated.items, ...readingProblems],
        vocabularyQuestions: generated.vocabularyQuestions,
      );
    });

final jlptTestScheduleRepositoryProvider = Provider(
  (ref) => const JlptTestScheduleRepository(),
);

final jlptTestSchedulesForLevelProvider =
    FutureProvider.family<List<JlptTestSchedule>, String>((ref, level) async {
      final schedules = await ref
          .read(jlptTestScheduleRepositoryProvider)
          .load();
      final filtered = schedules
          .where((schedule) => schedule.level == level)
          .toList(growable: false)
        ..sort((a, b) => b.examDate.compareTo(a.examDate));
      return filtered;
    });
