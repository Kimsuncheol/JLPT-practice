import 'package:flutter/material.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/data/models/kanji.dart';
import 'package:jlpt_practice/features/kanji/kanji_visibility.dart';
import 'package:jlpt_practice/features/kanji/widgets/hide_group.dart';
import 'package:jlpt_practice/features/kanji/widgets/hun_eum_line.dart';
import 'package:jlpt_practice/features/kanji/widgets/kanji_glyph.dart';
import 'package:jlpt_practice/features/kanji/widgets/reading_chip.dart';
import 'package:jlpt_practice/core/constants/app_sizes.dart';

/// The front: the kanji with all kun and the first two on readings.
class KanjiFrontFace extends StatelessWidget {
  const KanjiFrontFace({
    required this.kanji,
    required this.visibility,
    required this.onVisibilityChanged,
    required this.onSpeakReading,
    required this.footer,
    this.onStartOver,
    super.key,
  });

  final Kanji kanji;
  final KanjiVisibility visibility;
  final ValueChanged<KanjiVisibility> onVisibilityChanged;
  final ValueChanged<String> onSpeakReading;
  final Widget footer;

  /// Shown as the hide group's last item when set: restarts the day.
  final VoidCallback? onStartOver;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return Column(
      children: [
        Expanded(
          // Scales down rather than scrolling, so every front reading stays in
          // view on short screens.
          child: LayoutBuilder(
            builder: (context, constraints) => Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  // Give the reading wraps a finite width before scaling the
                  // complete content to fit the available height.
                  width: constraints.maxWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      KanjiGlyph(
                        character: kanji.character,
                        fontSize: AppSizes.font132,
                        hidden: visibility.hideKanji,
                      ),
                      if (kanji.frontKunYomi.isNotEmpty ||
                          kanji.uniqueHun.isNotEmpty) ...[
                        const SizedBox(height: AppSizes.space60),
                        if (kanji.frontKunYomi.isEmpty)
                          HunEumLine(
                            values: kanji.uniqueHun,
                            hidden: visibility.hideHun,
                          )
                        else
                          ReadingGroup(
                            label: strings('kunYomi'),
                            readings: kanji.frontKunYomi,
                            hidden: visibility.hideKunYomi,
                            onSpeak: onSpeakReading,
                            extra: kanji.uniqueHun.isEmpty
                                ? null
                                : HunEumLine(
                                    values: kanji.uniqueHun,
                                    hidden: visibility.hideHun,
                                  ),
                          ),
                      ],
                      if (kanji.frontOnYomi.isNotEmpty ||
                          kanji.uniqueEum.isNotEmpty) ...[
                        const SizedBox(height: AppSizes.space44),
                        if (kanji.frontOnYomi.isEmpty)
                          HunEumLine(
                            values: kanji.uniqueEum,
                            hidden: visibility.hideEum,
                          )
                        else
                          ReadingGroup(
                            label: strings('onYomi'),
                            readings: kanji.frontOnYomi,
                            hidden: visibility.hideOnYomi,
                            onSpeak: onSpeakReading,
                            extra: kanji.uniqueEum.isEmpty
                                ? null
                                : HunEumLine(
                                    values: kanji.uniqueEum,
                                    hidden: visibility.hideEum,
                                  ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        footer,
        HideGroup(
          side: 'front',
          trailing: onStartOver == null
              ? null
              : HideGroupAction(
                  icon: Icons.refresh_rounded,
                  label: strings('startOver'),
                  onTap: onStartOver!,
                ),
          morePages: [
            [
              HideToggle(
                id: 'hun',
                hidden: visibility.hideHun,
                hideLabel: strings('hideHun'),
                showLabel: strings('showHun'),
                onTap: () => onVisibilityChanged(
                  visibility.copyWith(hideHun: !visibility.hideHun),
                ),
              ),
              HideToggle(
                id: 'eum',
                hidden: visibility.hideEum,
                hideLabel: strings('hideEum'),
                showLabel: strings('showEum'),
                onTap: () => onVisibilityChanged(
                  visibility.copyWith(hideEum: !visibility.hideEum),
                ),
              ),
            ],
          ],
          toggles: [
            HideToggle(
              id: 'kanji',
              hidden: visibility.hideKanji,
              hideLabel: strings('hideKanji'),
              showLabel: strings('showKanji'),
              onTap: () => onVisibilityChanged(
                visibility.copyWith(hideKanji: !visibility.hideKanji),
              ),
            ),
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
          ],
        ),
      ],
    );
  }
}
