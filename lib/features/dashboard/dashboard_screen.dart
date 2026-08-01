import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/app/theme/app_theme.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/shared/adaptive_ad_slot.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(appControllerProvider);
    return SafeArea(
      child: asyncState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (state) {
          final strings = context.strings;
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: const BoxDecoration(
                            color: AppTheme.mint,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            '語',
                            style: TextStyle(
                              color: AppTheme.ink,
                              fontSize: 23,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Chip(
                          avatar: const Icon(Icons.school_rounded, size: 18),
                          label: Text(state.selectedLevel),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    Text(
                      strings('welcomeBack'),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings('dailyMomentum'),
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimary.withValues(alpha: 0.78),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${state.studiedCount}',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                  fontSize: 42,
                                  height: 1,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 8,
                                  bottom: 4,
                                ),
                                child: Text(
                                  '/ ${state.dailyGoal} ${strings('wordsStudied')}',
                                  style: TextStyle(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimary
                                        .withValues(alpha: 0.82),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          LinearProgressIndicator(
                            value: state.dailyProgress,
                            minHeight: 9,
                            borderRadius: BorderRadius.circular(9),
                            backgroundColor: Colors.white24,
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              _OnPrimaryMetric(
                                icon: Icons.replay_rounded,
                                value: '${state.dueVocabulary.length}',
                                label: strings('reviewsDue'),
                              ),
                              const SizedBox(width: 22),
                              _OnPrimaryMetric(
                                icon: Icons.local_fire_department_rounded,
                                value: '${state.currentStreak}',
                                label: strings('streak'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _ActionTile(
                      color: Theme.of(context).colorScheme.secondaryContainer,
                      icon: Icons.style_rounded,
                      title: strings('startStudy'),
                      subtitle:
                          '${state.selectedVocabulary.length} ${strings('words').toLowerCase()}',
                      onTap: () => context.push('/study'),
                    ),
                    const SizedBox(height: 10),
                    _ActionTile(
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      icon: Icons.auto_stories_rounded,
                      title: strings('studyGrammar'),
                      subtitle: strings('grammarByRank'),
                      onTap: () => context.push('/grammar'),
                    ),
                    const SizedBox(height: 10),
                    _ActionTile(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      icon: Icons.grid_view_rounded,
                      title: strings('kanaChart'),
                      subtitle: strings('kanaChartSubtitle'),
                      onTap: () => context.push('/kana'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _SmallAction(
                            icon: Icons.replay_circle_filled_rounded,
                            title: strings('startReview'),
                            badge: '${state.dueVocabulary.length}',
                            onTap: () => context.push('/review'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _SmallAction(
                            icon: Icons.quiz_rounded,
                            title: strings('startQuiz'),
                            badge:
                                '${state.selectedVocabulary.where((word) => word.hasExample).length}',
                            onTap: () => context.push('/quiz'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      strings('recentActivity'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            value: '${state.learnedCount}',
                            label: strings('learned'),
                            icon: Icons.check_circle_rounded,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MetricCard(
                            value: '${state.studiedCount - state.learnedCount}',
                            label: strings('learning'),
                            icon: Icons.trending_up_rounded,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const AdaptiveAdSlot(),
            ],
          );
        },
      ),
    );
  }
}

class _OnPrimaryMetric extends StatelessWidget {
  const _OnPrimaryMetric({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20, color: Theme.of(context).colorScheme.onPrimary),
      const SizedBox(width: 7),
      Text(
        '$value $label',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    borderRadius: BorderRadius.circular(24),
    child: InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(icon),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded),
          ],
        ),
      ),
    ),
  );
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({
    required this.icon,
    required this.title,
    required this.badge,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(22),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badge,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.value,
    required this.label,
    required this.icon,
  });
  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 12),
        Text(
          value,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ],
    ),
  );
}
