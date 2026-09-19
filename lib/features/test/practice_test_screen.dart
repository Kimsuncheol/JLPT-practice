import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/core/services/tts_service.dart';
import 'package:jlpt_practice/core/services/volume_service.dart';
import 'package:jlpt_practice/data/models/mock_test.dart';
import 'package:jlpt_practice/data/models/mock_test_problem.dart';
import 'package:jlpt_practice/data/models/quiz.dart';
import 'package:jlpt_practice/features/test/mock_test_providers.dart';
import 'package:jlpt_practice/features/test/practice_ai_tutor_sheet.dart';
import 'package:jlpt_practice/features/test/practice_test_generator.dart';

TestSectionType _sectionType(ProblemSection section) => switch (section) {
  ProblemSection.vocabulary => TestSectionType.vocabulary,
  ProblemSection.grammar => TestSectionType.grammar,
  ProblemSection.reading => TestSectionType.reading,
  ProblemSection.listening => TestSectionType.listening,
};

class PracticeTestScreen extends ConsumerStatefulWidget {
  const PracticeTestScreen({
    super.key,
    required this.level,
    required this.section,
    required this.practiceNumber,
  });

  final String level;
  final ProblemSection section;
  final int practiceNumber;

  @override
  ConsumerState<PracticeTestScreen> createState() => _PracticeTestScreenState();
}

class _PracticeTestScreenState extends ConsumerState<PracticeTestScreen> {
  int _index = 0;
  String? _selected;
  bool _answered = false;
  final List<String> _incorrectIds = [];
  late final DateTime _startedAt = DateTime.now();
  List<QuizQuestion> _vocabularyQuestions = const [];
  TtsService? _ttsService;

  @override
  void dispose() {
    if (_ttsService != null) unawaited(_ttsService!.stop());
    super.dispose();
  }

  Future<void> _playDialogue(String passage) async {
    if (await isSystemVolumeTooLow()) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.strings('lowVolumeBody'))));
      return;
    }
    _ttsService ??= ref.read(ttsServiceProvider);
    unawaited(_ttsService!.speakDialogue(parseDialogueScript(passage)));
  }

  Future<void> _advance(List<MockTestProblem> items) async {
    if (_ttsService != null) unawaited(_ttsService!.stop());
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
        '/test/practice/${widget.level}/${sectionPathSegment(widget.section)}/'
        '${practiceSetId(widget.practiceNumber)}/result',
      );
    }
  }

  String _sectionLabel(BuildContext context, ProblemSection section) =>
      switch (section) {
        ProblemSection.vocabulary => context.strings('sectionVocabulary'),
        ProblemSection.grammar => context.strings('grammar'),
        ProblemSection.reading => context.strings('sectionReading'),
        ProblemSection.listening => context.strings('sectionListening'),
      };

  String _instruction(BuildContext context, ProblemSection section) =>
      switch (section) {
        ProblemSection.vocabulary => context.strings('quizInstruction'),
        ProblemSection.grammar => context.strings('grammarQuizInstruction'),
        ProblemSection.reading => context.strings('readingQuizInstruction'),
        ProblemSection.listening => context.strings('listeningQuizInstruction'),
      };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider).requireValue;
    final practiceSetAsync = ref.watch(
      generatedPracticeSetProvider((
        level: widget.level,
        practiceNumber: widget.practiceNumber,
      )),
    );
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
            title: Text(
              '${widget.level} · ${_sectionLabel(context, item.section)}',
            ),
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (item.section == ProblemSection.listening)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          _playDialogue(item.passage),
                                      icon: const Icon(Icons.volume_up_rounded),
                                      label: Text(context.strings('playAudio')),
                                    ),
                                  ),
                                Text(
                                  item.passage,
                                  style: const TextStyle(height: 1.7),
                                ),
                              ],
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
                            key: const ValueKey('practice_feedback'),
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
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  item.localizedExplanation(
                                    state.meaningLanguage,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                FilledButton.tonalIcon(
                                  key: const ValueKey('practice_ask_ai_tutor'),
                                  onPressed: () => showPracticeAiTutorSheet(
                                    context: context,
                                    problem: item,
                                    selectedAnswer: _selected!,
                                    explanationLanguage:
                                        state.meaningLanguage == 'ko'
                                        ? 'Korean'
                                        : 'English',
                                    onContinue: () =>
                                        unawaited(_advance(items)),
                                  ),
                                  icon: const Icon(Icons.auto_awesome_rounded),
                                  label: Text(context.strings('askAiTutor')),
                                ),
                              ],
                            ),
                          ),
                        if (!_answered)
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
                                        : Theme.of(
                                            context,
                                          ).colorScheme.surface),
                                borderRadius: BorderRadius.circular(19),
                                child: InkWell(
                                  key: ValueKey(
                                    'practice_test_choice_${entry.key}',
                                  ),
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
                        if (_answered) ...[
                          const SizedBox(height: 8),
                          FilledButton(
                            key: const ValueKey('practice_continue'),
                            onPressed: () => _advance(items),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(54),
                            ),
                            child: Text(
                              _index == items.length - 1
                                  ? context.strings('seeResults')
                                  : context.strings('continue'),
                            ),
                          ),
                        ],
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
