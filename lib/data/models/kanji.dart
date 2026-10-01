/// A run of a sentence, with the reading to print above it when it has one.
class FuriganaSegment {
  const FuriganaSegment(this.text, [this.ruby]);

  final String text;
  final String? ruby;

  @override
  bool operator ==(Object other) =>
      other is FuriganaSegment && other.text == text && other.ruby == ruby;

  @override
  int get hashCode => Object.hash(text, ruby);
}

final _furiganaMarkup = RegExp(r'\{([^|}]+)\|([^}]+)\}');

/// Splits sentence text marked up as `りんごを{一|ひと}つください。`, where
/// `{base|reading}` is a word written with kanji, into segments.
List<FuriganaSegment> parseFurigana(String marked) {
  final segments = <FuriganaSegment>[];
  var cursor = 0;
  for (final match in _furiganaMarkup.allMatches(marked)) {
    if (match.start > cursor) {
      segments.add(FuriganaSegment(marked.substring(cursor, match.start)));
    }
    segments.add(FuriganaSegment(match.group(1)!, match.group(2)));
    cursor = match.end;
  }
  if (cursor < marked.length) {
    segments.add(FuriganaSegment(marked.substring(cursor)));
  }
  return segments;
}

/// A word that demonstrates one reading of a kanji.
class KanjiExample {
  const KanjiExample({
    required this.word,
    required this.reading,
    required this.meanings,
    required this.sentence,
    required this.sentenceTranslations,
    this.sentenceFurigana = '',
  });

  factory KanjiExample.fromJson(Map<String, dynamic> json) => KanjiExample(
    word: json['word'] as String? ?? '',
    reading: json['reading'] as String? ?? '',
    meanings: {
      for (final language in const ['ko', 'en'])
        if ((json['meaning_$language'] as String?)?.isNotEmpty ?? false)
          language: json['meaning_$language'] as String,
    },
    sentence: json['sentence_jp'] as String? ?? '',
    sentenceFurigana: json['sentence_furigana'] as String? ?? '',
    sentenceTranslations: {
      for (final language in const ['ko'])
        if ((json['sentence_$language'] as String?)?.isNotEmpty ?? false)
          language: json['sentence_$language'] as String,
    },
  );

  final String word;
  final String reading;
  final Map<String, String> meanings;
  final String sentence;

  /// [sentence] marked up for [parseFurigana]; empty when no readings exist.
  final String sentenceFurigana;
  final Map<String, String> sentenceTranslations;

  /// The sentence in segments; without readings it is a single plain one.
  List<FuriganaSegment> get sentenceSegments => sentenceFurigana.isEmpty
      ? [FuriganaSegment(sentence)]
      : parseFurigana(sentenceFurigana);

  /// [sentence] written in kana only, read from [sentenceFurigana]; empty when
  /// there are no readings or the sentence has no kanji to read.
  String get sentenceReading {
    if (sentenceFurigana.isEmpty) return '';
    final reading = sentenceSegments
        .map((segment) => segment.ruby ?? segment.text)
        .join();
    return reading == sentence ? '' : reading;
  }

  String meaning(String language) => meanings[language] ?? meanings['en'] ?? '';

  String sentenceTranslation(String language) =>
      sentenceTranslations[language] ?? '';
}

class Kanji {
  const Kanji({
    required this.character,
    required this.jlptLevel,
    required this.hunEum,
    required this.strokes,
    required this.kunYomi,
    required this.onYomi,
    required this.kunExamples,
    required this.onExamples,
  });

  factory Kanji.fromJson(Map<String, dynamic> json) => Kanji(
    character: json['kanji'] as String,
    jlptLevel: json['jlpt'] as String,
    hunEum: _strings(json['hun_eum']),
    strokes: json['strokes'] as int? ?? 0,
    kunYomi: _strings(json['kun_yomi']),
    onYomi: _strings(json['on_yomi']),
    kunExamples: _examples(json['kun_examples']),
    onExamples: _examples(json['on_examples']),
  );

  final String character;
  final String jlptLevel;
  final List<String> hunEum;
  final int strokes;
  final List<String> kunYomi;
  final List<String> onYomi;
  final List<KanjiExample> kunExamples;
  final List<KanjiExample> onExamples;

  /// One kanji appears once per level, so the character identifies it.
  String get id => '$jlptLevel-$character';

  /// The readings shown on the front of the card: the first kun'yomi and the
  /// first two on'yomi.
  List<String> get frontKunYomi => kunYomi.take(1).toList(growable: false);
  List<String> get frontOnYomi => onYomi.take(2).toList(growable: false);

  static List<String> _strings(Object? value) =>
      (value as List<dynamic>? ?? const []).whereType<String>().toList(
        growable: false,
      );

  static List<KanjiExample> _examples(Object? value) =>
      (value as List<dynamic>? ?? const [])
          .map((item) => KanjiExample.fromJson(item as Map<String, dynamic>))
          .toList(growable: false);
}

/// The text to hand to text-to-speech for a dictionary-style reading.
///
/// Dictionaries mark okurigana with `.` (`ひと.つ`) and affixes with `-`
/// (`ひと-`); neither is part of the pronunciation.
String kanjiReadingForSpeech(String reading) =>
    reading.replaceAll(RegExp(r'[.\-]'), '');
