import 'package:flutter/material.dart';
import 'package:jlpt_practice/shared/adaptive_ad_slot.dart';
import 'package:jlpt_practice/shared/skeleton.dart';

/// Mirrors [StatisticsScreen]'s layout so nothing jumps once data loads.
class StatisticsSkeleton extends StatelessWidget {
  const StatisticsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            children: [
              const ShimmerBone(width: 140, height: 28, radius: 8),
              const SizedBox(height: 20),
              Row(
                children: const [
                  Expanded(child: _StatCardSkeleton()),
                  SizedBox(width: 10),
                  Expanded(child: _StatCardSkeleton()),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: const [
                  Expanded(child: _StatCardSkeleton()),
                  SizedBox(width: 10),
                  Expanded(child: _StatCardSkeleton()),
                ],
              ),
              const SizedBox(height: 26),
              const ShimmerBone(width: 160, height: 22, radius: 6),
              const SizedBox(height: 12),
              Container(
                height: 210,
                padding: const EdgeInsets.fromLTRB(18, 24, 18, 14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (index) {
                    final heights = [70.0, 110.0, 90.0, 130.0, 60.0, 100.0, 145.0];
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ShimmerBone(height: heights[index], radius: 9),
                            const SizedBox(height: 9),
                            const ShimmerBone(width: 12, height: 10, radius: 4),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 26),
              const ShimmerBone(width: 130, height: 22, radius: 6),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: List.generate(
                    5,
                    (_) => const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Row(
                        children: [
                          ShimmerBone(width: 34, height: 16, radius: 6),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: ShimmerBone(
                                width: double.infinity,
                                height: 10,
                                radius: 10,
                              ),
                            ),
                          ),
                          ShimmerBone(width: 38, height: 12, radius: 6),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const AdaptiveAdSlot(),
      ],
    );
  }
}

class _StatCardSkeleton extends StatelessWidget {
  const _StatCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBone(width: 24, height: 24, radius: 12),
          SizedBox(height: 17),
          ShimmerBone(width: 50, height: 26, radius: 6),
          SizedBox(height: 6),
          ShimmerBone(width: 70, height: 13, radius: 6),
        ],
      ),
    );
  }
}
