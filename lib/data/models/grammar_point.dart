class GrammarExample {
  const GrammarExample({
    required this.japanese,
    required this.reading,
    required this.english,
    this.korean = '',
  });

  factory GrammarExample.fromJson(Map<String, dynamic> json) => GrammarExample(
    japanese: json['japanese'] as String,
    reading: json['reading'] as String,
    english: json['english'] as String,
    korean: json['korean'] as String? ?? '',
  );

  final String japanese;
  final String reading;
  final String english;
  final String korean;

  String translation(String language) =>
      language == 'ko' && korean.isNotEmpty ? korean : english;
}

class GrammarPoint {
  const GrammarPoint({
    required this.id,
    required this.level,
    required this.rank,
    required this.title,
    required this.summary,
    required this.explanation,
    required this.formation,
    required this.examples,
    this.summaryKo = '',
    this.explanationKo = '',
    this.formationKo = '',
  });

  factory GrammarPoint.fromJson(Map<String, dynamic> json) => GrammarPoint(
    id: json['id'] as String,
    level: json['level'] as String,
    rank: json['rank'] as int,
    title: json['title'] as String,
    summary: json['summary'] as String,
    explanation: json['explanation'] as String,
    formation: json['formation'] as String,
    summaryKo: json['summaryKo'] as String? ?? '',
    explanationKo: json['explanationKo'] as String? ?? '',
    formationKo: json['formationKo'] as String? ?? '',
    examples: (json['examples'] as List<dynamic>)
        .map((item) => GrammarExample.fromJson(item as Map<String, dynamic>))
        .toList(growable: false),
  );

  final String id;
  final String level;
  final int rank;
  final String title;
  final String summary;
  final String explanation;
  final String formation;
  final List<GrammarExample> examples;
  final String summaryKo;
  final String explanationKo;
  final String formationKo;

  String localizedSummary(String language) =>
      language == 'ko' && summaryKo.isNotEmpty ? summaryKo : summary;

  String localizedExplanation(String language) =>
      language == 'ko' && explanationKo.isNotEmpty
      ? explanationKo
      : explanation;

  String localizedFormation(String language) =>
      language == 'ko' && formationKo.isNotEmpty ? formationKo : formation;

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return [
      title,
      summary,
      explanation,
      formation,
      summaryKo,
      explanationKo,
      formationKo,
    ].any((value) => value.toLowerCase().contains(normalized));
  }
}
