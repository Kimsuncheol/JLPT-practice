import 'package:flutter/material.dart';
import 'package:jlpt_practice/data/models/kanji.dart';
import 'package:jlpt_practice/features/kanji/widgets/furigana_text.dart';
import 'package:jlpt_practice/features/kanji/widgets/reading_chip.dart';
import 'package:jlpt_practice/features/vocabulary/cover_tape.dart';

/// One reading type on the back: its readings, then an example for each.
class ReadingSection extends StatelessWidget {
  const ReadingSection({
    required this.label,
    required this.readings,
    required this.examples,
    required this.language,
    required this.hideReadings,
    required this.hideMeanings,
    required this.onSpeak,
    required this.onSpeakSentence,
    super.key,
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
              ReadingChip(
                reading: reading,
                hidden: hideReadings,
                onTap: () => onSpeak(reading),
              ),
          ],
        ),
        for (final example in examples)
          ExampleTile(
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

class ExampleTile extends StatelessWidget {
  const ExampleTile({
    required this.example,
    required this.language,
    required this.hideReadings,
    required this.hideMeanings,
    required this.onSpeakSentence,
    super.key,
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
                  child: FuriganaText(
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
