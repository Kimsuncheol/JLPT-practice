import 'package:flutter/material.dart';
import 'package:jlpt_practice/features/vocabulary/cover_tape.dart';
import 'package:jlpt_practice/core/constants/app_sizes.dart';

/// Size of the readings on the card front, larger than on the back.
const frontFontSize = 32.0;

/// A caption above a wrap of tappable readings.
class ReadingGroup extends StatelessWidget {
  const ReadingGroup({
    required this.label,
    required this.readings,
    required this.hidden,
    required this.onSpeak,
    super.key,
  });

  final String label;
  final List<String> readings;
  final bool hidden;
  final ValueChanged<String> onSpeak;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: AppSizes.space6),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final reading in readings)
            ReadingChip(
              reading: reading,
              hidden: hidden,
              color: Theme.of(context).colorScheme.primary,
              fontSize: frontFontSize,
              onTap: () => onSpeak(reading),
            ),
        ],
      ),
    ],
  );
}

/// A reading that speaks itself when tapped. Covered readings can still be
/// tapped, so the learner can check a recalled reading by ear.
class ReadingChip extends StatelessWidget {
  const ReadingChip({
    required this.reading,
    required this.hidden,
    required this.onTap,
    this.color,
    this.fontSize,
    super.key,
  });

  final String reading;
  final bool hidden;
  final VoidCallback onTap;

  /// The text color; the surface text color when null.
  final Color? color;

  /// The text size; the theme's title size when null.
  final double? fontSize;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.titleLarge?.copyWith(
      color: color ?? colors.onSurface,
      fontSize: fontSize,
    );
    return Semantics(
      button: true,
      child: Material(
        key: ValueKey('reading-$reading'),
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppSizes.radius16),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppSizes.radius16),
          splashFactory: NoSplash.splashFactory,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.size14,
              vertical: AppSizes.size8,
            ),
            child: hidden
                ? coverTapeFor(
                    characters: reading.length,
                    fontSize: style?.fontSize ?? 22,
                    maxWidth: AppSizes.size120,
                    glyphWidth: 0.9,
                  )
                : Text(reading, style: style),
          ),
        ),
      ),
    );
  }
}
