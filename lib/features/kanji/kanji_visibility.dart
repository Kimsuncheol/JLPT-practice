/// What the learner has covered on one kanji card. Both faces share it, so a
/// reading hidden on the front stays hidden on the back.
class KanjiVisibility {
  const KanjiVisibility({
    required this.hideKanji,
    required this.hideKunYomi,
    required this.hideOnYomi,
    required this.hideFurigana,
    required this.hideMeanings,
  });

  final bool hideKanji;
  final bool hideKunYomi;
  final bool hideOnYomi;

  /// The furigana of the examples on the back; the readings stay as they are.
  final bool hideFurigana;
  final bool hideMeanings;

  KanjiVisibility copyWith({
    bool? hideKanji,
    bool? hideKunYomi,
    bool? hideOnYomi,
    bool? hideFurigana,
    bool? hideMeanings,
  }) => KanjiVisibility(
    hideKanji: hideKanji ?? this.hideKanji,
    hideKunYomi: hideKunYomi ?? this.hideKunYomi,
    hideOnYomi: hideOnYomi ?? this.hideOnYomi,
    hideFurigana: hideFurigana ?? this.hideFurigana,
    hideMeanings: hideMeanings ?? this.hideMeanings,
  );
}
