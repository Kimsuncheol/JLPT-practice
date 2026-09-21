import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/core/utils/study_batches.dart';

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
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.celebration_rounded, size: 42),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      body,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (completesLevel) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _completeLevel(
                      context,
                      ref,
                      level: level,
                      destination: _LevelCompletionDestination.levels,
                    ),
                    icon: const Icon(Icons.swap_horiz_rounded),
                    label: Text(strings('chooseAnotherLevel')),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _completeLevel(
                      context,
                      ref,
                      level: level,
                      destination: _LevelCompletionDestination.days,
                    ),
                    icon: const Icon(Icons.grid_view_rounded),
                    label: Text(strings('backToStudyDays')),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _completeLevel(
                      context,
                      ref,
                      level: level,
                      destination: _LevelCompletionDestination.quiz,
                    ),
                    icon: const Icon(Icons.quiz_rounded),
                    label: Text(
                      strings(
                        'takeLevelVocabularyQuiz',
                      ).replaceAll('{level}', level),
                    ),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _finish(context, ref),
                    icon: const Icon(Icons.check_rounded),
                    label: Text(strings('finishSession')),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push('/quiz/day/$day'),
                    icon: const Icon(Icons.quiz_rounded),
                    label: Text(strings('startQuiz')),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _completeLevel(
    BuildContext context,
    WidgetRef ref, {
    required String level,
    required _LevelCompletionDestination destination,
  }) async {
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
      case _LevelCompletionDestination.quiz:
        context.push('/quiz');
    }
  }

  Future<void> _finish(BuildContext context, WidgetRef ref) async {
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

enum _LevelCompletionDestination { levels, days, quiz }
