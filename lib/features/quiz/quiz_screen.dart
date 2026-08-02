import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/ads/ad_service.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/core/utils/study_batches.dart';
import 'package:jlpt_practice/data/models/quiz.dart';

class QuizScreen extends ConsumerStatefulWidget {
  const QuizScreen({this.day, super.key});

  /// When set, the quiz is scoped to that study day's vocabulary instead of
  /// the whole selected level.
  final int? day;

  @override
  ConsumerState<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends ConsumerState<QuizScreen> {
  List<QuizQuestion>? _questions;
  int _index = 0;
  String? _selected;
  bool _answered = false;
  bool _hintRevealed = false;
  int _correct = 0;
  final List<String> _incorrectIds = [];
  late final DateTime _startedAt = DateTime.now();
  Timer? _autoAdvanceTimer;

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    super.dispose();
  }

  Future<void> _advance() async {
    _autoAdvanceTimer?.cancel();
    final questions = _questions!;
    if (_index < questions.length - 1) {
      setState(() {
        _index++;
        _selected = null;
        _answered = false;
        _hintRevealed = false;
      });
      return;
    }
    final result = QuizResult(
      total: questions.length,
      correct: _correct,
      duration: DateTime.now().difference(_startedAt),
      incorrectIds: List.unmodifiable(_incorrectIds),
    );
    await ref
        .read(appControllerProvider.notifier)
        .recordQuizResult(result, questions);
    if (mounted) context.go('/quiz/result');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider).requireValue;
    _questions ??= widget.day != null
        ? ref.read(quizRepositoryProvider).buildQuestions(
            StudyBatches.wordsForDay(
              state.selectedVocabulary,
              day: widget.day!,
              dailyGoal: state.dailyGoal,
            ),
            count: state.dailyGoal,
          )
        : ref
              .read(quizRepositoryProvider)
              .buildQuestions(state.vocabulary, level: state.selectedLevel);
    final questions = _questions!;
    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(context.strings('noResults'))),
      );
    }
    final question = questions[_index];
    final isCorrect = _selected == question.correctAnswer;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: context.pop,
          icon: const Icon(Icons.close_rounded),
        ),
        title: Text(context.strings('startQuiz')),
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
                      value: (_index + 1) / questions.length,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    '${_index + 1}/${questions.length}',
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
                      context.strings('quizInstruction'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
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
                      child: Column(
                        children: [
                          Text(
                            question.vocabulary.example.quizSentence,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 25,
                              height: 1.6,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            question.vocabulary.example.translation(
                              state.meaningLanguage,
                            ),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (!_answered)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: AdService.enabled
                              ? () async {
                                  final earned = await AdService.showRewarded();
                                  if (earned && mounted) {
                                    setState(() => _hintRevealed = true);
                                  }
                                }
                              : () => setState(() => _hintRevealed = true),
                          icon: Icon(
                            AdService.enabled
                                ? Icons.ondemand_video_rounded
                                : Icons.lightbulb_outline_rounded,
                          ),
                          label: const Text('Hint'),
                        ),
                      ),
                    if (_hintRevealed && !_answered)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${question.vocabulary.reading} · ${question.vocabulary.meaning(state.meaningLanguage)}',
                        ),
                      ),
                    ...question.choices.asMap().entries.map((entry) {
                      final choice = entry.value;
                      final selected = _selected == choice;
                      Color? color;
                      IconData? trailing;
                      if (_answered && choice == question.correctAnswer) {
                        color = Theme.of(context).colorScheme.primaryContainer;
                        trailing = Icons.check_circle_rounded;
                      } else if (_answered && selected) {
                        color = Theme.of(context).colorScheme.errorContainer;
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
                            onTap: _answered
                                ? null
                                : () {
                                    setState(() {
                                      _selected = choice;
                                      _answered = true;
                                      if (choice == question.correctAnswer) {
                                        _correct++;
                                      } else {
                                        _incorrectIds.add(
                                          question.vocabulary.id,
                                        );
                                      }
                                    });
                                    _autoAdvanceTimer?.cancel();
                                    _autoAdvanceTimer = Timer(
                                      const Duration(milliseconds: 1400),
                                      _advance,
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
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.surfaceContainerHighest,
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
                    if (_answered)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isCorrect
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isCorrect
                                  ? context.strings('correct')
                                  : context.strings('incorrect'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${question.vocabulary.reading} · ${question.vocabulary.meaning(state.meaningLanguage)}',
                            ),
                            const SizedBox(height: 6),
                            Text(question.vocabulary.example.sentence),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 18),
              child: FilledButton(
                onPressed: !_answered ? null : _advance,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                ),
                child: Text(
                  _index == questions.length - 1
                      ? context.strings('seeResults')
                      : context.strings('next'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
