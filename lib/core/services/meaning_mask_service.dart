import 'dart:developer' as developer;

/// A run of a translation that must be hidden. [start] is inclusive and [end]
/// exclusive, in UTF-16 code units of the analyzed string.
class MaskSpan {
  const MaskSpan({required this.start, required this.end, required this.text});

  final int start;
  final int end;
  final String text;

  @override
  bool operator ==(Object other) =>
      other is MaskSpan &&
      other.start == start &&
      other.end == end &&
      other.text == text;

  @override
  int get hashCode => Object.hash(start, end, text);

  @override
  String toString() => 'MaskSpan($start, $end, $text)';
}

/// One morpheme of an analyzed text, with its position in that text.
class Morpheme {
  const Morpheme({
    required this.form,
    required this.tag,
    required this.start,
    required this.length,
  });

  final String form;

  /// Sejong/Kiwi part-of-speech tag such as `NNG`, `VV-I` or `XSV`.
  final String tag;
  final int start;
  final int length;

  int get end => start + length;
}

/// Splits Korean text into morphemes. Kept abstract so the matching logic
/// does not depend on the native Kiwi backend.
abstract interface class MorphemeAnalyzer {
  Future<List<Morpheme>> analyze(String text);

  Future<void> close();
}

/// Finds where the Korean meaning of a word — in any inflected form — appears
/// in an example translation, so those runs can be hidden.
///
/// Matching is by lemma: the meaning and the sentence are both reduced to
/// their content morphemes, so "듣다" is found inside "들었어요" although the
/// surface strings differ.
class MeaningMaskService {
  MeaningMaskService(this._analyzer);

  static const _logName = 'MeaningMaskService';
  static const _maxCachedEntries = 512;

  final MorphemeAnalyzer _analyzer;
  final _spanCache = <String, Future<List<MaskSpan>>>{};
  final _lemmaCache = <String, Future<_Lemma?>>{};

  Future<List<MaskSpan>> findMaskSpans(String meaning, String sentence) {
    final key = '$meaning\u0000$sentence';
    final cached = _spanCache.remove(key);
    if (cached != null) return _spanCache[key] = cached;
    if (_spanCache.length >= _maxCachedEntries) {
      _spanCache.remove(_spanCache.keys.first);
    }
    return _spanCache[key] = _findMaskSpans(meaning, sentence);
  }

  Future<void> close() => _analyzer.close();

  Future<List<MaskSpan>> _findMaskSpans(String meaning, String sentence) async {
    final parts = splitMeaningParts(meaning);
    if (parts.isEmpty || sentence.trim().isEmpty) return const [];

    final lemmas = <_Lemma>[];
    final fallbackParts = <String>[];
    for (final part in parts) {
      final lemma = await _lemmaFor(part);
      if (lemma == null) {
        fallbackParts.add(part);
      } else {
        lemmas.add(lemma);
      }
    }

    final spans = <MaskSpan>[];
    if (lemmas.isNotEmpty) {
      try {
        final tokens = await _analyzer.analyze(sentence);
        for (final lemma in lemmas) {
          spans.addAll(_matchLemma(lemma, sentence, tokens));
        }
      } catch (error) {
        _warn(
          'Could not analyze the translation; using substring match.',
          error,
        );
        fallbackParts.addAll(
          lemmas
              .map((lemma) => lemma.source)
              .where((p) => !fallbackParts.contains(p)),
        );
      }
    }
    for (final part in fallbackParts) {
      spans.addAll(_substringSpans(part, sentence));
    }
    return _merge(spans);
  }

  /// The content-morpheme lemma of [part], or null when Kiwi is unavailable
  /// or finds nothing to match on.
  Future<_Lemma?> _lemmaFor(String part) {
    return _lemmaCache.putIfAbsent(part, () async {
      try {
        final lemma = _Lemma.from(part, await _analyzer.analyze(part));
        if (lemma == null) {
          _warn('No lemma found for "$part"; using substring match.');
        }
        return lemma;
      } catch (error) {
        _warn('Could not analyze "$part"; using substring match.', error);
        return null;
      }
    });
  }

  List<MaskSpan> _matchLemma(
    _Lemma lemma,
    String sentence,
    List<Morpheme> tokens,
  ) {
    final spans = <MaskSpan>[];
    for (var first = 0; first < tokens.length; first++) {
      var joined = '';
      for (var last = first; last < tokens.length; last++) {
        final token = tokens[last];
        final category = _contentCategory(token.tag);
        if (category == null) break;
        joined += token.form;
        if (!lemma.stem.startsWith(joined)) break;
        if (joined == lemma.stem && category == lemma.lastCategory) {
          spans.add(_expandToEojeol(sentence, tokens, first, last));
          first = last;
          break;
        }
      }
    }
    return spans;
  }

