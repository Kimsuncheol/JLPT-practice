import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:jlpt_practice/data/models/kanji.dart';
import 'package:jlpt_practice/features/vocabulary/cover_masking.dart';
import 'package:jlpt_practice/features/vocabulary/masked_translation.dart';
import 'package:jlpt_practice/core/constants/app_sizes.dart';
import 'package:jlpt_practice/core/constants/app_spacing.dart';

/// Keeps each kanji run's reading directly above its written form.
class ExampleFuriganaText extends StatelessWidget {
  const ExampleFuriganaText({
    required this.segments,
    required this.style,
    required this.wordTargets,
    required this.hideReadings,
    this.alignment = WrapAlignment.center,
    this.runSpacingWithFurigana,
    this.fontScale = 1,
    super.key,
  });

  final List<FuriganaSegment> segments;

  /// The sentence's style at [fontScale] 1.
  final TextStyle style;
  final List<String> wordTargets;
  final bool hideReadings;
  final WrapAlignment alignment;

  /// Space above wrapped lines with visible furigana; the default when null.
  final double? runSpacingWithFurigana;

  /// Scales the sentence and its furigana together.
  final double fontScale;

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
    final sentenceStyle = style.fontSize == null
        ? style
        : style.copyWith(fontSize: style.fontSize! * fontScale);
    final rubyStyle = style.copyWith(
      fontSize: AppSizes.font12 * fontScale,
      height: AppSizes.lineHeight1_2,
      color: Theme.of(context).colorScheme.primary,
    );
    final lines = <List<Widget>>[[]];
    final readingsByLine = <List<bool>>[[]];
    offset = 0;
    for (final segment in displaySegments) {
      // Plain kana can wrap individually; annotated kanji stay together with
      // their reading. Explicit dialogue breaks stay intact.
      final parts = segment.ruby == null
          ? segment.text.runes.map(String.fromCharCode)
          : [segment.text];
      for (final part in parts) {
        if (part == '\n') {
          lines.add([]);
          readingsByLine.add([]);
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
        final unit = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (segment.ruby != null)
              SizedBox(
                height: AppSizes.size16 * fontScale,
                child: MaskedSegmentsText(
                  key: ValueKey('example-ruby-$start'),
                  segments: [MaskSegment(segment.ruby!, covered: hideReadings)],
                  style: rubyStyle,
                  glyphWidth: 1,
                ),
              ),
            masks.any((mask) => mask.covered)
                ? MaskedSegmentsText(
                    segments: masks,
                    style: sentenceStyle,
                    glyphWidth: 1,
                  )
                : Text(part, style: sentenceStyle),
          ],
        );
        // Sentence-ending punctuation must wrap with the preceding unit,
        // including when that unit is a kanji with a reading or a word mask.
        if (lines.last.isNotEmpty && RegExp(r'^[。．.!?！？]+$').hasMatch(part)) {
          final preceding = lines.last.removeLast();
          lines.last.add(
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [preceding, unit],
            ),
          );
        } else {
          lines.last.add(unit);
          readingsByLine.last.add(
            !hideReadings && (segment.ruby?.isNotEmpty ?? false),
          );
        }
      }
    }
    return Semantics(
      label: baseMasks.map((mask) => mask.covered ? '…' : mask.text).join(),
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: alignment == WrapAlignment.start
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            for (var index = 0; index < lines.length; index++) ...[
              // Speaker turns are separate blocks, so keep their gap even
              // when a turn has no kanji or its readings are hidden.
              if (index > 0) const SizedBox(height: AppSpacing.run20),
              _FuriganaWrap(
                alignment: alignment,
                textDirection: Directionality.of(context),
                readingSpacing: runSpacingWithFurigana ?? AppSpacing.run20,
                hasReadings: readingsByLine[index],
                children: lines[index],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Like a horizontal Wrap, with the gap chosen for each incoming row.
class _FuriganaWrap extends MultiChildRenderObjectWidget {
  const _FuriganaWrap({
    required this.alignment,
    required this.textDirection,
    required this.readingSpacing,
    required this.hasReadings,
    required super.children,
  });

  final WrapAlignment alignment;
  final TextDirection textDirection;
  final double readingSpacing;
  final List<bool> hasReadings;

  @override
  _RenderFuriganaWrap createRenderObject(BuildContext context) =>
      _RenderFuriganaWrap(
        alignment,
        textDirection,
        readingSpacing,
        hasReadings,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderFuriganaWrap renderObject,
  ) {
    renderObject
      ..alignment = alignment
      ..textDirection = textDirection
      ..readingSpacing = readingSpacing
      ..hasReadings = hasReadings
      ..markNeedsLayout();
  }
}

class _RenderFuriganaWrap extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, WrapParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, WrapParentData> {
  _RenderFuriganaWrap(
    this.alignment,
    this.textDirection,
    this.readingSpacing,
    this.hasReadings,
  );

  WrapAlignment alignment;
  TextDirection textDirection;
  double readingSpacing;
  List<bool> hasReadings;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! WrapParentData) {
      child.parentData = WrapParentData();
    }
  }

  Size _layout(BoxConstraints constraints, {required bool dry}) {
    final childConstraints = BoxConstraints(maxWidth: constraints.maxWidth);
    final rows =
        <
          ({
            List<RenderBox> children,
            double width,
            double height,
            bool reading,
          })
        >[];
    var rowChildren = <RenderBox>[];
    var rowWidth = 0.0;
    var rowHeight = 0.0;
    var rowReading = false;
    var index = 0;
    final sizes = <RenderBox, Size>{};
    void finishRow() {
      rows.add((
        children: rowChildren,
        width: rowWidth,
        height: rowHeight,
        reading: rowReading,
      ));
      rowChildren = [];
      rowWidth = 0;
      rowHeight = 0;
      rowReading = false;
    }

    var child = firstChild;
    while (child != null) {
      if (!dry) child.layout(childConstraints, parentUsesSize: true);
      final childSize = dry ? child.getDryLayout(childConstraints) : child.size;
      sizes[child] = childSize;
      if (rowChildren.isNotEmpty &&
          rowWidth + childSize.width > constraints.maxWidth) {
        finishRow();
      }
      rowChildren.add(child);
      rowWidth += childSize.width;
      if (childSize.height > rowHeight) rowHeight = childSize.height;
      rowReading = rowReading || hasReadings[index];
      index++;
      child = childAfter(child);
    }
    if (rowChildren.isNotEmpty) finishRow();

    var width = 0.0;
    var height = 0.0;
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row.width > width) width = row.width;
      if (i > 0) height += row.reading ? readingSpacing : AppSpacing.run2;
      height += row.height;
    }
    final result = constraints.constrain(Size(width, height));
    if (dry) return result;

    var y = 0.0;
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (i > 0) y += row.reading ? readingSpacing : AppSpacing.run2;
      final free = (result.width - row.width).clamp(0.0, double.infinity);
      final count = row.children.length;
      final (leading, between) = switch (alignment) {
        WrapAlignment.start => (0.0, 0.0),
        WrapAlignment.end => (free, 0.0),
        WrapAlignment.center => (free / 2, 0.0),
        WrapAlignment.spaceBetween => (
          0.0,
          count > 1 ? free / (count - 1) : 0.0,
        ),
        WrapAlignment.spaceAround => (free / count / 2, free / count),
        WrapAlignment.spaceEvenly => (free / (count + 1), free / (count + 1)),
      };
      var x = leading;
      for (final child in row.children) {
        final childSize = sizes[child]!;
        final parentData = child.parentData! as WrapParentData;
        parentData.offset = Offset(
          textDirection == TextDirection.rtl
              ? result.width - x - childSize.width
              : x,
          y + row.height - childSize.height,
        );
        x += childSize.width + between;
      }
      y += row.height;
    }
    return result;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _layout(constraints, dry: true);

  @override
  void performLayout() => size = _layout(constraints, dry: false);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
