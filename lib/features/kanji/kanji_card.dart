import 'package:flip_card_plus/flip_card_plus.dart';
import 'package:flutter/material.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/data/models/kanji.dart';
import 'package:jlpt_practice/features/vocabulary/cover_tape.dart';

/// What the learner has covered on one kanji card. Both faces share it, so a
/// reading hidden on the front stays hidden on the back.
class KanjiVisibility {
  const KanjiVisibility({
    required this.hideKanji,
    required this.hideKunYomi,
    required this.hideOnYomi,
    required this.hideMeanings,
  });

  final bool hideKanji;
  final bool hideKunYomi;
  final bool hideOnYomi;
  final bool hideMeanings;

  KanjiVisibility copyWith({
    bool? hideKanji,
    bool? hideKunYomi,
    bool? hideOnYomi,
    bool? hideMeanings,
  }) => KanjiVisibility(
    hideKanji: hideKanji ?? this.hideKanji,
    hideKunYomi: hideKunYomi ?? this.hideKunYomi,
    hideOnYomi: hideOnYomi ?? this.hideOnYomi,
    hideMeanings: hideMeanings ?? this.hideMeanings,
  );
}

/// A flip card: the kanji with its main readings on the front, every reading
/// with its example words on the back.
class KanjiCard extends StatelessWidget {
  const KanjiCard({
    required this.kanji,
    required this.language,
    required this.visibility,
    required this.onVisibilityChanged,
    required this.onSpeakReading,
    required this.onSpeakSentence,
    required this.onFlip,
    required this.footer,
    this.bottomInset = 0,
    super.key,
  });

  final Kanji kanji;
  final String language;
  final KanjiVisibility visibility;
  final ValueChanged<KanjiVisibility> onVisibilityChanged;

  /// Called with the dictionary form of the reading that was tapped.
  final ValueChanged<String> onSpeakReading;

  /// Shown at the foot of both faces, just above the hide group.
  final Widget footer;

  /// Room at the foot of the back's scrolling content for the [footer].
  static const _footerClearance = 72.0;

  /// Space kept clear at the foot of both faces for controls drawn over the
  /// card, so the hide group sits just above them.
  final double bottomInset;

  /// Called with the example sentence that was tapped.
  final ValueChanged<String> onSpeakSentence;

  /// Called as soon as a flip starts, with whether the back is being shown, so
  /// audio can stop.
  final ValueChanged<bool> onFlip;

