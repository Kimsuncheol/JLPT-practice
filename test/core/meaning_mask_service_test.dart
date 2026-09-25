import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/core/services/korean_morpheme_analyzer.dart';
import 'package:jlpt_practice/core/services/meaning_mask_service.dart';

import 'kiwi_fixtures.dart';

class _FixtureAnalyzer implements MorphemeAnalyzer {
  _FixtureAnalyzer([this.fixtures = kiwiFixtures]);

  final Map<String, List<Morpheme>> fixtures;
  int calls = 0;

  @override
  Future<List<Morpheme>> analyze(String text) async {
    calls++;
    final tokens = fixtures[text];
    if (tokens == null) throw StateError('No fixture for "$text".');
    return tokens;
  }

  @override
  Future<void> close() async {}
}

class _FailingAnalyzer implements MorphemeAnalyzer {
  @override
  Future<List<Morpheme>> analyze(String text) async =>
      throw StateError('Kiwi failed to initialize.');

  @override
  Future<void> close() async {}
}

/// Each case: meaning, sentence, expected spans as (start, end, text).
const _examples = <(String, String, List<MaskSpan>)>[
  ('일하다', '장래에 의사로 일할 생각입니다.', [MaskSpan(start: 8, end: 10, text: '일할')]),
  ('공부하다', '어제 도서관에서 공부했어요.', [MaskSpan(start: 9, end: 14, text: '공부했어요')]),
  (
    '일하다, 근무하다',
    '그는 은행에서 근무하고 있어요.',
    [MaskSpan(start: 8, end: 12, text: '근무하고')],
  ),
  ('듣다', '음악을 들었어요.', [MaskSpan(start: 4, end: 8, text: '들었어요')]),
  ('먹다', '밥을 먹었어요.', [MaskSpan(start: 3, end: 7, text: '먹었어요')]),
  ('일하다', '일요일에는 일이 많아요.', <MaskSpan>[]),
];

void main() {
  group('MeaningMaskService', () {
    for (final (meaning, sentence, expected) in _examples) {
      test('$meaning in "$sentence"', () async {
        final service = MeaningMaskService(_FixtureAnalyzer());
        expect(await service.findMaskSpans(meaning, sentence), expected);
      });
    }

    test('span offsets index the original sentence', () async {
      final service = MeaningMaskService(_FixtureAnalyzer());
      for (final (meaning, sentence, _) in _examples) {
        for (final span in await service.findMaskSpans(meaning, sentence)) {
          expect(sentence.substring(span.start, span.end), span.text);
        }
      }
    });

    test('caches results per meaning and sentence', () async {
      final analyzer = _FixtureAnalyzer();
      final service = MeaningMaskService(analyzer);
      await service.findMaskSpans('먹다', '밥을 먹었어요.');
      final callsAfterFirst = analyzer.calls;
      await service.findMaskSpans('먹다', '밥을 먹었어요.');
      expect(analyzer.calls, callsAfterFirst);
    });

    test('falls back to substring matching when Kiwi is unavailable', () async {
      final service = MeaningMaskService(_FailingAnalyzer());
      expect(await service.findMaskSpans('일하다', '회사에서 일하고 있어요.'), [
        const MaskSpan(start: 5, end: 7, text: '일하'),
      ]);
    });

    test('falls back for a meaning that has no lemma', () async {
      final service = MeaningMaskService(
        _FixtureAnalyzer({
          '를': const [Morpheme(form: '를', tag: 'JKO', start: 0, length: 1)],
        }),
      );
      // Only the meaning is analyzed with a fixture; the substring fallback
      // needs no analysis of the sentence.
      expect(await service.findMaskSpans('를', '밥을 먹고 물를 마셔요.'), [
        const MaskSpan(start: 7, end: 8, text: '를'),
      ]);
    });
  });

  group('KoreanMorphemeAnalyzer', () {
    for (final (meaning, sentence, expected) in _examples) {
      test('$meaning in "$sentence"', () async {
        final analyzer = KoreanMorphemeAnalyzer();
        addTearDown(analyzer.close);
        final service = MeaningMaskService(analyzer);
        expect(await service.findMaskSpans(meaning, sentence), expected);
      });
    }
  });
}
