import 'package:jlpt_practice/core/utils/daily_lesson_readings.dart';
import 'package:jlpt_practice/data/models/daily_lesson.dart';

/// Formats only public lesson content; no account or tutor state is included.
String dailyLessonShareText(
  DailyLesson lesson, {
  LessonExpression? expression,
  bool korean = false,
}) {
  final sections = <String>[
    '🌸 ${korean ? '매일 일본어' : 'Daily Japanese'} · ${lesson.date}',
  ];
  String text(LessonText value) {
    final japanese = _stripSpeaker(value.japanese);
    final reading = dailyLessonReading(japanese, _stripSpeaker(value.reading));
    return [
      japanese,
      if (reading.isNotEmpty && reading != japanese) '($reading)',
      if (value.translation.trim().isNotEmpty) _stripSpeaker(value.translation),
    ].join('\n');
  }

  for (final item in expression == null ? lesson.expressions : [expression]) {
    sections.add('📝 ${korean ? '표현' : 'Expression'}\n${text(item)}');
    if (item.explanation.trim().isNotEmpty) {
      sections.add(item.explanation.trim());
    }
    if (item.examples.isNotEmpty) {
      sections.add(
        '💬 ${korean ? '대화' : 'Conversation'}\n${[for (final (index, example) in item.examples.indexed) '${_speaker(example.japanese) ?? (index.isEven ? 'A' : 'B')}: ${text(example)}'].join('\n\n')}',
      );
    }
  }
  if (expression == null && lesson.notes.isNotEmpty) {
    sections.add(
      '📚 ${korean ? '학습 노트' : 'Lesson notes'}\n${lesson.notes.join('\n')}',
    );
  }
  if (lesson.uncertainText.isNotEmpty) {
    sections.add(
      korean
          ? '일부 원문이 불확실합니다. 원문을 확인해 주세요.'
          : 'Some source text is uncertain. Please check the original.',
    );
  }
  if (lesson.url.trim().isNotEmpty) {
    sections.add('📖 ${korean ? '출처' : 'Source'}\n${lesson.url}');
  }
  sections.add(
    korean
        ? 'AI로 옮긴 학습 자료입니다. 본문과 읽기에 오류가 있을 수 있습니다.'
        : 'AI-transcribed study material. Text and readings may contain errors.',
  );
  return sections.join('\n\n');
}

String _stripSpeaker(String text) =>
    text.replaceFirst(dailyLessonSpeakerPrefix, '').trim();
String? _speaker(String text) {
  final label = dailyLessonSpeakerPrefix.firstMatch(text)?.group(1);
  return switch (label) {
    'Ａ' => 'A',
    'Ｂ' => 'B',
    _ => label,
  };
}
