import 'package:flutter/material.dart';
import 'package:jlpt_practice/core/constants/app_font_weights.dart';
import 'package:jlpt_practice/core/constants/app_sizes.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';

/// Pill naming the study day, coloured from the theme so it follows the
/// light or dark appearance.
class DayChip extends StatelessWidget {
  const DayChip({required this.day, super.key});

  final int day;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(AppSizes.radius999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.size14,
          vertical: AppSizes.size6,
        ),
        child: Text(
          '${context.strings('day')} $day',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: colors.onPrimaryContainer,
            fontWeight: AppFontWeights.bold700,
          ),
        ),
      ),
    );
  }
}

/// [DayChip] in the top-right corner of the nearest [Stack]; every study
/// screen places it here so its position is defined once.
class PositionedDayChip extends StatelessWidget {
  const PositionedDayChip({required this.day, super.key});

  final int day;

  @override
  Widget build(BuildContext context) => PositionedDirectional(
    end: AppSizes.dayChipEnd,
    top: AppSizes.dayChipTop,
    child: DayChip(day: day),
  );
}
