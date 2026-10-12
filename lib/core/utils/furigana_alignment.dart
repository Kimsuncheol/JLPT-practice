import 'package:jlpt_practice/data/models/kanji.dart';

final _kanjiRuns = RegExp(r'[㐀-䶿一-鿿々〆ヵヶ]+');

String _normalizedKana(String text) => text
    .replaceAll(RegExp(r'\s+'), '')
    .replaceAllMapped(
      RegExp(r'[ァ-ヶ]'),
      (match) => String.fromCharCode(match.group(0)!.codeUnitAt(0) - 0x60),
    );

/// Aligns kanji readings using the unchanged kana between kanji runs as anchors.
/// If the supplied reading does not match, keep the original sentence intact.
List<FuriganaSegment> alignSentenceFurigana(String sentence, String reading) {
  final runs = _kanjiRuns.allMatches(sentence).toList();
  if (runs.isEmpty) return [FuriganaSegment(sentence)];
  final pattern = StringBuffer('^');
  var cursor = 0;
  for (final run in runs) {
    pattern.write(
      RegExp.escape(_normalizedKana(sentence.substring(cursor, run.start))),
    );
    pattern.write('(.+?)');
    cursor = run.end;
  }
  pattern.write(RegExp.escape(_normalizedKana(sentence.substring(cursor))));
  pattern.write(r'$');
  final match = RegExp(pattern.toString()).firstMatch(_normalizedKana(reading));
  if (match == null) return [FuriganaSegment(sentence)];
  final segments = <FuriganaSegment>[];
  cursor = 0;
  for (var index = 0; index < runs.length; index++) {
    final run = runs[index];
    if (cursor < run.start) {
      segments.add(FuriganaSegment(sentence.substring(cursor, run.start)));
    }
    segments.add(FuriganaSegment(run.group(0)!, match.group(index + 1)!));
    cursor = run.end;
  }
  if (cursor < sentence.length) {
    segments.add(FuriganaSegment(sentence.substring(cursor)));
  }
  return segments;
}
