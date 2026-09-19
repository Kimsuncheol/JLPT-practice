import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/features/vocabulary/cover_masking.dart';

List<String> covered(List<MaskSegment> segments) => [
  for (final segment in segments)
    if (segment.covered) segment.text,
];

void main() {
  group('wordMaskTargets', () {
    test('adds the stem of an inflecting word', () {
      expect(wordMaskTargets('食べる'), ['食べる', '食べ']);
    });

    test('keeps kana-only words whole', () {
      expect(wordMaskTargets('ある'), ['ある']);
    });
  });

  group('maskSegments', () {
    test('covers the word wherever it appears', () {
      final segments = maskSegments('学生は学校へ行く。', wordMaskTargets('学生'));
      expect(covered(segments), ['学生']);
      expect(segments.map((s) => s.text).join(), '学生は学校へ行く。');
    });

    test('covers an inflected use through the stem', () {
      expect(covered(maskSegments('朝ご飯を食べます。', wordMaskTargets('食べる'))), [
        '食べ',
      ]);
    });

    test('covers the whole English word and ignores case', () {
      final segments = maskSegments('Eating is fun. I eat rice.', ['eat']);
      expect(covered(segments), ['Eating', 'eat']);
    });

    test('leaves text alone when nothing matches', () {
      final segments = maskSegments('こんにちは', ['学生']);
      expect(segments, hasLength(1));
      expect(segments.single.covered, isFalse);
    });
  });

  group('meaningMaskTargets', () {
    test('drops the infinitive marker and short fragments', () {
      expect(meaningMaskTargets(['to eat', 'to be']), ['eat']);
    });

    test('splits lists and removes parenthetical notes', () {
      expect(meaningMaskTargets(['student (school)', 'pupil; learner']), [
        'student',
        'pupil',
        'learner',
      ]);
    });

    test('adds the stem of a Korean dictionary form', () {
      expect(meaningMaskTargets(['먹다']), ['먹다', '먹']);
    });
  });
}
