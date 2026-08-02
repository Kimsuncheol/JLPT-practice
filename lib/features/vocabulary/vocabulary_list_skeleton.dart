import 'package:flutter/material.dart';
import 'package:jlpt_practice/shared/skeleton.dart';

/// Mirrors [VocabularyListScreen]'s layout so nothing jumps once data loads.
class VocabularyListSkeleton extends StatelessWidget {
  const VocabularyListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ShimmerBone(width: 96, height: 28, radius: 8),
              const SizedBox(height: 16),
              const ShimmerBone(width: double.infinity, height: 54, radius: 18),
              const SizedBox(height: 12),
              SizedBox(
                height: 40,
                child: Row(
                  children: List.generate(
                    5,
                    (index) => const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: ShimmerBone(width: 52, height: 40, radius: 12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const ShimmerBone(width: double.infinity, height: 54, radius: 18),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
            itemCount: 7,
            separatorBuilder: (_, _) => const SizedBox(height: 9),
            itemBuilder: (context, _) => const _VocabularyTileSkeleton(),
          ),
        ),
      ],
    );
  }
}

class _VocabularyTileSkeleton extends StatelessWidget {
  const _VocabularyTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.fromLTRB(17, 15, 17, 17),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerBone(width: 50, height: 50, radius: 15),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const ShimmerBone(width: 64, height: 20, radius: 6),
                    const SizedBox(width: 8),
                    const ShimmerBone(width: 70, height: 14, radius: 6),
                  ],
                ),
                const SizedBox(height: 8),
                const ShimmerBone(width: 160, height: 14, radius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
