import 'package:jlpt_practice/core/services/meaning_mask_service.dart';

/// A small, memory-safe Korean analyzer tailored to masking vocabulary in
/// example translations.
///
/// The previous implementation called Kiwi through native FFI. A fault in
/// that ARM64 runtime terminates the whole Android process, so it is not safe
/// to use for an optional display feature. This analyzer recognizes the noun,
/// particle, and common predicate shapes needed by the masker using Dart only.
class KoreanMorphemeAnalyzer implements MorphemeAnalyzer {
  static final _word = RegExp(r'[가-힣]+');

  static const _particles = [
    '에게서',
    '으로는',
    '에서는',
    '부터는',
    '까지는',
    '처럼은',
    '에게',
    '에서',
    '으로',
    '부터',
    '까지',
    '처럼',
    '보다',
    '하고',
    '와',
    '과',
    '은',
    '는',
    '이',
    '가',
    '을',
    '를',
    '에',
    '도',
    '만',
    '의',
    '로',
  ];

  static const _endings = [
    '었습니다',
    '았습니다',
    '겠어요',
    '었어요',
    '았어요',
    '습니다',
    '겠어',
    '어서',
    '아서',
    '으면',
    '면서',
    '어요',
    '아요',
    '고',
    '면',
    '서',
    '지',
    '죠',
    '네',
    '다',
    '요',
  ];

  static const _haForms = {
    '하': '하',
    '해': '하',
    '했': '하',
    '할': '하',
    '한': '하',
    '함': '하',
    '합': '하',
  };

  static const _irregularStems = {'들': '듣', '걸': '걷', '물': '묻'};

  var _closed = false;

  @override
  Future<List<Morpheme>> analyze(String text) async {
    if (_closed) throw StateError('KoreanMorphemeAnalyzer is closed.');
    return [
      for (final match in _word.allMatches(text))
        ..._analyzeWord(match.group(0)!, match.start),
    ];
  }

  List<Morpheme> _analyzeWord(String word, int offset) {
    for (var index = 0; index < word.length; index++) {
      final normalized = _haForms[word[index]];
      if (normalized == null || index == 0) continue;
      return [
        Morpheme(
          form: word.substring(0, index),
          tag: 'NNG',
          start: offset,
          length: index,
        ),
        Morpheme(form: normalized, tag: 'VV', start: offset + index, length: 1),
        if (index + 1 < word.length)
          Morpheme(
            form: word.substring(index + 1),
            tag: 'EF',
            start: offset + index + 1,
            length: word.length - index - 1,
          ),
      ];
    }

    for (final ending in _endings) {
      if (!word.endsWith(ending) || word.length <= ending.length) continue;
      final surfaceStem = word.substring(0, word.length - ending.length);
      final stem = _irregularStems[surfaceStem] ?? surfaceStem;
      return [
        Morpheme(
          form: stem,
          tag: 'VV',
          start: offset,
          length: surfaceStem.length,
        ),
        Morpheme(
          form: ending,
          tag: 'EF',
          start: offset + surfaceStem.length,
          length: ending.length,
        ),
      ];
    }

    for (final particle in _particles) {
      if (!word.endsWith(particle) || word.length <= particle.length) continue;
      final nounLength = word.length - particle.length;
      return [
        Morpheme(
          form: word.substring(0, nounLength),
          tag: 'NNG',
          start: offset,
          length: nounLength,
        ),
        Morpheme(
          form: particle,
          tag: 'JX',
          start: offset + nounLength,
          length: particle.length,
        ),
      ];
    }

    return [
      Morpheme(form: word, tag: 'NNG', start: offset, length: word.length),
    ];
  }

  @override
  Future<void> close() async => _closed = true;
}
