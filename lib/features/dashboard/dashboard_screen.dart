import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/app/theme/app_theme.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/features/dashboard/dashboard_skeleton.dart';
import 'package:jlpt_practice/features/dashboard/recent_study_card.dart';
import 'package:jlpt_practice/shared/rewarded_xp_card.dart';
import 'package:jlpt_practice/core/constants/app_sizes.dart';
import 'package:jlpt_practice/core/constants/app_colors.dart';
import 'package:jlpt_practice/core/constants/app_font_weights.dart';

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
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.size20,
                    AppSizes.size22,
                    AppSizes.size20,
                    AppSizes.size12,
                  ),
                  children: [
                    Row(
                      children: [
                        Container(
                          width: AppSizes.size46,
                          height: AppSizes.size46,
                          decoration: const BoxDecoration(
                            color: AppTheme.mint,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            '語',
                            style: TextStyle(
                              color: AppTheme.ink,
                              fontSize: AppSizes.font23,
                              fontWeight: AppFontWeights.extraBold,
                            ),
                          ),
                        ),
                        const Spacer(),
                        ActionChip(
                          avatar: const Icon(
                            Icons.school_rounded,
                            size: AppSizes.size18,
                          ),
                          label: Text(state.selectedLevel),
                          onPressed: () => context.push('/settings/levels'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.space26),
                    Text(
                      strings('welcomeBack'),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSizes.space20),
                    Container(
                      padding: const EdgeInsets.all(AppSizes.size22),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(AppSizes.radius28),
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
                              fontWeight: AppFontWeights.semiBold,
                            ),
                          ),
                          const SizedBox(height: AppSizes.space14),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${state.studiedCount}',
                                style: TextStyle(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onPrimary,
                                  fontSize: AppSizes.font42,
                                  height: AppSizes.size1,
                                  fontWeight: AppFontWeights.extraBold,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: AppSizes.size8,
                                  bottom: AppSizes.size4,
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
                          const SizedBox(height: AppSizes.space18),
                          LinearProgressIndicator(
                            value: state.dailyProgress,
                            minHeight: AppSizes.size9,
                            borderRadius: BorderRadius.circular(
                              AppSizes.radius9,
                            ),
                            backgroundColor: AppPalette.white24,
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                          ),
                          const SizedBox(height: AppSizes.space18),
                          Row(
                            children: [
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
                    RecentStudyCard(state: state),
                    const SizedBox(height: AppSizes.space18),
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
                          title: strings('voca'),
                          onTap: () => context.push('/study'),
                        ),
                        _GridActionTile(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          icon: Icons.translate_rounded,
                          title: strings('kanji'),
                          onTap: () => context.push('/kanji'),
                        ),
                        _GridActionTile(
                          color: Theme.of(
                            context,
                          ).colorScheme.secondaryContainer,
                          icon: Icons.auto_stories_rounded,
                          title: strings('grammar'),
                          onTap: () => context.push('/grammar'),
                        ),
                        _GridActionTile(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          icon: Icons.grid_view_rounded,
                          title: strings('kanaChartTile'),
                          onTap: () => context.push('/kana'),
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
                      ],
                    ),
                    const SizedBox(height: AppSizes.space24),
                    Text(
                      strings('recentActivity'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSizes.space12),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricCard(
                            value: '${state.learnedCount}',
                            label: strings('learned'),
                            icon: Icons.check_circle_rounded,
                          ),
                        ),
                        const SizedBox(width: AppSizes.space10),
                        Expanded(
                          child: _MetricCard(
                            value: '${state.studiedCount - state.learnedCount}',
                            label: strings('learning'),
                            icon: Icons.trending_up_rounded,
                          ),
                        ),
                        const SizedBox(width: AppSizes.space10),
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
      Icon(
        icon,
        size: AppSizes.size20,
        color: Theme.of(context).colorScheme.onPrimary,
      ),
      const SizedBox(width: AppSizes.space7),
      Text(
        '$value $label',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimary,
          fontWeight: AppFontWeights.semiBold,
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
    borderRadius: BorderRadius.circular(AppSizes.radius24),
    child: InkWell(
      borderRadius: BorderRadius.circular(AppSizes.radius24),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.size16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: AppSizes.size42,
              height: AppSizes.size42,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(AppSizes.radius15),
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
    padding: const EdgeInsets.all(AppSizes.size14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppSizes.radius18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: AppSizes.size20,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: AppSizes.space12),
        Text(
          value,
          style: const TextStyle(
            fontSize: AppSizes.font24,
            fontWeight: AppFontWeights.extraBold,
          ),
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
