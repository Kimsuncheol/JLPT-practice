import 'package:flutter/material.dart';
import 'package:jlpt_practice/shared/skeleton.dart';

/// Mirrors [GrammarListScreen]'s layout so nothing jumps once data loads.
class GrammarListSkeleton extends StatelessWidget {
  const GrammarListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: ShimmerBone(width: double.infinity, height: 54, radius: 18),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
            itemCount: 8,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
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
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(17),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerCircle(size: 40),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerBone(width: 140, height: 18, radius: 6),
                const SizedBox(height: 8),
                const ShimmerBone(
                  width: double.infinity,
                  height: 14,
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