  /// Grows the match to the space-delimited word(s) it sits in so attached
  /// endings are hidden too, while leaving sentence punctuation visible.
  MaskSpan _expandToEojeol(
    String sentence,
    List<Morpheme> tokens,
    int first,
    int last,
  ) {
    final matchStart = tokens[first].start.clamp(0, sentence.length);
    final matchEnd = tokens[last].end.clamp(0, sentence.length);
    var wordStart = matchStart;
    while (wordStart > 0 && !_isSpace(sentence.codeUnitAt(wordStart - 1))) {
      wordStart--;
    }
    var wordEnd = matchEnd;
    while (wordEnd < sentence.length &&
        !_isSpace(sentence.codeUnitAt(wordEnd))) {
      wordEnd++;
    }

    var start = matchStart;
    var end = matchEnd;
    for (final token in tokens) {
      if (token.tag.startsWith('S')) continue;
      if (token.start < wordStart || token.start >= wordEnd) continue;
      if (token.start < start) start = token.start;
      if (token.end > end) end = token.end.clamp(0, wordEnd);
    }
    return MaskSpan(
      start: start,
      end: end,
      text: sentence.substring(start, end),
    );
  }

  void _warn(String message, [Object? error]) {
    developer.log(message, name: _logName, level: 900, error: error);
  }
}

/// Splits a meaning like "일하다, 근무하다" into single meanings, dropping
/// parenthetical notes.
List<String> splitMeaningParts(String meaning) => meaning
    .replaceAll(RegExp(r'\(.*?\)|（.*?）'), '')
    .split(RegExp(r'[,;/、；，]'))
    .map((part) => part.trim())
    .where((part) => part.isNotEmpty)
    .toList();

/// The content morphemes of one meaning, joined into the stem to look for.
class _Lemma {
  const _Lemma(this.source, this.stem, this.lastCategory);

  final String source;
  final String stem;
  final String lastCategory;

  static _Lemma? from(String source, List<Morpheme> tokens) {
    final buffer = StringBuffer();
    String? lastCategory;
    for (final token in tokens) {
      final category = _contentCategory(token.tag);
      if (category == null) continue;
      buffer.write(token.form);
      lastCategory = category;
    }
    if (lastCategory == null) return null;
    return _Lemma(source, buffer.toString(), lastCategory);
  }
}

/// Coarse class of a content morpheme, or null for particles, endings and
/// punctuation. Verb suffixes (하/XSV) count as verbs and adjective suffixes
/// as adjectives, so a segmentation that fuses or splits them still matches.
String? _contentCategory(String tag) {
  if (tag.startsWith('NN') || tag == 'NR' || tag == 'NP' || tag == 'XSN') {
    return 'N';
  }
  if (tag.startsWith('VV') || tag.startsWith('VX') || tag == 'XSV') return 'V';
  if (tag.startsWith('VA') || tag == 'XSA') return 'A';
  if (tag == 'XR') return 'R';
  if (tag == 'MAG' || tag == 'MAJ' || tag == 'MM') return 'M';
  return null;
}

bool _isSpace(int codeUnit) => codeUnit == 0x20 || codeUnit == 0x3000;

/// Plain substring match on the meaning's stem ("일하다" → "일하").
List<MaskSpan> _substringSpans(String meaning, String sentence) {
  final stem = meaning.length > 1 && meaning.endsWith('다')
      ? meaning.substring(0, meaning.length - 1)
      : meaning;
  if (stem.isEmpty) return const [];
  final spans = <MaskSpan>[];
  var from = 0;
  while (true) {
    final index = sentence.indexOf(stem, from);
    if (index < 0) return spans;
    spans.add(MaskSpan(start: index, end: index + stem.length, text: stem));
    from = index + stem.length;
  }
}

List<MaskSpan> _merge(List<MaskSpan> spans) {
  if (spans.length < 2) return spans;
  final sorted = [...spans]..sort((a, b) => a.start.compareTo(b.start));
  final merged = <MaskSpan>[sorted.first];
  for (final span in sorted.skip(1)) {
    final previous = merged.last;
    if (span.start >= previous.end) {
      merged.add(span);
    } else if (span.end > previous.end) {
      // Both spans cut the same sentence, so the overlap is recoverable
      // from the text of whichever covers it.
      final text =
          previous.text + span.text.substring(previous.end - span.start);
      merged[merged.length - 1] = MaskSpan(
        start: previous.start,
        end: span.end,
        text: text,
      );
    }
  }
  return merged;
}
