import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/core/utils/study_batches.dart';
import 'package:jlpt_practice/data/models/vocabulary.dart';

class ChooseStudyScreen extends ConsumerWidget {
  const ChooseStudyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(appControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.strings('chooseStudyType'))),
      body: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (state) {
          final strings = context.strings;
          final studySession = state.studySessions[state.selectedLevel];
          final resumeWords =
              studySession != null &&
                  studySession.isCompatible(
                    level: state.selectedLevel,
                    dailyGoal: state.dailyGoal,
                  )
              ? StudyBatches.wordsForDay(
                  state.selectedVocabulary,
                  day: studySession.day,
                  dailyGoal: state.dailyGoal,
                )
              : const <Vocabulary>[];
          final canResume = studySession != null && resumeWords.isNotEmpty;
          return SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              children: [
                _StudyGroup(
                  children: [
                    _StudyTile(
                      icon: canResume
                          ? Icons.play_circle_fill_rounded
                          : Icons.style_rounded,
                      title: canResume
                          ? strings('resumeLearning')
                          : strings('startStudy'),
                      subtitle: strings('studyVocabularySubtitle'),
                      onTap: () => canResume
                          ? context.push('/study/day/${studySession.day}')
                          : context.push('/study'),
                    ),
                    _StudyTile(
                      icon: Icons.auto_stories_rounded,
                      title: strings('studyGrammar'),
                      subtitle: strings('grammarByRank'),
                      onTap: () => context.push('/grammar'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StudyGroup extends StatelessWidget {
  const _StudyGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(22),
    clipBehavior: Clip.antiAlias,
    child: Column(
      children: [
        for (var index = 0; index < children.length; index++) ...[
          children[index],
          if (index != children.length - 1)
            Divider(
              height: 1,
              indent: 72,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
        ],
      ],
    ),
  );
}

class _StudyTile extends StatelessWidget {
  const _StudyTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
    leading: Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon),
    ),
    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: onTap,
  );
}
