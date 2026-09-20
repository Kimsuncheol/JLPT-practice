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