  @override
  Widget build(BuildContext context) => FlipCardPlus(
    duration: const Duration(milliseconds: 350),
    onFlipStart: (_, to) => onFlip(to == CardSide.back),
    front: _Face(
      key: const ValueKey('kanji-front'),
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset),
      child: _buildFront(context),
    ),
    back: _Face(
      key: const ValueKey('kanji-back'),
      // No side or top padding: the scroll view inside pads its own content,
      // so a drag that starts anywhere on the card scrolls it.
      padding: EdgeInsets.only(bottom: bottomInset),
      child: _buildBack(context),
    ),
  );

  Widget _buildFront(BuildContext context) {
    final strings = context.strings;
    return Column(
      children: [
        Expanded(
          // Scales down rather than scrolling, so every front reading stays in
          // view on short screens.
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildKanji(context, fontSize: 132),
                  if (kanji.frontKunYomi.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    _ReadingGroup(
                      label: strings('kunYomi'),
                      readings: kanji.frontKunYomi,
                      hidden: visibility.hideKunYomi,
                      onSpeak: onSpeakReading,
                    ),
                  ],
                  if (kanji.frontOnYomi.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _ReadingGroup(
                      label: strings('onYomi'),
                      readings: kanji.frontOnYomi,
                      hidden: visibility.hideOnYomi,
                      onSpeak: onSpeakReading,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        footer,
        _HideGroup(
          side: 'front',
          toggles: [
            _HideToggle(
              id: 'kanji',
              hidden: visibility.hideKanji,
              hideLabel: strings('hideKanji'),
              showLabel: strings('showKanji'),
              onTap: () => onVisibilityChanged(
                visibility.copyWith(hideKanji: !visibility.hideKanji),
              ),
            ),
            _HideToggle(
              id: 'kun',
              hidden: visibility.hideKunYomi,
              hideLabel: strings('hideKunYomi'),
              showLabel: strings('showKunYomi'),
              onTap: () => onVisibilityChanged(
                visibility.copyWith(hideKunYomi: !visibility.hideKunYomi),
              ),
            ),
            _HideToggle(
              id: 'on',
              hidden: visibility.hideOnYomi,
              hideLabel: strings('hideOnYomi'),
              showLabel: strings('showOnYomi'),
              onTap: () => onVisibilityChanged(
                visibility.copyWith(hideOnYomi: !visibility.hideOnYomi),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBack(BuildContext context) {
    final strings = context.strings;
    const sideInset = EdgeInsets.symmetric(horizontal: 16);
    return Column(
      children: [
        // The scroll view runs down to the hide group; the footer floats over
        // its lower edge, which the extra bottom padding keeps clear of text.
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    12 + _footerClearance,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: _buildKanji(context, fontSize: 56, reveal: true),
                      ),
                      if (kanji.kunYomi.isNotEmpty ||
                          kanji.kunExamples.isNotEmpty)
                        _ReadingSection(
                          label: strings('kunYomi'),
                          readings: kanji.kunYomi,
                          examples: kanji.kunExamples,
                          language: language,
                          hideReadings: visibility.hideKunYomi,
                          hideMeanings: visibility.hideMeanings,
                          onSpeak: onSpeakReading,
                          onSpeakSentence: onSpeakSentence,
                        ),
                      if ((kanji.kunYomi.isNotEmpty ||
                              kanji.kunExamples.isNotEmpty) &&
                          (kanji.onYomi.isNotEmpty ||
                              kanji.onExamples.isNotEmpty))
                        Padding(
                          padding: const EdgeInsets.only(top: 22),
                          child: _DashedDivider(
                            key: const ValueKey('kun-on-divider'),
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      if (kanji.onYomi.isNotEmpty ||
                          kanji.onExamples.isNotEmpty)
                        _ReadingSection(
                          label: strings('onYomi'),
                          readings: kanji.onYomi,
                          examples: kanji.onExamples,
                          language: language,
                          hideReadings: visibility.hideOnYomi,
                          hideMeanings: visibility.hideMeanings,
                          onSpeak: onSpeakReading,
                          onSpeakSentence: onSpeakSentence,
                        ),
                    ],
                  ),
                ),
              ),
              Positioned(left: 16, right: 16, bottom: 0, child: footer),
            ],
          ),
        ),
        Padding(
          padding: sideInset,
          child: _HideGroup(
            side: 'back',
            toggles: [
              _HideToggle(
                id: 'kun',
                hidden: visibility.hideKunYomi,
                hideLabel: strings('hideKunYomi'),
                showLabel: strings('showKunYomi'),
                onTap: () => onVisibilityChanged(
                  visibility.copyWith(hideKunYomi: !visibility.hideKunYomi),
                ),
              ),
              _HideToggle(
                id: 'on',
                hidden: visibility.hideOnYomi,
                hideLabel: strings('hideOnYomi'),
                showLabel: strings('showOnYomi'),
                onTap: () => onVisibilityChanged(
                  visibility.copyWith(hideOnYomi: !visibility.hideOnYomi),
                ),
              ),
              _HideToggle(
                id: 'meanings',
                hidden: visibility.hideMeanings,
                hideLabel: strings('hideMeanings'),
                showLabel: strings('showMeanings'),
                onTap: () => onVisibilityChanged(
                  visibility.copyWith(hideMeanings: !visibility.hideMeanings),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The back is the answer side, so [reveal] shows the kanji even when it was
  /// covered on the front.
  Widget _buildKanji(
    BuildContext context, {
    required double fontSize,
    bool reveal = false,
  }) {
    if (visibility.hideKanji && !reveal) {
      return coverTapeFor(
        characters: 1,
        fontSize: fontSize,
        maxWidth: fontSize * 1.3,
        glyphWidth: 0.9,
        tilt: -0.02,
      );
    }
    return Text(
      kanji.character,
      style: TextStyle(
        fontSize: fontSize,
        height: 1.1,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({required this.child, required this.padding, super.key});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor),
    child: SizedBox.expand(
      child: Padding(padding: padding, child: child),
    ),
  );
}

/// A caption above a wrap of tappable readings.
class _ReadingGroup extends StatelessWidget {
  const _ReadingGroup({
    required this.label,
    required this.readings,
    required this.hidden,
    required this.onSpeak,
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
      const SizedBox(height: 6),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final reading in readings)
            _ReadingChip(
              reading: reading,
              hidden: hidden,
              color: Theme.of(context).colorScheme.primary,
              onTap: () => onSpeak(reading),
            ),
        ],
      ),
    ],
  );
}

/// A reading that speaks itself when tapped. Covered readings can still be
/// tapped, so the learner can check a recalled reading by ear.
class _ReadingChip extends StatelessWidget {
  const _ReadingChip({
    required this.reading,
    required this.hidden,
    required this.onTap,
    this.color,
  });

  final String reading;
  final bool hidden;
  final VoidCallback onTap;

  /// The text color; the surface text color when null.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final style = Theme.of(
      context,
    ).textTheme.titleLarge?.copyWith(color: color ?? colors.onSurface);
    return Semantics(
      button: true,
      child: Material(
        key: ValueKey('reading-$reading'),
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          splashFactory: NoSplash.splashFactory,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: hidden
                ? coverTapeFor(
                    characters: reading.length,
                    fontSize: style?.fontSize ?? 22,
                    maxWidth: 120,
                    glyphWidth: 0.9,
                  )
                : Text(reading, style: style),
          ),
        ),
      ),
    );
  }
}

/// One reading type on the back: its readings, then an example for each.
class _ReadingSection extends StatelessWidget {
  const _ReadingSection({
    required this.label,
    required this.readings,
    required this.examples,
    required this.language,
    required this.hideReadings,
    required this.hideMeanings,
    required this.onSpeak,
    required this.onSpeakSentence,
  });

  final String label;
  final List<String> readings;
  final List<KanjiExample> examples;
  final String language;
  final bool hideReadings;
  final bool hideMeanings;
  final ValueChanged<String> onSpeak;
  final ValueChanged<String> onSpeakSentence;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final reading in readings)
              _ReadingChip(
                reading: reading,
                hidden: hideReadings,
                onTap: () => onSpeak(reading),
              ),
          ],
        ),
        for (final example in examples)
          _ExampleTile(
            example: example,
            language: language,
            hideReadings: hideReadings,
            hideMeanings: hideMeanings,
            onSpeakSentence: onSpeakSentence,
          ),
      ],
    ),
  );
}

