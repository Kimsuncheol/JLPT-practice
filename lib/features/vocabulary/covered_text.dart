import 'package:flutter/material.dart';
import 'package:jlpt_practice/features/vocabulary/cover_tape.dart';

/// Keeps the text's exact wrapping and dimensions underneath its cover.
class CoveredText extends StatelessWidget {
  const CoveredText({
    required this.text,
    required this.hidden,
    this.style,
    this.tilt = -0.012,
    super.key,
  });

  final String text;
  final bool hidden;
  final TextStyle? style;
  final double tilt;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Text.rich(
        TextSpan(text: text, semanticsLabel: hidden ? '' : null),
        style: hidden
            ? (style ?? const TextStyle()).copyWith(color: Colors.transparent)
            : style,
      ),
      if (hidden)
        Positioned.fill(child: CoverTape(width: 0, height: 0, tilt: tilt)),
    ],
  );
}
