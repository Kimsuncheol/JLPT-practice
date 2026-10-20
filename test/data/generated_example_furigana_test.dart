import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/data/models/vocabulary.dart';
import 'package:jlpt_practice/features/vocabulary/example_furigana_text.dart';

import '../../tool/example_furigana_format.dart';

void main() {
  const sentence = '旅行から帰った。';
  const marked = '{旅行|りょこう}から{帰|かえ}った。';

  test('requires exact text and readings for all kanji', () {
    for (final value in [
      marked,
      null,
      '',
      'りょこうからかえった。',
      '{旅行|りょこう}から帰った。',
      '{旅行|旅行}から{帰|かえ}った。',
      '{旅行|りょこう}から{帰った|かえった}。',
      '{旅行|りょこう}から{帰|かえ}った！',
    ]) {
      expect(
        hasValidExampleFurigana({
          'sentence': sentence,
          'sentence_furigana': value,
        }),
        value == marked,
        reason: '$value',
      );
    }
    expect(
      hasValidExampleFurigana({
        'sentence': 'こんにちは。',
        'sentence_furigana': 'こんにちは。',
      }),
      isTrue,
    );
  });

  for (final legacy in [false, true]) {
    testWidgets('study examples show ruby above kanji (legacy: $legacy)', (
      tester,
    ) async {
      final example = VocabularyExample.fromJson({
        'sentence': sentence,
        if (legacy) 'reading': 'りょこうからかえった。' else 'sentence_furigana': marked,
        'translations': <String, String>{},
      });
      expect(example.speechText, 'りょこうからかえった。');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ExampleFuriganaText(
              segments: example.sentenceSegments,
              style: const TextStyle(fontSize: 22),
              wordTargets: const [],
              hideReadings: false,
            ),
          ),
        ),
      );
      for (final pair in [('旅行', 'りょこう'), ('帰', 'かえ')]) {
        final ruby = find.text(pair.$2, findRichText: true);
        final kanji = find.text(pair.$1);
        expect(ruby, findsOneWidget);
        expect(kanji, findsOneWidget);
        expect(
          tester.getBottomLeft(ruby).dy,
          lessThanOrEqualTo(tester.getTopLeft(kanji).dy),
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
}
