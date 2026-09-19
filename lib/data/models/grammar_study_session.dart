enum GrammarStudyKind { detail, tutor, checkpoint }

class GrammarStudySession {
  const GrammarStudySession({
    required this.level,
    required this.part,
    required this.kind,
    required this.updatedAt,
    this.grammarId,
    this.title,
  });

  final String level;
  final int part;
  final GrammarStudyKind kind;
  final DateTime updatedAt;
  final String? grammarId;
  final String? title;

  String get route => switch (kind) {
    GrammarStudyKind.detail =>
      '/grammar/detail/${Uri.encodeComponent(grammarId!)}',
    GrammarStudyKind.tutor =>
      '/grammar/tutor/${Uri.encodeComponent(grammarId!)}',
    GrammarStudyKind.checkpoint => '/grammar/part/$level/$part',
  };

  factory GrammarStudySession.fromJson(Map<String, dynamic> json) {
    final session = GrammarStudySession(
      level: json['level'] as String,
      part: json['part'] as int,
      kind: GrammarStudyKind.values.byName(json['kind'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      grammarId: json['grammarId'] as String?,
      title: json['title'] as String?,
    );
    if (session.part < 1 ||
        (session.kind != GrammarStudyKind.checkpoint &&
            (session.grammarId == null || session.grammarId!.isEmpty))) {
      throw const FormatException('Invalid grammar study session');
    }
    return session;
  }

  Map<String, dynamic> toJson() => {
    'level': level,
    'part': part,
    'kind': kind.name,
    'updatedAt': updatedAt.toIso8601String(),
    'grammarId': grammarId,
    'title': title,
  };
}
