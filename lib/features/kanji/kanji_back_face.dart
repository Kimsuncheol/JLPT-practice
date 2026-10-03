import 'package:flutter/material.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/data/models/kanji.dart';
import 'package:jlpt_practice/features/kanji/kanji_visibility.dart';
import 'package:jlpt_practice/features/kanji/widgets/hide_group.dart';
import 'package:jlpt_practice/features/kanji/widgets/kanji_footer.dart';
import 'package:jlpt_practice/features/kanji/widgets/dashed_divider.dart';
import 'package:jlpt_practice/features/kanji/widgets/reading_section.dart';
import 'package:jlpt_practice/core/constants/app_sizes.dart';

/// The back: every reading with its examples, in a scroll view that runs down to the hide group. The kanji itself is not repeated here.
class KanjiBackFace extends StatelessWidget {
  const KanjiBackFace({
    required this.kanji,
    required this.language,
    required this.visibility,
    required this.onVisibilityChanged,
    required this.onSpeakReading,
    required this.onSpeakSentence,
    required this.footer,
    super.key,
  });

  final Kanji kanji;
  final String language;
  final KanjiVisibility visibility;
  final ValueChanged<KanjiVisibility> onVisibilityChanged;
  final ValueChanged<String> onSpeakReading;
  final ValueChanged<String> onSpeakSentence;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    const sideInset = EdgeInsets.symmetric(horizontal: AppSizes.size16);
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
                    AppSizes.size16,
                    AppSizes.size16,
                    AppSizes.size16,
                    AppSizes.size12 + KanjiFooter.height,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (kanji.kunYomi.isNotEmpty ||
                          kanji.kunExamples.isNotEmpty)
                        ReadingSection(
                          label: strings('kunYomi'),
                          topPadding: 0,
                          readings: kanji.kunYomi,
                          examples: kanji.kunExamples,
                          language: language,
                          hideReadings: visibility.hideKunYomi,
                          hideFurigana: visibility.hideFurigana,
                          hideMeanings: visibility.hideMeanings,
                          onSpeak: onSpeakReading,
                          onSpeakSentence: onSpeakSentence,
                        ),
                      if ((kanji.kunYomi.isNotEmpty ||
                              kanji.kunExamples.isNotEmpty) &&
                          (kanji.onYomi.isNotEmpty ||
                              kanji.onExamples.isNotEmpty))
                        Padding(
                          padding: const EdgeInsets.only(top: AppSizes.size22),
                          child: DashedDivider(
                            key: const ValueKey('kun-on-divider'),
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      if (kanji.onYomi.isNotEmpty ||
                          kanji.onExamples.isNotEmpty)
                        ReadingSection(
                          label: strings('onYomi'),
                          topPadding:
                              kanji.kunYomi.isEmpty && kanji.kunExamples.isEmpty
                              ? 0
                              : 18,
                          readings: kanji.onYomi,
                          examples: kanji.onExamples,
                          language: language,
                          hideReadings: visibility.hideOnYomi,
                          hideFurigana: visibility.hideFurigana,
                          hideMeanings: visibility.hideMeanings,
                          onSpeak: onSpeakReading,
                          onSpeakSentence: onSpeakSentence,
                        ),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: AppSizes.size16,
                right: AppSizes.size16,
                bottom: AppSizes.size0,
                child: footer,
              ),
            ],
          ),
        ),
        Padding(
          padding: sideInset,
          child: HideGroup(
            side: 'back',
            toggles: [
              HideToggle(
                id: 'kun',
                hidden: visibility.hideKunYomi,
                hideLabel: strings('hideKunYomi'),
                showLabel: strings('showKunYomi'),
                onTap: () => onVisibilityChanged(
                  visibility.copyWith(hideKunYomi: !visibility.hideKunYomi),
                ),
              ),
              HideToggle(
                id: 'on',
                hidden: visibility.hideOnYomi,
                hideLabel: strings('hideOnYomi'),
                showLabel: strings('showOnYomi'),
                onTap: () => onVisibilityChanged(
                  visibility.copyWith(hideOnYomi: !visibility.hideOnYomi),
                ),
              ),
              HideToggle(
                id: 'furigana',
                hidden: visibility.hideFurigana,
                hideLabel: strings('hideReading'),
                showLabel: strings('showReading'),
                onTap: () => onVisibilityChanged(
                  visibility.copyWith(hideFurigana: !visibility.hideFurigana),
                ),
              ),
              HideToggle(
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
}
