class GrammarExample {
  const GrammarExample({
    required this.japanese,
    required this.romaji,
    required this.english,
  });

  factory GrammarExample.fromJson(Map<String, dynamic> json) => GrammarExample(
    japanese: json['japanese'] as String,
    romaji: json['romaji'] as String,
    english: json['english'] as String,
  );

  final String japanese;
  final String romaji;
  final String english;
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
  });

  factory GrammarPoint.fromJson(Map<String, dynamic> json) => GrammarPoint(
    id: json['id'] as String,
    level: json['level'] as String,
    rank: json['rank'] as int,
    title: json['title'] as String,
    summary: json['summary'] as String,
    explanation: json['explanation'] as String,
    formation: json['formation'] as String,
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

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return [
      title,
      summary,
      explanation,
      formation,
    ].any((value) => value.toLowerCase().contains(normalized));
  }
}
