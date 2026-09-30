import 'package:flutter/material.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/features/vocabulary/sentence_reorder_quiz.dart';

class ReorderFeedback extends StatelessWidget {
  const ReorderFeedback({required this.quiz, required this.attempt, super.key});
  final SentenceReorderQuiz quiz;
  final QuizAttemptResult attempt;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(attempt.isCorrect ? strings('correct') : strings('incorrect')),
        Text(
          quiz.entry.example.sentence,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text(quiz.entry.example.reading),
        const SizedBox(height: 16),
      ],
    );
  }
}
