import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/core/utils/immersive_study_mode.dart';
import 'package:jlpt_practice/features/grammar/grammar_providers.dart';
import 'package:jlpt_practice/shared/api_tutor_chat.dart';
import 'package:jlpt_practice/core/api/jlpt_tutor_service.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/features/test/ai_practice_screen.dart';
import 'package:jlpt_practice/features/grammar/grammar_study_session_provider.dart';
import 'package:jlpt_practice/data/models/grammar_study_session.dart';

class GrammarTutorScreen extends ConsumerStatefulWidget {
  const GrammarTutorScreen({required this.grammarId, super.key});
  final String grammarId;

  @override
  ConsumerState<GrammarTutorScreen> createState() => _GrammarTutorScreenState();
}

class _GrammarTutorScreenState extends ConsumerState<GrammarTutorScreen>
    with ImmersiveStudyMode<GrammarTutorScreen> {
  @override
  Widget build(BuildContext context) => wrapImmersive(
    ref
        .watch(grammarCatalogProvider)
        .when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, _) => Scaffold(body: Center(child: Text('$error'))),
          data: (items) {
            if (!items.any((item) => item.id == widget.grammarId)) {
              return Scaffold(
                appBar: AppBar(),
                body: Center(child: Text(context.strings('noGrammarResults'))),
              );
            }
            final grammar = items.firstWhere(
              (item) => item.id == widget.grammarId,
            );
            final language =
                ref.watch(appControllerProvider).value?.meaningLanguage ??
                Localizations.localeOf(context).languageCode;
            return TrackGrammarStudy(
              key: ValueKey(grammar.id),
              session: GrammarStudySession(
                level: grammar.level,
                part: (grammar.rank - 1) ~/ 10 + 1,
                kind: GrammarStudyKind.tutor,
                grammarId: grammar.id,
                title: grammar.title,
                updatedAt: DateTime.now(),
              ),
              child: ApiTutorChat(
                level: grammar.level,
                language: language,
                contextData: grammarTutorContext(grammar, language),
                initialMessage:
                    'Explain this grammar point, give two Japanese examples with translations, '
                    'then invite me to write a sentence using it. Give feedback when I reply.',
                onPractice: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AiPracticeScreen(
                      level: grammar.level,
                      topic: grammar.title,
                    ),
                  ),
                ),
                title: context.strings('practiceWithAi'),
                icon: Icons.auto_awesome_rounded,
                hint: context.strings('practiceChatHint'),
                suggestionKeys: const [
                  'practicePromptSuggestion',
                  'practiceExampleSuggestion',
                  'practiceUsageSuggestion',
                ],
                closeKey: const ValueKey('grammar_practice_close'),
                sendKey: const ValueKey('grammar_practice_send'),
              ),
            );
          },
        ),
  );
}
