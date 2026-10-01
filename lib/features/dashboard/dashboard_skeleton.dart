import 'package:flutter/material.dart';
import 'package:jlpt_practice/shared/skeleton.dart';
import 'package:jlpt_practice/core/constants/app_sizes.dart';

/// Mirrors [DashboardScreen]'s layout so nothing jumps once data loads.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
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
                children: const [
                  ShimmerCircle(size: AppSizes.size46),
                  Spacer(),
                  ShimmerBone(
                    width: AppSizes.size84,
                    height: AppSizes.size32,
                    radius: 16,
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.space26),
              const ShimmerBone(
                width: AppSizes.size220,
                height: AppSizes.size30,
                radius: 8,
              ),
              const SizedBox(height: AppSizes.space20),
              Container(
                padding: const EdgeInsets.all(AppSizes.size22),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppSizes.radius28),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBone(
                      width: AppSizes.size130,
                      height: AppSizes.size14,
                      radius: 6,
                    ),
                    SizedBox(height: AppSizes.space14),
                    ShimmerBone(
                      width: AppSizes.size100,
                      height: AppSizes.size42,
                      radius: 8,
                    ),
                    SizedBox(height: AppSizes.space18),
                    ShimmerBone(
                      width: double.infinity,
                      height: AppSizes.size9,
                      radius: 9,
                    ),
                    SizedBox(height: AppSizes.space18),
                    Row(
                      children: [
                        ShimmerBone(
                          width: AppSizes.size110,
                          height: AppSizes.size20,
                          radius: 6,
                        ),
                        SizedBox(width: AppSizes.space22),
                        ShimmerBone(
                          width: AppSizes.size90,
                          height: AppSizes.size20,
                          radius: 6,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.space12),
              Container(
                padding: const EdgeInsets.all(AppSizes.size16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppSizes.radius22),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBone(
                      width: AppSizes.size92,
                      height: AppSizes.size12,
                      radius: 5,
                    ),
                    SizedBox(height: AppSizes.space12),
                    Row(
                      children: [
                        ShimmerBone(
                          width: AppSizes.size44,
                          height: AppSizes.size44,
                          radius: 14,
                        ),
                        SizedBox(width: AppSizes.space12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ShimmerBone(
                                width: AppSizes.size120,
                                height: AppSizes.size16,
                                radius: 6,
                              ),
                              SizedBox(height: AppSizes.space7),
                              ShimmerBone(
                                width: AppSizes.size72,
                                height: AppSizes.size13,
                                radius: 5,
                              ),
                            ],
                          ),
                        ),
                        ShimmerCircle(size: AppSizes.size44),
                      ],
                    ),
                    SizedBox(height: AppSizes.space14),
                    ShimmerBone(
                      width: double.infinity,
                      height: AppSizes.size6,
                      radius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.space18),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.05,
                children: const [
                  _GridActionTileSkeleton(),
                  _GridActionTileSkeleton(),
                  _GridActionTileSkeleton(),
                  _GridActionTileSkeleton(),
                ],
              ),
              const SizedBox(height: AppSizes.space24),
              const ShimmerBone(
                width: AppSizes.size150,
                height: AppSizes.size22,
                radius: 6,
              ),
              const SizedBox(height: AppSizes.space12),
              Row(
                children: const [
                  Expanded(child: _MetricCardSkeleton()),
                  SizedBox(width: AppSizes.space10),
                  Expanded(child: _MetricCardSkeleton()),
                  SizedBox(width: AppSizes.space10),
                  Expanded(child: _MetricCardSkeleton()),
                ],
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

class _GridActionTileSkeleton extends StatelessWidget {
  const _GridActionTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSizes.radius24),
      ),
      padding: const EdgeInsets.all(AppSizes.size18),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBone(
            width: AppSizes.size46,
            height: AppSizes.size46,
            radius: 15,
          ),
          Spacer(),
          ShimmerBone(
            width: AppSizes.size100,
            height: AppSizes.size16,
            radius: 6,
          ),
          SizedBox(height: AppSizes.space8),
          ShimmerBone(
            width: AppSizes.size120,
            height: AppSizes.size13,
            radius: 6,
          ),
        ],
      ),
    );
  }
}

class _MetricCardSkeleton extends StatelessWidget {
  const _MetricCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.size14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSizes.radius18),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBone(
            width: AppSizes.size20,
            height: AppSizes.size20,
            radius: 10,
          ),
          SizedBox(height: AppSizes.space12),
          ShimmerBone(
            width: AppSizes.size40,
            height: AppSizes.size24,
            radius: 6,
          ),
          SizedBox(height: AppSizes.space6),
          ShimmerBone(
            width: AppSizes.size60,
            height: AppSizes.size12,
            radius: 6,
          ),
        ],
      ),
    );
  }
}
