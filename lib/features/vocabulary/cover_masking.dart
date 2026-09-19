/// A run of text that is either shown as-is or covered by tape.
class MaskSegment {
  const MaskSegment(this.text, {required this.covered});

  final String text;
  final bool covered;
}

final _kanji = RegExp(r'[㐀-䶿一-鿿々〆]');
final _hiragana = RegExp(r'^[ぁ-ゖ]$');
final _latinTarget = RegExp(r'^[A-Za-z][A-Za-z\s\-]*$');
final _meaningSeparators = RegExp(r'[;,/、；]|\(.*?\)|（.*?）');

/// Text forms that identify [word] inside an example sentence: the word
/// itself plus its stem, so an inflected use like 食べます still matches 食べる.
List<String> wordMaskTargets(String word) {
  final trimmed = word.trim();
  if (trimmed.isEmpty) return const [];
  final targets = <String>[trimmed];
  if (trimmed.length > 1 && _hiragana.hasMatch(trimmed[trimmed.length - 1])) {
    final stem = trimmed.substring(0, trimmed.length - 1);
    if (_kanji.hasMatch(stem)) targets.add(stem);
  }
  return targets;
}

/// Text forms that identify a word's meanings inside a translation:
/// each listed meaning, its infinitive-less form ("to eat" → "eat"), and the
/// stem of a Korean dictionary form ("먹다" → "먹").
List<String> meaningMaskTargets(Iterable<String> meanings) {
  final targets = <String>{};
  for (final meaning in meanings) {
    for (final part in meaning.split(_meaningSeparators)) {
      var candidate = part.trim();
      if (candidate.isEmpty) continue;
      if (_latinTarget.hasMatch(candidate)) {
        candidate = candidate.replaceFirst(
          RegExp(r'^(to|a|an|the)\s+', caseSensitive: false),
          '',
        );
        // Very short Latin fragments would blank out unrelated words.
        if (candidate.length >= 3) targets.add(candidate);
      } else {
        targets.add(candidate);
        if (candidate.length > 1 && candidate.endsWith('다')) {
          targets.add(candidate.substring(0, candidate.length - 1));
        }
      }
    }
  }
  return targets.toList();
}

/// Splits [text] into shown and covered runs. Longer targets win over shorter
/// ones. Latin targets match case-insensitively and cover the whole word they
/// start ("eat" also covers "eating").
List<MaskSegment> maskSegments(String text, Iterable<String> targets) {
  final ordered = targets.where((target) => target.isNotEmpty).toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  if (text.isEmpty || ordered.isEmpty) {
    return [MaskSegment(text, covered: false)];
  }
  final pattern = RegExp(
    ordered
        .map((target) {
          final escaped = RegExp.escape(target);
          return _latinTarget.hasMatch(target)
              ? '\\b$escaped[A-Za-z]*'
              : escaped;
        })
        .join('|'),
    caseSensitive: false,
  );
  final segments = <MaskSegment>[];
  var cursor = 0;
  for (final match in pattern.allMatches(text)) {
    if (match.end == match.start) continue;
    if (match.start > cursor) {
      segments.add(
        MaskSegment(text.substring(cursor, match.start), covered: false),
      );
    }
    segments.add(
      MaskSegment(text.substring(match.start, match.end), covered: true),
    );
    cursor = match.end;
  }
  if (cursor < text.length) {
    segments.add(MaskSegment(text.substring(cursor), covered: false));
  }
  return segments;
}
