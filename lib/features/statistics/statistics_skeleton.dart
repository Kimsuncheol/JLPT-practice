import 'package:flutter/material.dart';
import 'package:jlpt_practice/shared/skeleton.dart';
import 'package:jlpt_practice/core/constants/app_sizes.dart';

/// Mirrors [StatisticsScreen]'s layout so nothing jumps once data loads.
class StatisticsSkeleton extends StatelessWidget {
  const StatisticsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
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
              const ShimmerBone(
                width: AppSizes.size140,
                height: AppSizes.size28,
                radius: 8,
              ),
              const SizedBox(height: AppSizes.space20),
              Row(
                children: const [
                  Expanded(child: _StatCardSkeleton()),
                  SizedBox(width: AppSizes.space10),
                  Expanded(child: _StatCardSkeleton()),
                ],
              ),
              const SizedBox(height: AppSizes.space10),
              Row(
                children: const [
                  Expanded(child: _StatCardSkeleton()),
                  SizedBox(width: AppSizes.space10),
                  Expanded(child: _StatCardSkeleton()),
                ],
              ),
              const SizedBox(height: AppSizes.space10),
              const _StatCardSkeleton(),
              const SizedBox(height: AppSizes.space26),
              const ShimmerBone(
                width: AppSizes.size160,
                height: AppSizes.size22,
                radius: 6,
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
                    final heights = [
                      70.0,
                      110.0,
                      90.0,
                      130.0,
                      60.0,
                      100.0,
                      145.0,
                    ];
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.size4,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ShimmerBone(height: heights[index], radius: 9),
                            const SizedBox(height: AppSizes.space9),
                            const ShimmerBone(
                              width: AppSizes.size12,
                              height: AppSizes.size10,
                              radius: 4,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: AppSizes.space26),
              const ShimmerBone(
                width: AppSizes.size130,
                height: AppSizes.size22,
                radius: 6,
              ),
              const SizedBox(height: AppSizes.space12),
              Container(
                padding: const EdgeInsets.all(AppSizes.size20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppSizes.radius24),
                ),
                child: Column(
                  children: List.generate(
                    5,
                    (_) => const Padding(
                      padding: EdgeInsets.only(bottom: AppSizes.size16),
                      child: Row(
                        children: [
                          ShimmerBone(
                            width: AppSizes.size34,
                            height: AppSizes.size16,
                            radius: 6,
                          ),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: AppSizes.size10,
                              ),
                              child: ShimmerBone(
                                width: double.infinity,
                                height: AppSizes.size10,
                                radius: 10,
                              ),
                            ),
                          ),
                          ShimmerBone(
                            width: AppSizes.size38,
                            height: AppSizes.size12,
                            radius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const _RewardedXpCardSkeleton(),
      ],
    );
  }
}

class _RewardedXpCardSkeleton extends StatelessWidget {
  const _RewardedXpCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSizes.size20,
          AppSizes.size4,
          AppSizes.size20,
          AppSizes.size8,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(AppSizes.radius16),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.size16,
            vertical: AppSizes.size12,
          ),
          child: const Row(
            children: [
              ShimmerCircle(size: AppSizes.size24),
              SizedBox(width: AppSizes.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBone(
                      width: AppSizes.size120,
                      height: AppSizes.size15,
                      radius: 6,
                    ),
                    SizedBox(height: AppSizes.space6),
                    ShimmerBone(
                      width: AppSizes.size50,
                      height: AppSizes.size12,
                      radius: 6,
                    ),
                  ],
                ),
              ),
              ShimmerCircle(size: AppSizes.size20),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCardSkeleton extends StatelessWidget {
  const _StatCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.size18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSizes.radius22),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBone(
            width: AppSizes.size24,
            height: AppSizes.size24,
            radius: 12,
          ),
          SizedBox(height: AppSizes.space17),
          ShimmerBone(
            width: AppSizes.size50,
            height: AppSizes.size26,
            radius: 6,
          ),
          SizedBox(height: AppSizes.space6),
          ShimmerBone(
            width: AppSizes.size70,
            height: AppSizes.size13,
            radius: 6,
          ),
        ],
      ),
    );
  }
}
