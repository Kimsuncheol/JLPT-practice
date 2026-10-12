import 'package:flutter/material.dart';
import 'package:jlpt_practice/core/constants/app_spacing.dart';
import 'package:jlpt_practice/features/vocabulary/covered_text.dart';

/// The Korean hun (meaning) or eum (sound) of a kanji, shown with the kun or
/// on readings it belongs with. Covered by tape while [hidden].
class HunEumLine extends StatelessWidget {
  const HunEumLine({required this.values, required this.hidden, super.key});

  final List<String> values;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.titleLarge;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.item8 * 2,
      runSpacing: AppSpacing.run8,
      children: [
        for (final value in values)
          CoveredText(text: value, hidden: hidden, style: style),
      ],
    );
  }
}
