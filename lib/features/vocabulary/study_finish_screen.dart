import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/core/utils/study_batches.dart';
import 'package:jlpt_practice/features/vocabulary/study_finish/studied_words_section.dart';
import 'package:jlpt_practice/features/vocabulary/study_finish/study_finish_actions.dart';
import 'package:jlpt_practice/features/vocabulary/study_finish/study_finish_header.dart';
import 'package:jlpt_practice/core/constants/app_sizes.dart';

class StudyFinishScreen extends ConsumerWidget {
  const StudyFinishScreen({required this.day, super.key});

  final int day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(appControllerProvider);
    if (asyncState.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (asyncState.hasError) {
      return Scaffold(body: Center(child: Text('${asyncState.error}')));
    }
    final state = asyncState.requireValue;
    final level = state.selectedLevel;
    final wordCount = state.selectedVocabulary.length;
    final dayCount = StudyBatches.count(wordCount, state.dailyGoal);
    final todaysWords = StudyBatches.wordsForDay(
      state.selectedVocabulary,
      day: day,
      dailyGoal: state.dailyGoal,
    );
    final completedDays = state.completedStudyDays[level] ?? const <int>{};
    final completesLevel =
        dayCount > 0 &&
        day == dayCount &&
        !completedDays.contains(day) &&
        List.generate(dayCount, (index) => index + 1).every(
          (candidate) => candidate == day || completedDays.contains(candidate),
        );
    final strings = context.strings;
    final title = completesLevel
        ? strings('levelVocabularyComplete').replaceAll('{level}', level)
        : strings('studyComplete');
    final body = completesLevel
        ? strings('levelVocabularyCompleteBody')
              .replaceAll('{words}', '$wordCount')
              .replaceAll('{days}', '$dayCount')
        : strings('studyCompleteBody');
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.size24,
            AppSizes.size24,
            AppSizes.size24,
            AppSizes.size20,
          ),
          child: Column(
            children: [
              Expanded(
                flex: 3,
                child: Center(
                  child: StudyFinishHeader(title: title, body: body),
                ),
              ),
              Expanded(
                flex: 5,
                child: StudiedWordsSection(
                  words: [for (final word in todaysWords) word.word],
                  onWordTap: (word) => ref.read(ttsServiceProvider).speak(word),
                ),
              ),
              const SizedBox(height: AppSizes.space16),
              if (completesLevel)
                LevelCompleteActions(
                  onChooseAnotherLevel: () => _completeLevel(
                    context,
                    ref,
                    level: level,
                    destination: _LevelCompletionDestination.levels,
                  ),
                  onBackToStudyDays: () => _completeLevel(
                    context,
                    ref,
                    level: level,
                    destination: _LevelCompletionDestination.days,
                  ),
                  onChooseQuizGame: () => _completeLevel(
                    context,
                    ref,
                    level: level,
                    destination: _LevelCompletionDestination.quizSelection,
                  ),
                  onStartOver: () => _startOver(context, ref),
                )
              else
                SessionActions(
                  onFinish: () => _finish(context, ref),
                  onStartOver: () => _startOver(context, ref),
                  onChooseQuizGame: () {
                    ref.read(ttsServiceProvider).stop();
                    context.push('/study/day/$day/quiz-selection');
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startOver(BuildContext context, WidgetRef ref) async {
    ref.read(ttsServiceProvider).stop();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.strings('startOverTitle')),
        content: Text(dialogContext.strings('startOverBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.strings('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.strings('startOver')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    context.pushReplacement('/study/day/$day?startOver=true');
  }

  Future<void> _completeLevel(
    BuildContext context,
    WidgetRef ref, {
    required String level,
    required _LevelCompletionDestination destination,
  }) async {
    ref.read(ttsServiceProvider).stop();
    await ref
        .read(appControllerProvider.notifier)
        .completeStudySession(level, day);
    if (!context.mounted) return;
    context.go('/home');
    switch (destination) {
      case _LevelCompletionDestination.levels:
        context.push('/settings/levels');
      case _LevelCompletionDestination.days:
        context.push('/study');
      case _LevelCompletionDestination.quizSelection:
        context.push('/study/day/$day/quiz-selection?level=true');
    }
  }

  Future<void> _finish(BuildContext context, WidgetRef ref) async {
    ref.read(ttsServiceProvider).stop();
    final state = ref.read(appControllerProvider).requireValue;
    final level = state.selectedLevel;
    final alreadyCompleted =
        state.completedStudyDays[level]?.contains(day) ?? false;
    final shouldComplete =
        alreadyCompleted ||
        await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: Text(context.strings('finishSessionConfirm')),
                content: Text(context.strings('finishSessionConfirmBody')),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(context.strings('cancel')),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: Text(context.strings('finish')),
                  ),
                ],
              ),
            ) ==
            true;
    if (shouldComplete != true || !context.mounted) return;

    await ref
        .read(appControllerProvider.notifier)
        .completeStudySession(level, day);
    if (!context.mounted) return;
    // go('/study') would leave the day list as the only route, so the system
    // back button would close the app. Rebuild home → day list instead.
    context.go('/home');
    context.push('/study');
  }
}

enum _LevelCompletionDestination { levels, days, quizSelection }
