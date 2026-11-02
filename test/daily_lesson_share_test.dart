import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/core/utils/daily_lesson_share.dart';
import 'package:jlpt_practice/data/models/daily_lesson.dart';

void main() {
  const expression = LessonExpression(
    japanese: '久しぶり',
    reading: 'ひさしぶり',
    translation: '오랜만임',
    examples: [LessonText(japanese: 'Ｂ：そうですね。', translation: 'B 그렇네요.')],
  );
  const lesson = DailyLesson(
    id: 'private-id',
    title: 'title',
    date: '2026-11-02',
    url: 'https://example.com/source',
    expressions: [
      expression,
      LessonExpression(japanese: '見る'),
    ],
    notes: ['見る — 보다'],
  );
  test(
    'single expression includes readings and source, normalizes speaker labels',
    () {
      final text = dailyLessonShareText(lesson, expression: expression);
      expect(text, contains('久しぶり\n(ひさしぶり)\n오랜만임'));
      expect(text, contains('B: そうですね。\n그렇네요.'));
      expect(text, contains(lesson.url));
      expect(text, isNot(contains('見る')));
      expect(text, isNot(contains(lesson.id)));
    },
  );
  test('full lesson includes all expressions and notes, localized labels', () {
    final text = dailyLessonShareText(lesson, korean: true);
    expect(text, contains('매일 일본어 · 2026-11-02'));
    expect(text, contains('📝 표현\n見る'));
    expect(text, contains('📚 학습 노트\n見る — 보다'));
    expect(text, contains('📖 출처\n${lesson.url}'));
  });
}
