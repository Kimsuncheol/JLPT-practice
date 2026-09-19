import 'dart:math' as math;

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
    final entries = <_RecentStudyEntry>[
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
        ...() {
          final words = StudyBatches.wordsForDay(
            state.selectedVocabulary,
            day: vocabulary.day,
            dailyGoal: state.dailyGoal,
          );
          if (words.isEmpty) return const <_RecentStudyEntry>[];
          final position = math.min(vocabulary.indexFallback + 1, words.length);
          return [
            _RecentStudyEntry(
              course: '${context.strings('words')} · ${state.selectedLevel}',
              destination: '${context.strings('day')} ${vocabulary.day}',
              detail: context
                  .strings('wordProgress')
                  .replaceAll('{current}', '$position')
                  .replaceAll('{total}', '${words.length}'),
              route: '/study/day/${vocabulary.day}',
              parentRoute: '/study',
              updatedAt: vocabulary.updatedAt,
              symbol: '語',
              progress: position / words.length,
            ),
          ];
        }(),
      if (grammar != null)
        _RecentStudyEntry(
          course: '${context.strings('grammar')} · ${grammar.level}',
          destination:
              '${context.strings('part')} ${grammar.part}'
              '${grammar.title == null ? '' : ' · ${grammar.title}'}',
          detail: context.strings('continueLesson'),
          route: grammar.route,
          parentRoute: '/grammar',
          updatedAt: grammar.updatedAt,
          symbol: '文',
        ),
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    if (entries.isEmpty) return const SizedBox.shrink();

    final primary = entries.first;
    final previous = entries.length > 1 ? entries[1] : null;
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.6)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              key: ValueKey('recent-study-${primary.route}'),
              onTap: () {
                context.push(primary.parentRoute);
                context.push(primary.route);
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.strings('recentStudy').toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _CourseSymbol(symbol: primary.symbol),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                primary.course,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                primary.destination,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                primary.detail,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: colors.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: colors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.play_arrow_rounded,
                            color: colors.onPrimary,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                    if (primary.progress case final progress?) ...[
                      const SizedBox(height: 14),
                      LinearProgressIndicator(
                        value: progress,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(6),
                        backgroundColor: colors.surfaceContainerHighest,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (previous != null) ...[
              Divider(height: 1, color: colors.outlineVariant),
              InkWell(
                key: ValueKey('recent-study-${previous.route}'),
                onTap: () {
                  context.push(previous.parentRoute);
                  context.push(previous.route);
                },
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                  child: Row(
                    children: [
                      Text(
                        context.strings('previousStudy'),
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${previous.course} · ${previous.destination}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded, size: 20),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CourseSymbol extends StatelessWidget {
  const _CourseSymbol({required this.symbol});

  final String symbol;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        symbol,
        style: TextStyle(
          color: colors.onPrimaryContainer,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _RecentStudyEntry {
  const _RecentStudyEntry({
    required this.course,
    required this.destination,
    required this.detail,
    required this.route,
    required this.parentRoute,
    required this.updatedAt,
    required this.symbol,
    this.progress,
  });

  final String course;
  final String destination;
  final String detail;
  final String route;
  final String parentRoute;
  final DateTime updatedAt;
  final String symbol;
  final double? progress;
}
