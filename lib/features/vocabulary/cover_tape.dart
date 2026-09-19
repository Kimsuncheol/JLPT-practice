import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';

/// A strip of masking tape laid over text the learner wants to recall.
class CoverTape extends StatelessWidget {
  const CoverTape({
    required this.width,
    required this.height,
    this.tilt = -0.012,
    super.key,
  });

  final double width;
  final double height;

  /// Rotation in radians, so neighbouring strips look hand-placed.
  final double tilt;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.strings('covered'),
      child: ExcludeSemantics(
        child: Transform.rotate(
          angle: tilt,
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tape sized for [characters] glyphs of text at [fontSize].
CoverTape coverTapeFor({
  required int characters,
  required double fontSize,
  double? maxWidth,
  double glyphWidth = 1,
  double tilt = -0.012,
}) {
  final raw = math.max(2, characters) * fontSize * glyphWidth;
  return CoverTape(
    width: maxWidth == null ? raw : math.min(raw, maxWidth),
    height: fontSize * 1.05,
    tilt: tilt,
  );
}
