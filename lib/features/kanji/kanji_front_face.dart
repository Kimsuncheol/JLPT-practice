import 'package:flutter/material.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/data/models/kanji.dart';
import 'package:jlpt_practice/features/kanji/kanji_visibility.dart';
import 'package:jlpt_practice/features/kanji/widgets/hide_group.dart';
import 'package:jlpt_practice/features/kanji/widgets/kanji_glyph.dart';
import 'package:jlpt_practice/features/kanji/widgets/reading_chip.dart';

/// The front: the kanji with its first kun and first two on readings.
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
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  KanjiGlyph(
                    character: kanji.character,
                    fontSize: 132,
                    hidden: visibility.hideKanji,
                  ),
                  if (kanji.frontKunYomi.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    ReadingGroup(
                      label: strings('kunYomi'),
                      readings: kanji.frontKunYomi,
                      hidden: visibility.hideKunYomi,
                      onSpeak: onSpeakReading,
                    ),
                  ],
                  if (kanji.frontOnYomi.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    ReadingGroup(
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
        HideGroup(
          side: 'front',
          trailing: onStartOver == null
              ? null
              : HideGroupAction(
                  icon: Icons.refresh_rounded,
                  label: strings('startOver'),
                  onTap: onStartOver!,
                ),
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
