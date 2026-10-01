import 'package:flutter/material.dart';
import 'package:jlpt_practice/data/models/kanji.dart';
import 'package:jlpt_practice/features/vocabulary/cover_masking.dart';
import 'package:jlpt_practice/features/vocabulary/masked_translation.dart';

/// Keeps each kanji run's reading directly above its written form.
class ExampleFuriganaText extends StatelessWidget {
  const ExampleFuriganaText({
    required this.segments,
    required this.style,
    required this.wordTargets,
    required this.hideReadings,
    super.key,
  });

  final List<FuriganaSegment> segments;
  final TextStyle style;
  final List<String> wordTargets;
  final bool hideReadings;

  @override
  Widget build(BuildContext context) {
    final displaySegments = [
      for (final segment in segments)
        FuriganaSegment(
          segment.text.replaceAllMapped(
            RegExp(r'([.!?。！？])\s*(?=[A-Za-z][A-Za-z0-9]{0,2}\s*[：:])'),
            (match) => '${match.group(1)}\n',
          ),
          segment.ruby,
        ),
    ];
    final sentence = displaySegments.map((segment) => segment.text).join();
    final baseMasks = maskSegments(sentence, wordTargets);
    final covered = <({int start, int end})>[];
    var offset = 0;
    for (final mask in baseMasks) {
      if (mask.covered) {
        covered.add((start: offset, end: offset + mask.text.length));
      }
      offset += mask.text.length;
    }
    final rubyStyle = style.copyWith(
      fontSize: 12,
      height: 1.2,
      color: Theme.of(context).colorScheme.primary,
    );
    final lines = <List<Widget>>[[]];
    offset = 0;
    for (final segment in displaySegments) {
      // Plain kana and punctuation can wrap individually; annotated kanji
      // stay together with their reading. Explicit dialogue breaks stay intact.
      final parts = segment.ruby == null
          ? segment.text.runes.map(String.fromCharCode)
          : [segment.text];
      for (final part in parts) {
        if (part == '\n') {
          lines.add([]);
          offset++;
          continue;
        }
        final start = offset;
        offset += part.length;
        final masks = maskSegmentsFromSpans(part, [
          for (final span in covered)
            if (span.start < offset && span.end > start)
              (start: span.start - start, end: span.end - start),
        ]);
        lines.last.add(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 16,
                child: segment.ruby == null
                    ? null
                    : MaskedSegmentsText(
                        key: ValueKey('example-ruby-$start'),
                        segments: [
                          MaskSegment(segment.ruby!, covered: hideReadings),
                        ],
                        style: rubyStyle,
                        glyphWidth: 1,
                      ),
              ),
              masks.any((mask) => mask.covered)
                  ? MaskedSegmentsText(
                      segments: masks,
                      style: style,
                      glyphWidth: 1,
                    )
                  : Text(part, style: style),
            ],
          ),
        );
      }
    }
    return Semantics(
      label: baseMasks.map((mask) => mask.covered ? '…' : mask.text).join(),
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final line in lines)
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.end,
                runSpacing: 2,
                children: line,
              ),
          ],
        ),
      ),
    );
  }
}
