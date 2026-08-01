import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
        expect(example['romaji'], isNotEmpty);
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
