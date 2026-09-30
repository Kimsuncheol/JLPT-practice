import 'package:flutter/material.dart';
import 'package:jlpt_practice/features/vocabulary/cover_tape.dart';

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
    if (hidden) {
      return coverTapeFor(
        characters: 1,
        fontSize: fontSize,
        maxWidth: fontSize * 1.3,
        glyphWidth: 0.9,
        tilt: -0.02,
      );
    }
    return Text(
      character,
      style: TextStyle(
        fontSize: fontSize,
        height: 1.1,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
