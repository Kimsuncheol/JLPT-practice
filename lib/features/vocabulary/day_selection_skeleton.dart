import 'package:flutter/material.dart';
import 'package:jlpt_practice/shared/skeleton.dart';
import 'package:jlpt_practice/core/constants/app_sizes.dart';

/// Mirrors [DaySelectionScreen]'s layout so nothing jumps once data loads.
class DaySelectionSkeleton extends StatelessWidget {
  const DaySelectionSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSizes.size20,
            AppSizes.size8,
            AppSizes.size20,
            AppSizes.size16,
          ),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSizes.size20),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppSizes.radius24),
            ),
            child: const Row(
              children: [
                ShimmerCircle(size: AppSizes.size56),
                SizedBox(width: AppSizes.space16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerBone(
                        width: AppSizes.size120,
                        height: AppSizes.size20,
                        radius: 6,
                      ),
                      SizedBox(height: AppSizes.space8),
                      ShimmerBone(
                        width: AppSizes.size160,
                        height: AppSizes.size14,
                        radius: 6,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.size20,
              0,
              AppSizes.size20,
              AppSizes.size28,
            ),
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
