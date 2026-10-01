import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/features/statistics/statistics_skeleton.dart';
import 'package:jlpt_practice/shared/rewarded_xp_card.dart';
import 'package:jlpt_practice/core/constants/app_sizes.dart';
import 'package:jlpt_practice/core/constants/app_font_weights.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(appControllerProvider);
    return SafeArea(
      child: asyncState.when(
        loading: () => const StatisticsSkeleton(),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (state) {
          final strings = context.strings;
          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSizes.size20,
                    AppSizes.size20,
                    AppSizes.size20,
                    AppSizes.size18,
                  ),
                  children: [
                    Text(
                      strings('progress'),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSizes.space20),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.menu_book_rounded,
                            value: '${state.studiedCount}',
                            label: strings('totalStudied'),
                          ),
                        ),
                        const SizedBox(width: AppSizes.space10),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.workspace_premium_rounded,
                            value: '${state.learnedCount}',
                            label: strings('totalLearned'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.space10),
                    Row(
                      children: [
                        Expanded(
                          child: _StatCard(
                            icon: Icons.local_fire_department_rounded,
                            value: '${state.currentStreak}',
                            label: strings('streak'),
                          ),
                        ),
                        const SizedBox(width: AppSizes.space10),
                        Expanded(
                          child: _StatCard(
                            icon: Icons.track_changes_rounded,
                            value: '${(state.quizAccuracy * 100).round()}%',
                            label: strings('quizAccuracy'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.space10),
                    SizedBox(
                      width: double.infinity,
                      child: _StatCard(
                        icon: Icons.bolt_rounded,
                        value: '${state.totalXp}',
                        label: strings('totalXp'),
                      ),
                    ),
                    const SizedBox(height: AppSizes.space26),
                    Text(
                      strings('weeklyActivity'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSizes.space12),
                    Container(
                      height: AppSizes.size210,
                      padding: const EdgeInsets.fromLTRB(
                        AppSizes.size18,
                        AppSizes.size24,
                        AppSizes.size18,
                        AppSizes.size14,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppSizes.radius24),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(7, (index) {
                          final activity = index == 6
                              ? state.studiedCount.clamp(1, state.dailyGoal)
                              : (state.studiedCount == 0
                                    ? 0
                                    : (index * 3 + state.studiedCount) %
                                          (state.dailyGoal + 1));
                          final height =
                              22 +
                              (activity / state.dailyGoal.clamp(1, 100)) * 120;
                          const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSizes.size4,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 300),
                                    height: height,
                                    decoration: BoxDecoration(
                                      color: index == 6
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.primary
                                          : Theme.of(
                                              context,
                                            ).colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(
                                        AppSizes.radius9,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: AppSizes.space9),
                                  Text(
                                    days[index],
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: AppSizes.space26),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${strings('progress')} · JLPT',
                        maxLines: 1,
                        softWrap: false,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(height: AppSizes.space12),
                    Container(
                      padding: const EdgeInsets.all(AppSizes.size20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppSizes.radius24),
                      ),
                      child: Table(
                        columnWidths: const {
                          0: IntrinsicColumnWidth(),
                          1: FlexColumnWidth(),
                          2: IntrinsicColumnWidth(),
                        },
                        defaultVerticalAlignment:
                            TableCellVerticalAlignment.middle,
                        children: ['N5', 'N4', 'N3', 'N2', 'N1'].map((level) {
                          final total = state.vocabulary
                              .where((word) => word.jlptLevel == level)
                              .length;
                          final studied = state.progress.values
                              .where((item) => item.jlptLevel == level)
                              .length;
                          return TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSizes.size16,
                                ),
                                child: Text(
                                  level,
                                  style: const TextStyle(
                                    fontWeight: AppFontWeights.extraBold,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  AppSizes.size10,
                                  0,
                                  AppSizes.size10,
                                  AppSizes.size16,
                                ),
                                child: LinearProgressIndicator(
                                  value: total == 0 ? 0 : studied / total,
                                  minHeight: AppSizes.size10,
                                  borderRadius: BorderRadius.circular(
                                    AppSizes.radius10,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSizes.size16,
                                ),
                                child: Text(
                                  '$studied / $total',
                                  textAlign: TextAlign.start,
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
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

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSizes.size18),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(AppSizes.radius22),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: AppSizes.space17),
        Text(
          value,
          style: const TextStyle(
            fontSize: AppSizes.font30,
            fontWeight: AppFontWeights.extraBold,
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    ),
  );
}
