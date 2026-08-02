import 'package:flutter/material.dart';
import 'package:jlpt_practice/shared/skeleton.dart';

/// Mirrors [DashboardScreen]'s layout so nothing jumps once data loads.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
            children: [
              Row(
                children: const [
                  ShimmerCircle(size: 46),
                  Spacer(),
                  ShimmerBone(width: 84, height: 32, radius: 16),
                ],
              ),
              const SizedBox(height: 26),
              const ShimmerBone(width: 220, height: 30, radius: 8),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBone(width: 130, height: 14, radius: 6),
                    SizedBox(height: 14),
                    ShimmerBone(width: 100, height: 42, radius: 8),
                    SizedBox(height: 18),
                    ShimmerBone(width: double.infinity, height: 9, radius: 9),
                    SizedBox(height: 18),
                    Row(
                      children: [
                        ShimmerBone(width: 110, height: 20, radius: 6),
                        SizedBox(width: 22),
                        ShimmerBone(width: 90, height: 20, radius: 6),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              const _ActionTileSkeleton(),
              const SizedBox(height: 10),
              const _ActionTileSkeleton(),
              const SizedBox(height: 10),
              const _ActionTileSkeleton(),
              const SizedBox(height: 10),
              Row(
                children: const [
                  Expanded(child: _SmallActionSkeleton()),
                  SizedBox(width: 10),
                  Expanded(child: _SmallActionSkeleton()),
                ],
              ),
              const SizedBox(height: 24),
              const ShimmerBone(width: 150, height: 22, radius: 6),
              const SizedBox(height: 12),
              Row(
                children: const [
                  Expanded(child: _MetricCardSkeleton()),
                  SizedBox(width: 10),
                  Expanded(child: _MetricCardSkeleton()),
                  SizedBox(width: 10),
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
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: const Row(
            children: [
              ShimmerCircle(size: 24),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBone(width: 120, height: 15, radius: 6),
                    SizedBox(height: 6),
                    ShimmerBone(width: 50, height: 12, radius: 6),
                  ],
                ),
              ),
              ShimmerCircle(size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTileSkeleton extends StatelessWidget {
  const _ActionTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.all(18),
      child: const Row(
        children: [
          ShimmerBone(width: 52, height: 52, radius: 17),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBone(width: 140, height: 16, radius: 6),
                SizedBox(height: 8),
                ShimmerBone(width: 180, height: 13, radius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallActionSkeleton extends StatelessWidget {
  const _SmallActionSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.all(16),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShimmerBone(width: 24, height: 24, radius: 12),
              Spacer(),
              ShimmerBone(width: 30, height: 20, radius: 10),
            ],
          ),
          SizedBox(height: 18),
          ShimmerBone(width: 90, height: 16, radius: 6),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerBone(width: 20, height: 20, radius: 10),
          SizedBox(height: 12),
          ShimmerBone(width: 40, height: 24, radius: 6),
          SizedBox(height: 6),
          ShimmerBone(width: 60, height: 12, radius: 6),
        ],
      ),
    );
  }
}
