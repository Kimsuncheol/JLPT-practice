import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/data/models/jlpt_test_schedule.dart';
import 'package:jlpt_practice/data/models/mock_test.dart';
import 'package:jlpt_practice/data/models/mock_test_problem.dart';
import 'package:jlpt_practice/data/models/quiz.dart';
import 'package:jlpt_practice/features/test/mock_test_providers.dart';

TestSectionType _sectionType(ProblemSection section) => switch (section) {
  ProblemSection.vocabulary => TestSectionType.vocabulary,
  ProblemSection.grammar => TestSectionType.grammar,
  ProblemSection.reading => TestSectionType.reading,
};

class PracticeTestScreen extends ConsumerStatefulWidget {
  const PracticeTestScreen({
    super.key,
    required this.level,
    required this.scheduleId,
    required this.section,
  });

  final String level;
  final String scheduleId;
  final ProblemSection section;

  @override
  ConsumerState<PracticeTestScreen> createState() =>
      _PracticeTestScreenState();
}

class _PracticeTestScreenState extends ConsumerState<PracticeTestScreen> {
  int _index = 0;
  String? _selected;
  bool _answered = false;
  final List<String> _incorrectIds = [];
  late final DateTime _startedAt = DateTime.now();
  Timer? _autoAdvanceTimer;
  List<QuizQuestion> _vocabularyQuestions = const [];

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    super.dispose();
  }

  Future<void> _advance(List<MockTestProblem> items) async {
    _autoAdvanceTimer?.cancel();
    if (_index < items.length - 1) {
      setState(() {
        _index++;
        _selected = null;
        _answered = false;
      });
      return;
    }
    final sections = <MockTestSectionResult>[];
    for (final type in TestSectionType.values) {
      final typeItems = items
          .where((item) => _sectionType(item.section) == type)
          .toList();
      if (typeItems.isEmpty) continue;
      final ids = typeItems.map((item) => item.id).toSet();
      final sectionIncorrect = _incorrectIds
          .where(ids.contains)
          .toSet()
          .toList(growable: false);
      sections.add(
        MockTestSectionResult(
          type: type,
          total: typeItems.length,
          correct: typeItems.length - sectionIncorrect.length,
          incorrectIds: sectionIncorrect,
        ),
      );
    }
    final result = MockTestResult(
      sections: sections,
      duration: DateTime.now().difference(_startedAt),
    );
    await ref
        .read(appControllerProvider.notifier)
        .recordMockTestResult(
          result,
          vocabularyQuestions: _vocabularyQuestions,
        );
    if (mounted) {
      context.go(
        '/test/practice/${widget.level}/${widget.scheduleId}/'
        '${sectionPathSegment(widget.section)}/result',
      );
    }
  }

  String _sectionLabel(BuildContext context, ProblemSection section) =>
      switch (section) {
        ProblemSection.vocabulary => context.strings('sectionVocabulary'),
        ProblemSection.grammar => context.strings('grammar'),
        ProblemSection.reading => context.strings('sectionReading'),
      };

  String _instruction(BuildContext context, ProblemSection section) =>
      switch (section) {
        ProblemSection.vocabulary => context.strings('quizInstruction'),
        ProblemSection.grammar => context.strings('grammarQuizInstruction'),
        ProblemSection.reading => context.strings('readingQuizInstruction'),
      };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider).requireValue;
    final practiceSetAsync = ref.watch(
      generatedPracticeSetProvider((
        level: widget.level,
        scheduleId: widget.scheduleId,
      )),
    );
    final schedules = ref
        .watch(jlptTestSchedulesForLevelProvider(widget.level))
        .value;
    JlptTestSchedule? schedule;
    if (schedules != null) {
      for (final candidate in schedules) {
        if (candidate.id == widget.scheduleId) {
          schedule = candidate;
          break;
        }
      }
    }
    final examTitle =
        schedule?.displayName ??
        '${widget.level} ${context.strings('practiceTest')}';
    return practiceSetAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(error.toString())),
      ),
      data: (practiceSet) {
        final items = practiceSet.items
            .where((item) => item.section == widget.section)
            .toList(growable: false);
        if (items.isEmpty) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(context.strings('noResults'))),
          );
        }
        _vocabularyQuestions = widget.section == ProblemSection.vocabulary
            ? practiceSet.vocabularyQuestions
            : const [];
        final item = items[_index];
        final isCorrect = _selected == item.correctAnswer;
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              onPressed: context.pop,
              icon: const Icon(Icons.close_rounded),
            ),
            title: Text('$examTitle · ${_sectionLabel(context, item.section)}'),
          ),
          body: SafeArea(
            top: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 6, 22, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: (_index + 1) / items.length,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        '${_index + 1}/${items.length}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 30, 22, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _instruction(context, item.section),
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (item.passage.isNotEmpty)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              item.passage,
                              style: const TextStyle(height: 1.7),
                            ),
                          ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 34,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: Text(
                            item.question,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              height: 1.6,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_answered)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: isCorrect
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer
                                  : Theme.of(
                                      context,
                                    ).colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              item.localizedExplanation(state.meaningLanguage),
                            ),
                          ),
                        ...item.choices.asMap().entries.map((entry) {
                          final choice = entry.value;
                          final selected = _selected == choice;
                          Color? color;
                          IconData? trailing;
                          if (_answered && choice == item.correctAnswer) {
                            color = Theme.of(
                              context,
                            ).colorScheme.primaryContainer;
                            trailing = Icons.check_circle_rounded;
                          } else if (_answered && selected) {
                            color = Theme.of(
                              context,
                            ).colorScheme.errorContainer;
                            trailing = Icons.cancel_rounded;
                          }
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Material(
                              color:
                                  color ??
                                  (selected
                                      ? Theme.of(
                                          context,
                                        ).colorScheme.secondaryContainer
                                      : Theme.of(context).colorScheme.surface),
                              borderRadius: BorderRadius.circular(19),
                              child: InkWell(
                                key: ValueKey('practice_test_choice_${entry.key}'),
                                onTap: _answered
                                    ? null
                                    : () {
                                        setState(() {
                                          _selected = choice;
                                          _answered = true;
                                          if (choice != item.correctAnswer) {
                                            _incorrectIds.add(item.id);
                                          }
                                        });
                                        _autoAdvanceTimer?.cancel();
                                        _autoAdvanceTimer = Timer(
                                          const Duration(milliseconds: 2200),
                                          () => _advance(items),
                                        );
                                      },
                                borderRadius: BorderRadius.circular(19),
                                child: Padding(
                                  padding: const EdgeInsets.all(17),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 30,
                                        height: 30,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest,
                                        ),
                                        child: Text(
                                          String.fromCharCode(65 + entry.key),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Text(
                                          choice,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      if (trailing != null) Icon(trailing),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