class _ExampleTile extends StatelessWidget {
  const _ExampleTile({
    required this.example,
    required this.language,
    required this.hideReadings,
    required this.hideMeanings,
    required this.onSpeakSentence,
  });

  final KanjiExample example;
  final String language;
  final bool hideReadings;
  final bool hideMeanings;
  final ValueChanged<String> onSpeakSentence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = TextStyle(color: theme.colorScheme.onSurfaceVariant);
    final translation = example.sentenceTranslation(language);
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            children: [
              Text(
                example.word,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (example.reading.isNotEmpty)
                hideReadings
                    ? coverTapeFor(
                        characters: example.reading.length,
                        fontSize: 16,
                        maxWidth: 110,
                        glyphWidth: 0.9,
                      )
                    : Text(
                        example.reading,
                        style: TextStyle(color: theme.colorScheme.primary),
                      ),
            ],
          ),
          const SizedBox(height: 2),
          _maybeCovered(
            example.meaning(language),
            style: theme.textTheme.bodyLarge,
            fontSize: 16,
          ),
          if (example.sentence.isNotEmpty) ...[
            const SizedBox(height: 6),
            Semantics(
              button: true,
              child: InkWell(
                key: ValueKey('sentence-${example.word}'),
                borderRadius: BorderRadius.circular(8),
                splashFactory: NoSplash.splashFactory,
                onTap: () => onSpeakSentence(example.sentence),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: _FuriganaText(
                    segments: example.sentenceSegments,
                    style: theme.textTheme.bodyMedium ?? const TextStyle(),
                    hideFurigana: hideReadings,
                  ),
                ),
              ),
            ),
            if (translation.isNotEmpty)
              _maybeCovered(translation, style: muted, fontSize: 14),
          ],
        ],
      ),
    );
  }

  /// [text] as-is, or tape the width of the text while meanings are hidden.
  Widget _maybeCovered(
    String text, {
    required TextStyle? style,
    required double fontSize,
  }) {
    if (text.isEmpty) return const SizedBox.shrink();
    if (!hideMeanings) return Text(text, style: style);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: coverTapeFor(
        characters: text.length,
        fontSize: fontSize,
        maxWidth: 220,
        glyphWidth: 0.7,
        tilt: 0.015,
      ),
    );
  }
}

/// The row of hide/show toggles at the foot of a card face.
class _HideGroup extends StatelessWidget {
  const _HideGroup({required this.side, required this.toggles});

  final String side;
  final List<_HideToggle> toggles;

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('hide-group-$side'),
    child: Row(
      children: [
        for (final toggle in toggles)
          Expanded(
            child: KeyedSubtree(
              key: ValueKey('hide-$side-${toggle.id}'),
              child: toggle,
            ),
          ),
      ],
    ),
  );
}

class _HideToggle extends StatelessWidget {
  const _HideToggle({
    required this.id,
    required this.hidden,
    required this.hideLabel,
    required this.showLabel,
    required this.onTap,
  });

  final String id;
  final bool hidden;
  final String hideLabel;
  final String showLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(20),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hidden ? Icons.visibility_rounded : Icons.visibility_off_rounded,
          ),
          const SizedBox(height: 4),
          Text(
            hidden ? showLabel : hideLabel,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    ),
  );
}

/// A sentence with each kanji word's reading printed above it.
///
/// Flutter has no ruby layout, so every segment is a small column and the
/// segments wrap like words. Segments without a reading keep a blank line of
/// the same height, which keeps the text on one baseline. With
/// [hideFurigana] the readings keep their space but are not drawn.
class _FuriganaText extends StatelessWidget {
  const _FuriganaText({
    required this.segments,
    required this.style,
    required this.hideFurigana,
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

/// A horizontal line drawn as evenly spaced dashes.
class _DashedDivider extends StatelessWidget {
  const _DashedDivider({required this.color, super.key});

  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(double.infinity, 1),
    painter: _DashedLinePainter(color),
  );
}

class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter(this.color);

  final Color color;

  static const _dash = 6.0;
  static const _gap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += _dash + _gap) {
      canvas.drawLine(
        Offset(x, 0),
        Offset((x + _dash).clamp(0, size.width), 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) => old.color != color;
}
