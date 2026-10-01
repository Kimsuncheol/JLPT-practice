import 'package:flutter/material.dart';
import 'package:jlpt_practice/shared/skeleton.dart';
import 'package:jlpt_practice/core/constants/app_sizes.dart';

/// Mirrors [GrammarListScreen]'s layout so nothing jumps once data loads.
class GrammarListSkeleton extends StatelessWidget {
  const GrammarListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(
            AppSizes.size20,
            AppSizes.size12,
            AppSizes.size20,
            AppSizes.size12,
          ),
          child: ShimmerBone(
            width: double.infinity,
            height: AppSizes.size54,
            radius: 18,
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.size20,
              AppSizes.size4,
              AppSizes.size20,
              AppSizes.size28,
            ),
            itemCount: 8,
            separatorBuilder: (_, _) =>
                const SizedBox(height: AppSizes.space10),
            itemBuilder: (context, _) => const _GrammarCardSkeleton(),
          ),
        ),
      ],
    );
  }
}

class _GrammarCardSkeleton extends StatelessWidget {
  const _GrammarCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppSizes.radius20),
      ),
      padding: const EdgeInsets.all(AppSizes.size17),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerCircle(size: AppSizes.size40),
          const SizedBox(width: AppSizes.space14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerBone(
                  width: AppSizes.size140,
                  height: AppSizes.size18,
                  radius: 6,
                ),
                const SizedBox(height: AppSizes.space8),
                const ShimmerBone(
                  width: double.infinity,
                  height: AppSizes.size14,
                  radius: 6,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
