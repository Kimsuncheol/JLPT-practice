import 'package:flutter/material.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/core/constants/app_sizes.dart';

class LevelCompleteActions extends StatelessWidget {
  const LevelCompleteActions({
    required this.onChooseAnotherLevel,
    required this.onBackToStudyDays,
    required this.onChooseQuizGame,
    super.key,
  });

  final VoidCallback onChooseAnotherLevel;
  final VoidCallback onBackToStudyDays;
  final VoidCallback onChooseQuizGame;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onChooseAnotherLevel,
            icon: const Icon(Icons.swap_horiz_rounded),
            label: Text(strings('chooseAnotherLevel')),
          ),
        ),
        const SizedBox(height: AppSizes.space10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onBackToStudyDays,
            icon: const Icon(Icons.grid_view_rounded),
            label: Text(strings('backToStudyDays')),
          ),
        ),
        const SizedBox(height: AppSizes.space10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
            ),
            onPressed: onChooseQuizGame,
            icon: const Icon(Icons.quiz_rounded),
            label: Text(strings('chooseQuizGame')),
          ),
        ),
      ],
    );
  }
}

class SessionActions extends StatelessWidget {
  const SessionActions({
    required this.onFinish,
    required this.onChooseQuizGame,
    super.key,
  });

  final VoidCallback onFinish;
  final VoidCallback onChooseQuizGame;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
            ),
            onPressed: onFinish,
            icon: const Icon(Icons.check_rounded),
            label: Text(strings('finishSession')),
          ),
        ),
        const SizedBox(height: AppSizes.space10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
            ),
            onPressed: onChooseQuizGame,
            icon: const Icon(Icons.quiz_rounded),
            label: Text(strings('chooseQuizGame')),
          ),
        ),
      ],
    );
  }
}
