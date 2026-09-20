import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/services/meaning_mask_service.dart';
import 'package:jlpt_practice/features/vocabulary/cover_masking.dart';
import 'package:jlpt_practice/features/vocabulary/cover_tape.dart';

/// Renders [segments] centered, laying tape over the covered runs.
class MaskedSegmentsText extends StatelessWidget {
  const MaskedSegmentsText({
    required this.segments,
    required this.style,
    required this.glyphWidth,
    super.key,
  });

  final List<MaskSegment> segments;
  final TextStyle? style;
  final double glyphWidth;

  @override
  Widget build(BuildContext context) {
    final fontSize = style?.fontSize ?? 14;
    return Text.rich(
      TextSpan(
        style: style,
        children: [
          for (final segment in segments)
            if (segment.covered)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: coverTapeFor(
                  characters: segment.text.length,
                  fontSize: fontSize,
                  glyphWidth: glyphWidth,
                ),
              )
            else
              TextSpan(text: segment.text),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// A Korean example translation that hides the word's meaning, including its
/// inflected forms, while [hideMeanings] is true.
///
/// The morphological match runs off the UI thread. Until it finishes — or if
/// it fails — the plain substring mask is shown, so the answer is never
/// visible even for a moment.
class MaskedTranslation extends ConsumerStatefulWidget {
  const MaskedTranslation({
    required this.translation,
    required this.meanings,
    required this.hideMeanings,
    required this.style,
    required this.glyphWidth,
    super.key,
  });

  final String translation;

  /// The word's Korean meanings, e.g. `['일하다', '근무하다']`.
  final List<String> meanings;
  final bool hideMeanings;
  final TextStyle? style;
  final double glyphWidth;

  @override
  ConsumerState<MaskedTranslation> createState() => _MaskedTranslationState();
}

class _MaskedTranslationState extends ConsumerState<MaskedTranslation> {
  Future<List<MaskSpan>>? _spans;

  @override
  void initState() {
    super.initState();
    _spans = _search();
  }

  @override
  void didUpdateWidget(MaskedTranslation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.translation != widget.translation ||
        oldWidget.hideMeanings != widget.hideMeanings ||
        !_sameMeanings(oldWidget.meanings, widget.meanings)) {
      _spans = _search();
    }
  }

  Future<List<MaskSpan>>? _search() {
    if (!widget.hideMeanings || widget.meanings.isEmpty) return null;
    return ref
        .read(meaningMaskServiceProvider)
        .findMaskSpans(widget.meanings.join(', '), widget.translation);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.hideMeanings) {
      return Text(
        widget.translation,
        textAlign: TextAlign.center,
        style: widget.style,
      );
    }
    final baseline = maskSegments(
      widget.translation,
      meaningMaskTargets(widget.meanings),
    );
    return FutureBuilder<List<MaskSpan>>(
      future: _spans,
      builder: (context, snapshot) => MaskedSegmentsText(
        segments: snapshot.hasData
            ? maskSegmentsFromSpans(widget.translation, [
                for (final span in snapshot.data!)
                  (start: span.start, end: span.end),
              ])
            : baseline,
        style: widget.style,
        glyphWidth: widget.glyphWidth,
      ),
    );
  }
}

bool _sameMeanings(List<String> a, List<String> b) =>
    a.length == b.length &&
    Iterable.generate(a.length).every((i) => a[i] == b[i]);
