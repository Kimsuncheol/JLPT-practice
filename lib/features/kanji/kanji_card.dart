import 'package:flip_card_plus/flip_card_plus.dart';
import 'package:flutter/material.dart';
import 'package:jlpt_practice/data/models/kanji.dart';
import 'package:jlpt_practice/features/kanji/kanji_back_face.dart';
import 'package:jlpt_practice/features/kanji/kanji_card_face.dart';
import 'package:jlpt_practice/features/kanji/kanji_front_face.dart';
import 'package:jlpt_practice/features/kanji/kanji_visibility.dart';

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
    front: KanjiFace(
      key: const ValueKey('kanji-front'),
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset),
      child: KanjiFrontFace(
        kanji: kanji,
        visibility: visibility,
        onVisibilityChanged: onVisibilityChanged,
        onSpeakReading: onSpeakReading,
        footer: footer,
      ),
    ),
    back: KanjiFace(
      key: const ValueKey('kanji-back'),
      // No side or top padding: the scroll view inside pads its own content,
      // so a drag that starts anywhere on the card scrolls it.
      padding: EdgeInsets.only(bottom: bottomInset),
      child: KanjiBackFace(
        kanji: kanji,
        language: language,
        visibility: visibility,
        onVisibilityChanged: onVisibilityChanged,
        onSpeakReading: onSpeakReading,
        onSpeakSentence: onSpeakSentence,
        footer: footer,
      ),
    ),
  );
}
