import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/core/utils/study_batches.dart';
import 'package:jlpt_practice/features/vocabulary/sentence_reorder_quiz.dart';

class SentenceReorderScreen extends ConsumerStatefulWidget {
  const SentenceReorderScreen({required this.day, super.key});
  final int day;

  @override
  ConsumerState<SentenceReorderScreen> createState() =>
      _SentenceReorderScreenState();
}

class _SentenceReorderScreenState extends ConsumerState<SentenceReorderScreen> {
  static const _autoAdvanceDelay = Duration(milliseconds: 2500);
  SentenceReorderQuizSet? _set;
  QuizSessionSummary _summary = QuizSessionSummary();
  final List<SentenceToken> _selected = [];
  QuizAttemptResult? _attempt;
  int _index = 0;
  bool _leaveDialogOpen = false;
  Timer? _autoAdvanceTimer;

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    super.dispose();
  }

  Future<void> _confirmLeave() async {
    if (_leaveDialogOpen) return;
    _autoAdvanceTimer?.cancel();
    _leaveDialogOpen = true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.strings('leaveQuizTitle')),
        content: Text(dialogContext.strings('leaveQuizBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.strings('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.strings('leave')),
          ),
        ],
      ),
    );
    _leaveDialogOpen = false;
    if (!mounted) return;
    if (leave == true) {
      context.pop();
    } else if (_attempt != null) {
      _scheduleAutoAdvance();
    }
  }

  void _scheduleAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = Timer(_autoAdvanceDelay, _advance);
  }

  void _advance() {
    _autoAdvanceTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _index++;
      _selected.clear();
      _attempt = null;
    });
  }

  void _retry(List<VocabEntry> words) => setState(() {
    _autoAdvanceTimer?.cancel();
    _set = buildQuizSet(words);
    _summary = QuizSessionSummary();
    _selected.clear();
    _attempt = null;
    _index = 0;
  });

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(appControllerProvider);
    return stateAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error.toString()),
              TextButton(
                onPressed: () => ref.invalidate(appControllerProvider),
                child: Text(context.strings('retry')),
              ),
            ],
          ),
        ),
      ),
      data: (state) {
        final words = StudyBatches.wordsForDay(
          state.selectedVocabulary,
          day: widget.day,
          dailyGoal: state.dailyGoal,
        );
        _set ??= buildQuizSet(words);
        final set = _set!;
        final strings = context.strings;
        if (set.hasNoEligibleEntries) {
          return Scaffold(
            appBar: AppBar(title: Text(strings('sentenceReordering'))),
            body: Center(child: Text(strings('noReorderSentences'))),
          );
        }
        if (_index >= set.actualCount) {
          return Scaffold(
            appBar: AppBar(title: Text(strings('sentenceReordering'))),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_summary.correct} / ${_summary.total}',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () => _retry(words),
                    child: Text(strings('retry')),
                  ),
                ],
              ),
            ),
          );
        }
        final quiz = set.quizzes[_index];
        final remaining = quiz.shuffledTiles
            .where((tile) => !_selected.any((picked) => picked.id == tile.id))
            .toList();
        final translation = quiz.entry.example.translation(
          state.meaningLanguage,
        );
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) unawaited(_confirmLeave());
          },
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                tooltip: strings('leave'),
                onPressed: _confirmLeave,
                icon: const Icon(Icons.close_rounded),
              ),
              title: Text(strings('sentenceReordering')),
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
                            value: (_index + 1) / set.actualCount,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          '${_index + 1}/${set.actualCount}',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Text(strings('reorderPrompt')),
                        const SizedBox(height: 24),
                        Container(
                          key: const ValueKey('reorder-answer-container'),
                          constraints: const BoxConstraints(minHeight: 86),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF292C2E)
                                : const Color(0xFFE8EAEB),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final (position, tile)
                                      in _selected.indexed)
                                    InputChip(
                                      key: ValueKey('selected-${tile.id}'),
                                      label: Text(tile.text),
                                      backgroundColor:
                                          _attempt?.wrongPositions.contains(
                                                position,
                                              ) ==
                                              true
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.errorContainer
                                          : null,
                                      onPressed: _attempt == null
                                          ? () => setState(
                                              () => _selected.remove(tile),
                                            )
                                          : null,
                                    ),
                                ],
                              ),
                              if (_selected.isNotEmpty)
                                const SizedBox(height: 14),
                              Text(
                                translation,
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final tile in remaining)
                              ActionChip(
                                key: ValueKey('available-${tile.id}'),
                                label: Text(tile.text),
                                onPressed: _attempt == null
                                    ? () => setState(() => _selected.add(tile))
                                    : null,
                              ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        if (_attempt != null) ...[
                          Text(
                            _attempt!.isCorrect
                                ? strings('correct')
                                : strings('incorrect'),
                          ),
                          Text(
                            quiz.entry.example.sentence,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(quiz.entry.example.reading),
                          const SizedBox(height: 16),
                        ],
                        if (_attempt == null) ...[
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(54),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _selected.isEmpty
                                ? null
                                : () => setState(_selected.clear),
                            child: Text(strings('reset')),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(54),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed:
                                _selected.length != quiz.correctOrder.length
                                ? null
                                : () {
                                    final result = submitAnswer(
                                      quiz,
                                      _selected
                                          .map((tile) => tile.text)
                                          .toList(),
                                    );
                                    setState(() {
                                      _attempt = result;
                                      _summary.add(quiz, result);
                                    });
                                    _scheduleAutoAdvance();
                                  },
                            child: Text(strings('checkAnswer')),
                          ),
                        ] else
                          FilledButton(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(54),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: _advance,
                            child: Text(strings('continue')),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
