import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/core/utils/study_batches.dart';
import 'package:jlpt_practice/data/models/app_state.dart';
import 'package:jlpt_practice/features/grammar/grammar_study_session_provider.dart';

class RecentStudyCard extends ConsumerWidget {
  const RecentStudyCard({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vocabulary = state.studySessions[state.selectedLevel];
    final grammar = ref
        .watch(grammarStudySessionsProvider)
        .value?[state.selectedLevel];
    final entries = <({String label, String route, DateTime updatedAt})>[
      if (vocabulary != null &&
          vocabulary.isCompatible(
            level: state.selectedLevel,
            dailyGoal: state.dailyGoal,
          ) &&
          StudyBatches.wordsForDay(
            state.selectedVocabulary,
            day: vocabulary.day,
            dailyGoal: state.dailyGoal,
          ).isNotEmpty)
        (
          label:
              '${state.selectedLevel} · ${context.strings('words')} · ${context.strings('day')} ${vocabulary.day}',
          route: '/study/day/${vocabulary.day}',
          updatedAt: vocabulary.updatedAt,
        ),
      if (grammar != null)
        (
          label:
              '${grammar.level} · ${context.strings('grammar')} · ${context.strings('part')} ${grammar.part}${grammar.title == null ? '' : ' · ${grammar.title}'}',
          route: grammar.route,
          updatedAt: grammar.updatedAt,
        ),
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (entries.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Card(
        margin: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                context.strings('recentStudy'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final entry in entries)
              ListTile(
                leading: const Icon(Icons.history_rounded),
                title: Text(entry.label),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push(entry.route),
              ),
          ],
        ),
      ),
    );
  }
}
