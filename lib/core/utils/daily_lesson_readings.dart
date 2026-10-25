import 'package:jlpt_practice/core/utils/furigana_alignment.dart';
import 'package:jlpt_practice/data/models/kanji.dart';

// Source transcriptions use both "A：…" and "A …" dialogue labels.
final dailyLessonSpeakerPrefix = RegExp(r'^\s*([ABＡＢ])(?:\s*[:：]\s*|\s+)');
final _kanji = RegExp(r'[㐀-䶿一-鿿々〆ヵヶ]+');
final _kana = RegExp(r'^[ぁ-ゖァ-ヺー]+$');
final _foreignPronunciationNote = RegExp(
  r'\s*[（(][^()（）]*[가-힣][^()（）]*[）)]\s*$',
);

// Sentence-specific corrections for malformed readings in the source archive.
// Keep Japanese unchanged; never infer an unknown name's pronunciation.
const _readingCorrections = {
  '本人は気付いていないようですね。': 'ほんにんはきづいていないようですね。',
  '昨日は久しぶりに旧友と会って、とりとめのない話をして楽しかったわ。':
      'きのうはひさしぶりにきゅうゆうとあって、とりとめのないはなしをしてたのしかったわ。',
};

/// Clean auxiliary Korean pronunciation notes before aligning kana anchors.
/// Exact corrections fill known gaps, including cached pre-fix API responses.
/// Unrecognized malformed readings stay unannotated instead of guessing ruby.
String dailyLessonReading(String japanese, String reading) {
  final sentence = japanese.replaceFirst(dailyLessonSpeakerPrefix, '');
  final candidate = reading
      .replaceFirst(dailyLessonSpeakerPrefix, '')
      .replaceFirst(_foreignPronunciationNote, '')
      .trim();
  if (candidate.isNotEmpty && !RegExp(r'[가-힣A-Za-z㐀-鿿]').hasMatch(candidate)) {
    final segments = alignSentenceFurigana(sentence, candidate);
    if (segments.every(
      (segment) =>
          !_kanji.hasMatch(segment.text) ||
          (segment.ruby != null && _kana.hasMatch(segment.ruby!)),
    )) {
      return candidate;
    }
  }
  return _readingCorrections[sentence] ?? '';
}

List<FuriganaSegment> dailyLessonSegments(String japanese, String reading) {
  final prefix = dailyLessonSpeakerPrefix.firstMatch(japanese)?.group(0) ?? '';
  return [
    if (prefix.isNotEmpty) FuriganaSegment(prefix),
    ...alignSentenceFurigana(
      japanese.substring(prefix.length),
      dailyLessonReading(japanese, reading),
    ),
  ];
}
