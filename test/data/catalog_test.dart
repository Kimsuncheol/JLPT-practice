import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/data/models/vocabulary.dart';

void main() {
  late List<Map<String, dynamic>> catalog;

  setUpAll(() {
    final decoded =
        jsonDecode(File('assets/data/jlpt_catalog.json').readAsStringSync())
            as List<dynamic>;
    catalog = decoded.cast<Map<String, dynamic>>();
  });

  test('catalog contains every upstream rank record', () {
    expect(catalog, hasLength(8449));
    expect(_count(catalog, 'N1'), 3476);
    expect(_count(catalog, 'N2'), 1835);
    expect(_count(catalog, 'N3'), 1835);
    expect(_count(catalog, 'N4'), 634);
    expect(_count(catalog, 'N5'), 669);
  });

  test('ranks are contiguous within each JLPT level', () {
    for (final level in ['N1', 'N2', 'N3', 'N4', 'N5']) {
      final ranks = catalog
          .where((word) => word['level'] == level)
          .map((word) => word['rank'] as int)
          .toList();
      expect(ranks, List<int>.generate(ranks.length, (index) => index + 1));
    }
  });

  test('every catalog record has required display data', () {
    for (final word in catalog) {
      expect(word['word'], isNotEmpty);
      expect(word['reading'], isNotEmpty);
      expect(word['meaning'], isNotEmpty);
    }
  });

  test('every catalog record has a complete example', () {
    for (final word in catalog) {
      final example = word['example'] as Map<String, dynamic>;
      final sentence = example['sentence'] as String;
      final reading = example['reading'] as String;
      final quizSentence = example['quizSentence'] as String;
      final answer = example['answer'] as String;
      final translations = example['translations'] as Map<String, dynamic>;

      expect(sentence, isNotEmpty, reason: '${word['level']} #${word['rank']}');
      expect(reading, isNotEmpty);
      expect(
        _compact(reading).length,
        greaterThanOrEqualTo((_compact(sentence).length * 0.8).floor()),
        reason: '${word['level']} #${word['rank']} has a partial reading',
      );
      expect(
        _containsKanji(reading),
        isFalse,
        reason: '${word['level']} #${word['rank']} has unresolved furigana',
      );
      expect(translations['en'], isNotEmpty);
      expect(translations['ko'], isNotEmpty);
      expect(answer, isNotEmpty);
      expect(sentence.contains(answer), isTrue);
      expect(quizSentence, sentence.replaceFirst(answer, '＿＿＿'));
    }
  });

  test('only speaker-tagged examples are classified as role-play', () {
    final rolePlayWords = catalog
        .map(Vocabulary.fromCatalogJson)
        .where((word) => word.example.hasRolePlay)
        .toList();

    expect(rolePlayWords, hasLength(1));
    expect(rolePlayWords.single.jlptLevel, 'N5');
    expect(rolePlayWords.single.rank, 89);
    expect(rolePlayWords.single.word, 'ええ');
    expect(
      rolePlayWords.single.example.rolePlayTurns
          .map((turn) => turn.speaker),
      ['A', 'B'],
    );
  });
}

String _compact(String value) => value.replaceAll(RegExp(r'[\s\u3000]'), '');

bool _containsKanji(String value) =>
    RegExp(r'[\u3400-\u4DBF\u4E00-\u9FFF々〆ヵヶ]').hasMatch(value);

int _count(List<Map<String, dynamic>> catalog, String level) =>
    catalog.where((word) => word['level'] == level).length;
