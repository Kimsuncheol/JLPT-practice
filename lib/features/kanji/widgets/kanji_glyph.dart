import 'package:flutter/material.dart';
import 'package:jlpt_practice/features/vocabulary/covered_text.dart';
import 'package:jlpt_practice/core/constants/app_font_weights.dart';
import 'package:jlpt_practice/core/constants/app_sizes.dart';

/// The kanji, or tape of the same size while it is [hidden].
class KanjiGlyph extends StatelessWidget {
  const KanjiGlyph({
    required this.character,
    required this.fontSize,
    this.hidden = false,
    super.key,
  });

  final String character;
  final double fontSize;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    return CoveredText(
      text: character,
      hidden: hidden,
      tilt: -0.02,
      style: TextStyle(
        fontSize: fontSize,
        height: AppSizes.lineHeight1_1,
        fontWeight: AppFontWeights.extraBold,
      ),
    );
  }
}
