class LessonText {
  const LessonText({
    required this.japanese,
    this.reading = '',
    this.translation = '',
  });

  factory LessonText.fromJson(Map<String, dynamic> json) => LessonText(
    japanese: json['japanese'] as String,
    reading: json['reading'] as String? ?? '',
    translation: json['translation'] as String? ?? '',
  );

  final String japanese, reading, translation;
}

class LessonExpression extends LessonText {
  const LessonExpression({
    required super.japanese,
    super.reading,
    super.translation,
    this.explanation = '',
    this.examples = const [],
  });

  factory LessonExpression.fromJson(Map<String, dynamic> json) {
    final text = LessonText.fromJson(json);
    if (text.japanese.trim().isEmpty) throw const FormatException();
    return LessonExpression(
      japanese: text.japanese,
      reading: text.reading,
      translation: text.translation,
      explanation: json['explanation'] as String? ?? '',
      examples: [
        for (final item in json['examples'] as List? ?? [])
          LessonText.fromJson(item as Map<String, dynamic>),
      ],
    );
  }

  final String explanation;
  final List<LessonText> examples;
}

class DailyLesson {
  const DailyLesson({
    required this.id,
    required this.title,
    required this.date,
    required this.url,
    required this.expressions,
    this.notes = const [],
    this.uncertainText = const [],
  });

  factory DailyLesson.fromJson(Map<String, dynamic> json) {
    if (json['status'] != 'ready') throw const FormatException();
    final lesson = json['lesson'] as Map<String, dynamic>;
    final expressions = [
      for (final item in lesson['expressions'] as List)
        LessonExpression.fromJson(item as Map<String, dynamic>),
    ];
    final id = json['id'] as String;
    if (id.isEmpty || expressions.isEmpty) throw const FormatException();
    return DailyLesson(
      id: id,
      title: json['title'] as String,
      date: json['date'] as String,
      url: json['url'] as String,
      expressions: expressions,
      notes: (lesson['notes'] as List? ?? []).cast<String>(),
      uncertainText: (lesson['uncertain_text'] as List? ?? []).cast<String>(),
    );
  }

  final String id, title, date, url;
  final List<LessonExpression> expressions;
  final List<String> notes, uncertainText;

  bool publishedToday(DateTime now) =>
      date ==
      '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

class DailyLessonPage {
  DailyLessonPage.fromJson(Map<String, dynamic> json)
    : lessons = [
        for (final item in json['articles'] as List)
          DailyLesson.fromJson(item as Map<String, dynamic>),
      ],
      page = json['page'] as int,
      pages = json['pages'] as int,
      total = json['total'] as int {
    if (page < 1 || pages < page || total < 0) throw const FormatException();
  }

  final List<DailyLesson> lessons;
  final int page, pages, total;
}
