import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/data/models/grammar_point.dart';
import 'package:jlpt_practice/core/utils/furigana_alignment.dart';

void main() {
  late List<Map<String, dynamic>> catalog;

  setUpAll(() {
    catalog =
        (jsonDecode(File('assets/data/jlpt_grammar.json').readAsStringSync())
                as List<dynamic>)
            .cast<Map<String, dynamic>>();
  });

  test('catalog contains every Hanabira grammar rank record', () {
    expect(catalog, hasLength(828));
    expect(_count(catalog, 'N1'), 245);
    expect(_count(catalog, 'N2'), 191);
    expect(_count(catalog, 'N3'), 132);
    expect(_count(catalog, 'N4'), 124);
    expect(_count(catalog, 'N5'), 136);
  });

  test('every grammar example aligns readings and preserves its sentence', () {
    for (final point in catalog) {
      for (final raw in point['examples'] as List<dynamic>) {
        final example = GrammarExample.fromJson(raw as Map<String, dynamic>);
        final segments = example.sentenceSegments;
        expect(
          segments.map((segment) => segment.text).join(),
          example.japanese,
        );
        for (final segment in segments) {
          if (_containsKanji(segment.text)) {
            expect(segment.ruby, isNotNull, reason: example.japanese);
            expect(segment.ruby, isNotEmpty, reason: example.japanese);
          }
        }
      }
    }
  });

  test(
    'furigana alignment handles katakana, okurigana and mismatched readings',
    () {
      final segments = alignSentenceFurigana(
        '一ヶ月後、フランス語を話します。',
        'いちかげつご、フランスごをはなします。',
      );
      expect(
        segments
            .where((segment) => segment.ruby != null)
            .map((segment) => segment.ruby),
        ['いちかげつご', 'ご', 'はな'],
      );
      final fallback = alignSentenceFurigana('学校へ行く。', 'invalid');
      expect(fallback.single.text, '学校へ行く。');
      expect(fallback.single.ruby, isNull);
    },
  );

  test('grammar ranks are contiguous within every level', () {
    for (final level in ['N1', 'N2', 'N3', 'N4', 'N5']) {
      final ranks = catalog
          .where((item) => item['level'] == level)
          .map((item) => item['rank'] as int)
          .toList();
      expect(ranks, List<int>.generate(ranks.length, (index) => index + 1));
    }
  });

  test('every grammar point and every source example is complete', () {
    var exampleCount = 0;
    for (final item in catalog) {
      for (final key in [
        'id',
        'title',
        'summary',
        'explanation',
        'formation',
        'summaryKo',
        'explanationKo',
        'formationKo',
      ]) {
        expect(
          item[key],
          isNotEmpty,
          reason: '${item['level']} #${item['rank']}',
        );
      }
      expect(item['formationKo'], item['formation']);
      expect(_hasCleanKorean(item['summaryKo'] as String), isTrue);
      expect(_hasCleanKorean(item['explanationKo'] as String), isTrue);
      final examples = (item['examples'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      expect(examples, isNotEmpty);
      exampleCount += examples.length;
      for (final example in examples) {
        expect(example['japanese'], isNotEmpty);
        expect(example['reading'], isNotEmpty);
        expect(_containsKanji(example['reading'] as String), isFalse);
        expect(example['english'], isNotEmpty);
        expect(example['korean'], isNotEmpty);
        expect(_hasCleanKorean(example['korean'] as String), isTrue);
      }
    }
    expect(exampleCount, 3310);
  });
}

int _count(List<Map<String, dynamic>> catalog, String level) =>
    catalog.where((item) => item['level'] == level).length;

bool _hasCleanKorean(String value) =>
    RegExp('[가-힣]').hasMatch(value) &&
    !RegExp(r'[\u0400-\u04ff\u0600-\u06ff]').hasMatch(value);

bool _containsKanji(String value) =>
    RegExp(r'[\u3400-\u4DBF\u4E00-\u9FFF々〆ヵヶ]').hasMatch(value);
