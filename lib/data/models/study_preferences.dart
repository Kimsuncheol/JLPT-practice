/// Which parts of a word's meaning the "Hide meanings" cover masks.
enum MeaningCoverMode {
  /// The meaning and the example translation are both covered.
  meaningAndTranslation,

  /// The meaning is covered, and so is its wording inside the translation.
  meaning,

  /// Only the example translation is covered.
  translation;

  static MeaningCoverMode parse(String? name) => values.firstWhere(
    (mode) => mode.name == name,
    orElse: () => MeaningCoverMode.meaningAndTranslation,
  );
}

/// Where the volume of spoken pronunciation comes from.
enum TtsVolumeMode {
  /// Follow whatever the operating system's media volume currently is.
  system,

  /// Use the app's own level, whatever the system volume is set to.
  slider;

  static TtsVolumeMode parse(String? name) => values.firstWhere(
    (mode) => mode.name == name,
    orElse: () => TtsVolumeMode.system,
  );
}

/// The three parts of a word card that auto review reveals one at a time.
enum ReviewElement { word, meanings, reading }

/// The order auto review reveals a card's [ReviewElement]s in. The first
/// element is shown on its own; each later step adds the next one.
class AutoReviewOrder {
  const AutoReviewOrder(this.elements);

  final List<ReviewElement> elements;

  /// Stable identifier used for persistence, e.g. `word-meanings-reading`.
  String get id => elements.map((element) => element.name).join('-');

  /// Every ordered combination of the elements (3! = 6), first option being
  /// word -> meanings -> reading.
  static final List<AutoReviewOrder> all = List.unmodifiable(
    _permutations(
      ReviewElement.values,
    ).map((elements) => AutoReviewOrder(elements)),
  );

  static const defaultOrder = AutoReviewOrder([
    ReviewElement.word,
    ReviewElement.meanings,
    ReviewElement.reading,
  ]);

  static AutoReviewOrder parse(String? id) =>
      all.firstWhere((order) => order.id == id, orElse: () => defaultOrder);

  static List<List<ReviewElement>> _permutations(List<ReviewElement> items) {
    if (items.length <= 1) return [items];
    return [
      for (var i = 0; i < items.length; i++)
        for (final rest in _permutations([
          ...items.sublist(0, i),
          ...items.sublist(i + 1),
        ]))
          [items[i], ...rest],
    ];
  }

  @override
  bool operator ==(Object other) => other is AutoReviewOrder && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Seconds auto review waits on each step, offered in the settings screen.
const autoReviewSecondsOptions = [2, 3, 5, 8];
