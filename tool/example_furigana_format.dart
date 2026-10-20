final _kanji = RegExp(r'[㐀-䶿一-鿿々〆]+');
final _annotation = RegExp(r'\{([㐀-䶿一-鿿々〆]+)\|([ぁ-ゖー]+)\}');
final _markup = RegExp(r'[{}|]');

/// Ensures generated ruby covers every kanji and preserves the written sentence.
bool hasValidExampleFurigana(Map<String, dynamic> example) {
  final sentence = example['sentence'];
  final marked = example['sentence_furigana'];
  if (sentence is! String || sentence.isEmpty || marked is! String) {
    return false;
  }
  var cursor = 0;
  final written = StringBuffer();
  for (final match in _annotation.allMatches(marked)) {
    final plain = marked.substring(cursor, match.start);
    if (_kanji.hasMatch(plain) || _markup.hasMatch(plain)) return false;
    written.write(plain);
    written.write(match.group(1));
    cursor = match.end;
  }
  final tail = marked.substring(cursor);
  if (_kanji.hasMatch(tail) || _markup.hasMatch(tail)) return false;
  written.write(tail);
  return written.toString() == sentence;
}
