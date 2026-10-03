import 'package:flutter/material.dart';
import 'package:jlpt_practice/data/models/kanji.dart';
import 'package:jlpt_practice/features/kanji/widgets/reading_chip.dart';
import 'package:jlpt_practice/features/vocabulary/cover_tape.dart';
import 'package:jlpt_practice/features/vocabulary/example_furigana_text.dart';
import 'package:jlpt_practice/core/constants/app_sizes.dart';
import 'package:jlpt_practice/core/constants/app_font_weights.dart';
import 'package:jlpt_practice/core/constants/app_spacing.dart';

/// One reading type on the back: its readings, then an example for each.
class ReadingSection extends StatelessWidget {
  const ReadingSection({
    required this.label,
    required this.readings,
    required this.examples,
    required this.language,
    required this.hideReadings,
    required this.hideFurigana,
    required this.hideMeanings,
    required this.onSpeak,
    required this.onSpeakSentence,
    this.topPadding = 18,
    this.exampleFontScale = 1,
    super.key,
  });

  /// Space above the label; zero when the section opens the face.
  final double topPadding;
  final String label;
  final List<String> readings;
  final List<KanjiExample> examples;
  final String language;
  final bool hideReadings;
  final bool hideFurigana;
  final bool hideMeanings;
  final ValueChanged<String> onSpeak;
  final ValueChanged<String> onSpeakSentence;
  final double exampleFontScale;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(top: topPadding),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSizes.space8),
        Wrap(
          spacing: AppSpacing.item8,
          runSpacing: AppSpacing.run8,
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
            hideFurigana: hideFurigana,
            hideMeanings: hideMeanings,
            onSpeakSentence: onSpeakSentence,
            fontScale: exampleFontScale,
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
    required this.hideFurigana,
    required this.hideMeanings,
    required this.onSpeakSentence,
    this.fontScale = 1,
    super.key,
  });

  final KanjiExample example;
  final String language;
  final bool hideReadings;

  /// Covers the furigana of the sentence only.
  final bool hideFurigana;
  final bool hideMeanings;
  final ValueChanged<String> onSpeakSentence;
  final double fontScale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = TextStyle(color: theme.colorScheme.onSurfaceVariant);
    final translation = example.sentenceTranslation(language);
    return Padding(
      padding: const EdgeInsets.only(top: AppSizes.size14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The reading is stacked above the word, with no brackets around it.
          if (example.reading.isNotEmpty)
            hideReadings
                ? coverTapeFor(
                    characters: example.reading.length,
                    fontSize: AppSizes.font12,
                    maxWidth: AppSizes.size110,
                    glyphWidth: 0.9,
                  )
                : Text(
                    example.reading,
                    style: TextStyle(
                      fontSize: AppSizes.font12,
                      height: AppSizes.lineHeight1_2,
                      color: theme.colorScheme.primary,
                    ),
                  ),
          Text(
            example.word,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: AppFontWeights.extraBold,
            ),
          ),
          const SizedBox(height: AppSizes.space2),
          _maybeCovered(
            example.meaning(language),
            style: theme.textTheme.bodyLarge,
            fontSize: AppSizes.font16,
          ),
          if (example.sentence.isNotEmpty) ...[
            const SizedBox(height: AppSizes.space6),
            Semantics(
              button: true,
              child: InkWell(
                key: ValueKey('sentence-${example.word}'),
                borderRadius: BorderRadius.circular(AppSizes.radius8),
                splashFactory: NoSplash.splashFactory,
                onTap: () => onSpeakSentence(example.sentence),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSizes.size2),
                  child: ExampleFuriganaText(
                    segments: example.sentenceSegments,
                    style:
                        theme.textTheme.titleMedium?.copyWith(height: 1.2) ??
                        const TextStyle(fontSize: AppSizes.font18),
                    wordTargets: const [],
                    hideReadings: hideFurigana,
                    runSpacingWithFurigana: AppSizes.space6,
                    fontScale: fontScale,
                    alignment: WrapAlignment.start,
                  ),
                ),
              ),
            ),
            if (translation.isNotEmpty)
              _maybeCovered(
                translation,
                style: muted,
                fontSize: AppSizes.font14,
              ),
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
      padding: const EdgeInsets.symmetric(vertical: AppSizes.size2),
      child: coverTapeFor(
        characters: text.length,
        fontSize: fontSize,
        maxWidth: AppSizes.size220,
        glyphWidth: 0.7,
        tilt: 0.015,
      ),
    );
  }
}
