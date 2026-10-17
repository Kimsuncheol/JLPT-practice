import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/core/utils/immersive_study_mode.dart';
import 'package:jlpt_practice/features/grammar/grammar_providers.dart';
import 'package:jlpt_practice/shared/inactive_ai_chat.dart';

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
            return InactiveAiChat(
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
            );
          },
        ),
  );
}
