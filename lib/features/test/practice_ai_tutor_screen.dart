import 'package:flutter/material.dart';
import 'package:jlpt_practice/core/api/jlpt_tutor_service.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/data/models/mock_test_problem.dart';
import 'package:jlpt_practice/shared/api_tutor_chat.dart';

Future<void> showPracticeAiTutorScreen({
  required BuildContext context,
  required MockTestProblem problem,
  required String selectedAnswer,
  required String explanationLanguage,
  required VoidCallback onContinue,
  List<String>? optionExplanations,
  String? supportingSentence,
}) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => PracticeAiTutorScreen(
        problem: problem,
        selectedAnswer: selectedAnswer,
        explanationLanguage: explanationLanguage,
        onContinue: onContinue,
        optionExplanations: optionExplanations,
        supportingSentence: supportingSentence,
      ),
    ),
  );
}

class PracticeAiTutorScreen extends StatelessWidget {
  const PracticeAiTutorScreen({
    required this.problem,
    required this.selectedAnswer,
    required this.explanationLanguage,
    required this.onContinue,
    this.optionExplanations,
    this.supportingSentence,
    super.key,
  });

  final MockTestProblem problem;
  final String selectedAnswer;
  final String explanationLanguage;
  final VoidCallback onContinue;
  final List<String>? optionExplanations;
  final String? supportingSentence;

  @override
  Widget build(BuildContext context) => ApiTutorChat(
    title: context.strings('practiceChatTitle'),
    icon: Icons.school_rounded,
    hint: context.strings('typeYourQuestion'),
    suggestionKeys: const ['explainChoices', 'showEvidence', 'giveExample'],
    closeKey: const ValueKey('practice_ai_close'),
    sendKey: const ValueKey('practice_ai_chat_send'),
    level: problem.level,
    language: explanationLanguage,
    contextBuilder: () => practiceTutorContext(
      problem,
      selectedAnswer,
      explanationLanguage,
      optionExplanations: optionExplanations,
      supportingSentence: supportingSentence,
    ),
    practiceItem: true,
    initialMessage:
        'Explain the correct answer and why my selected answer fits or does not fit. '
        'Use the supplied passage and stored explanation. Explain the other options briefly.',
    onContinue: onContinue,
  );
}
