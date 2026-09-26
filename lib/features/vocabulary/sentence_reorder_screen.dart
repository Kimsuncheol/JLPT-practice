import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/core/utils/study_batches.dart';
import 'package:jlpt_practice/features/vocabulary/reorder/reorder_actions.dart';
import 'package:jlpt_practice/features/vocabulary/reorder/reorder_answer_area.dart';
import 'package:jlpt_practice/features/vocabulary/reorder/reorder_feedback.dart';
import 'package:jlpt_practice/features/vocabulary/reorder/reorder_progress_bar.dart';
import 'package:jlpt_practice/features/vocabulary/reorder/reorder_status_views.dart';
import 'package:jlpt_practice/features/vocabulary/reorder/reorder_tile_pool.dart';
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

  void _submit(SentenceReorderQuiz quiz) {
    final result = submitAnswer(
      quiz,
      _selected.map((tile) => tile.text).toList(),
    );
    setState(() {
      _attempt = result;
      _summary.add(quiz, result);
    });
    _scheduleAutoAdvance();
  }

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(appControllerProvider);
    return stateAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => ReorderErrorView(
        error: error,
        onRetry: () => ref.invalidate(appControllerProvider),
      ),
      data: (state) {
        final words = StudyBatches.wordsForDay(
          state.selectedVocabulary,
          day: widget.day,
          dailyGoal: state.dailyGoal,
        );
        _set ??= buildQuizSet(words);
        final set = _set!;
        if (set.hasNoEligibleEntries) return const ReorderEmptyView();
        if (_index >= set.actualCount) {
          return ReorderSummaryView(
            summary: _summary,
            onRetry: () => _retry(words),
          );
        }
        final quiz = set.quizzes[_index];
        final attempt = _attempt;
        final remaining = quiz.shuffledTiles
            .where((tile) => !_selected.any((picked) => picked.id == tile.id))
            .toList();
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) unawaited(_confirmLeave());
          },
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                tooltip: context.strings('leave'),
                onPressed: _confirmLeave,
                icon: const Icon(Icons.close_rounded),
              ),
              title: Text(context.strings('sentenceReordering')),
            ),
            body: SafeArea(
              top: false,
              child: Column(
                children: [
                  ReorderProgressBar(index: _index, total: set.actualCount),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Text(context.strings('reorderPrompt')),
                        const SizedBox(height: 24),
                        ReorderAnswerArea(
                          selected: _selected,
                          attempt: attempt,
                          translation: quiz.entry.example.translation(
                            state.meaningLanguage,
                          ),
                          onRemove: (tile) =>
                              setState(() => _selected.remove(tile)),
                        ),
                        const SizedBox(height: 24),
                        ReorderTilePool(
                          tiles: remaining,
                          enabled: attempt == null,
                          onSelect: (tile) =>
                              setState(() => _selected.add(tile)),
                        ),
                        const SizedBox(height: 24),
                        if (attempt != null)
                          ReorderFeedback(quiz: quiz, attempt: attempt),
                        ReorderActions(
                          answered: attempt != null,
                          canReset: _selected.isNotEmpty,
                          canCheck:
                              _selected.length == quiz.correctOrder.length,
                          onReset: () => setState(_selected.clear),
                          onCheck: () => _submit(quiz),
                          onContinue: _advance,
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
