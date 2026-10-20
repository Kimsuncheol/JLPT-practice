import 'package:flutter/material.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/data/models/grammar_point.dart';
import 'package:jlpt_practice/shared/api_tutor_chat.dart';
import 'package:jlpt_practice/core/api/jlpt_tutor_service.dart';

Future<void> showGrammarQaChatScreen(
  BuildContext context, {
  required GrammarPoint grammar,
  required String languageCode,
}) async {
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) =>
          GrammarQaChatScreen(grammar: grammar, languageCode: languageCode),
    ),
  );
}

class GrammarQaChatScreen extends StatelessWidget {
  const GrammarQaChatScreen({
    required this.grammar,
    required this.languageCode,
    super.key,
  });

  final GrammarPoint grammar;
  final String languageCode;

  @override
  Widget build(BuildContext context) => ApiTutorChat(
    structuredExamples: true,
    level: grammar.level,
    language: languageCode,
    contextData: grammarTutorContext(grammar, languageCode),
    title: context.strings('grammarChatTitle'),
    icon: Icons.question_answer_rounded,
    hint: context.strings('askAboutThisGrammarHint'),
    suggestionKeys: const [],
    initialMessage:
        'Explain the selected grammar in detail: meaning, formation/conjugation, '
        'usage, register, nuances, common mistakes and similar grammar. Include '
        'two Japanese examples with translations and complete furigana in the '
        'structured examples array. Place each example marker on its own line '
        'in the explanation. Include exactly three follow-up questions in this response.',
    showInitialMessage: false,
    closeKey: const ValueKey('grammar_chat_close'),
  );
}
