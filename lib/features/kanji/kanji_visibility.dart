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
