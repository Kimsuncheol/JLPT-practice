class VocabularyExample {
  const VocabularyExample({
    required this.sentence,
    required this.reading,
    required this.translations,
    required this.quizSentence,
    required this.answer,
  });

  factory VocabularyExample.fromJson(Map<String, dynamic> json) {
    return VocabularyExample(
      sentence: json['sentence'] as String,
      reading: json['reading'] as String? ?? '',
      translations: Map<String, String>.from(
        json['translations'] as Map<String, dynamic>,
      ),
      quizSentence: json['quizSentence'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
    );
  }

  final String sentence;
  final String reading;
  final Map<String, String> translations;
  final String quizSentence;
  final String answer;

  String translation(String language) =>
      translations[language] ?? translations['en'] ?? '';

  bool get hasRolePlay {
    final turns = _parseRolePlayTurns(sentence);
    return turns.map((turn) => turn.speaker).toSet().length >= 2 &&
        quizSentence.isNotEmpty &&
        answer.isNotEmpty;
  }

  List<VocabularyRolePlayTurn> get rolePlayTurns =>
      _parseRolePlayTurns(quizSentence);

  String get completedQuizSentence =>
      quizSentence.replaceFirst(RegExp(r'＿+'), answer);
}

class VocabularyRolePlayTurn {
  const VocabularyRolePlayTurn({required this.speaker, required this.text});

  final String speaker;
  final String text;

  bool get isLearnerTurn => text.contains('＿');
}

final _rolePlaySpeakerPattern = RegExp(
  r'(?:^|\s)([A-Za-z][A-Za-z0-9]{0,2})\s*[：:]\s*',
);

List<VocabularyRolePlayTurn> _parseRolePlayTurns(String script) {
  final matches = _rolePlaySpeakerPattern.allMatches(script).toList();
  return List.generate(matches.length, (index) {
    final match = matches[index];
    final end = index + 1 < matches.length
        ? matches[index + 1].start
        : script.length;
    return VocabularyRolePlayTurn(
      speaker: match.group(1)!,
      text: script.substring(match.end, end).trim(),
    );
  });
}

class Vocabulary {
  const Vocabulary({
    required this.id,
    required this.word,
    required this.reading,
    required this.furigana,
    required this.romaji,
    required this.meanings,
    required this.partOfSpeech,
    required this.jlptLevel,
    required this.tags,
    required this.example,
    this.rank = 0,
    this.isCommon = true,
  });

  factory Vocabulary.fromJson(Map<String, dynamic> json) {
    return Vocabulary(
      id: json['id'] as String,
      word: json['word'] as String,
      reading: json['reading'] as String,
      furigana: json['furigana'] as String? ?? json['reading'] as String,
      romaji: json['romaji'] as String? ?? '',
      meanings: (json['meanings'] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, List<String>.from(value as List)),
      ),
      partOfSpeech: json['partOfSpeech'] as String,
      jlptLevel: json['jlptLevel'] as String,
      tags: List<String>.from(json['tags'] as List? ?? const []),
      example: VocabularyExample.fromJson(
        json['example'] as Map<String, dynamic>,
      ),
      rank: json['rank'] as int? ?? 0,
      isCommon: json['isCommon'] as bool? ?? true,
    );
  }

  factory Vocabulary.fromCatalogJson(Map<String, dynamic> json) {
    final word = json['word'] as String;
    final reading = json['reading'] as String;
    final level = json['level'] as String;
    final rank = json['rank'] as int;
    final exampleJson = json['example'] as Map<String, dynamic>?;
    return Vocabulary(
      id: '${level}_${rank}_${_safeIdPart(word)}_${_safeIdPart(reading)}',
      word: word,
      reading: reading,
      furigana: reading,
      romaji: '',
      meanings: {
        'en': [json['meaning'] as String],
      },
      partOfSpeech: 'word',
      jlptLevel: level,
      tags: const ['JLPT'],
      example: exampleJson == null
          ? const VocabularyExample(
              sentence: '',
              reading: '',
              translations: {},
              quizSentence: '',
              answer: '',
            )
          : VocabularyExample.fromJson(exampleJson),
      rank: rank,
    );
  }

  final String id;
  final String word;
  final String reading;
  final String furigana;
  final String romaji;
  final Map<String, List<String>> meanings;
  final String partOfSpeech;
  final String jlptLevel;
  final List<String> tags;
  final VocabularyExample example;
  final int rank;
  final bool isCommon;

  bool get hasExample => example.sentence.isNotEmpty;

  String meaning(String language) =>
      (meanings[language] ?? meanings['en'] ?? const ['']).join(', ');

  bool matches(String query, String language) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return [
      word,
      reading,
      furigana,
      romaji,
      meaning(language),
      ...tags,
    ].any((value) => value.toLowerCase().contains(normalized));
  }

  Vocabulary enrichedWith(Vocabulary source) {
    return Vocabulary(
      id: id,
      word: word,
      reading: reading,
      furigana: source.furigana,
      romaji: source.romaji,
      meanings: {
        ...meanings,
        if (source.meanings['ko'] != null) 'ko': source.meanings['ko']!,
      },
      partOfSpeech: source.partOfSpeech,
      jlptLevel: jlptLevel,
      tags: {...tags, ...source.tags}.toList(),
      example: source.hasExample ? source.example : example,
      rank: rank,
      isCommon: source.isCommon,
    );
  }
}

String _safeIdPart(String value) => value.replaceAll('/', '／');
