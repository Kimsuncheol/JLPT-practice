import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/app/theme/app_theme.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/features/dashboard/dashboard_skeleton.dart';
import 'package:jlpt_practice/shared/rewarded_xp_card.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(appControllerProvider);
    return SafeArea(
      child: asyncState.when(
        loading: () => const DashboardSkeleton(),
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
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1,
                      children: [
                        _GridActionTile(
                          color: Theme.of(
                            context,
                          ).colorScheme.secondaryContainer,
                          icon: Icons.menu_book_rounded,
                          title: strings('study'),
                          onTap: () => context.push('/study/choose'),
                        ),
                        _GridActionTile(
                          color: Theme.of(
                            context,
                          ).colorScheme.tertiaryContainer,
                          icon: Icons.fact_check_rounded,
                          title: strings('n5Test'),
                          onTap: () => context.push(
                            '/test/practice/${state.selectedLevel}',
                          ),
                        ),
                        _GridActionTile(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          icon: Icons.grid_view_rounded,
                          title: strings('kanaChartTile'),
                          onTap: () => context.push('/kana'),
                        ),
                        _GridActionTile(
                          color: Color.alphaBlend(
                            Theme.of(context)
                                .extension<AppColors>()!
                                .warning
                                .withValues(alpha: 0.35),
                            Theme.of(context).colorScheme.surface,
                          ),
                          icon: Icons.replay_circle_filled_rounded,
                          title: strings('review'),
                          onTap: () => context.push('/review'),
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
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MetricCard(
                            value: '${state.totalXp}',
                            label: strings('totalXp'),
                            icon: Icons.bolt_rounded,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const RewardedXpCard(),
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

class _GridActionTile extends StatelessWidget {
  const _GridActionTile({
    required this.color,
    required this.icon,
    required this.title,
    required this.onTap,
  });
  final Color color;
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    borderRadius: BorderRadius.circular(24),
    child: InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(icon),
            ),
            const Spacer(),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
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
