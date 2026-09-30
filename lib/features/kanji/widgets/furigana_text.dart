import 'package:flutter/material.dart';
import 'package:jlpt_practice/data/models/kanji.dart';

/// A sentence with each kanji word's reading printed above it.
///
/// Flutter has no ruby layout, so every segment is a small column and the
/// segments wrap like words. Segments without a reading keep a blank line of
/// the same height, which keeps the text on one baseline. With
/// [hideFurigana] the readings keep their space but are not drawn.
class FuriganaText extends StatelessWidget {
  const FuriganaText({
    required this.segments,
    required this.style,
    required this.hideFurigana,
    super.key,
  });

  final List<FuriganaSegment> segments;
  final TextStyle style;
  final bool hideFurigana;

  @override
  Widget build(BuildContext context) {
    final fontSize = style.fontSize ?? 14;
    final rubyStyle = style.copyWith(
      fontSize: fontSize * 0.6,
      height: 1,
      color: Theme.of(context).colorScheme.primary,
    );
    final rubyHeight = fontSize * 0.6 + 2;
    return Semantics(
      label: segments.map((segment) => segment.text).join(),
      child: ExcludeSemantics(
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          runSpacing: 2,
          children: [
            for (final segment in segments)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: rubyHeight,
                    child: segment.ruby == null || hideFurigana
                        ? null
                        : Text(
                            segment.ruby!,
                            style: rubyStyle,
                            softWrap: false,
                          ),
                  ),
                  Text(segment.text, style: style),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
