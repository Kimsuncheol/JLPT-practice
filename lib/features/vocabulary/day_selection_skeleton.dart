import 'package:flutter/material.dart';
import 'package:jlpt_practice/shared/skeleton.dart';

/// Mirrors [DaySelectionScreen]'s layout so nothing jumps once data loads.
class DaySelectionSkeleton extends StatelessWidget {
  const DaySelectionSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Row(
              children: [
                ShimmerCircle(size: 56),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBone(width: 120, height: 20, radius: 6),
                      SizedBox(height: 8),
                      ShimmerBone(width: 160, height: 14, radius: 6),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 12.0;
                final columns = (constraints.maxWidth / 120).floor().clamp(
                  4,
                  6,
                );
                return GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: spacing,
                    mainAxisSpacing: spacing,
                  ),
                  itemCount: columns * 4,
                  itemBuilder: (context, _) => const ShimmerBone(
                    width: double.infinity,
                    height: double.infinity,
                    radius: 24,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
