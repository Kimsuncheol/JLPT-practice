import 'dart:math';

import 'package:jlpt_practice/data/models/kanji.dart';
import 'package:jlpt_practice/data/models/vocabulary.dart';

/// A single blank in the displayed example, using its actual inflected answer.
class ShortQuiz {
  const ShortQuiz({
    required this.entry,
    required this.start,
    required this.end,
    required this.answer,
    required this.options,
  });

  final Vocabulary entry;
  final int start;
  final int end;
  final String answer;
  final List<String> options;
  static const placeholder = '\uFFFC';

  bool grade(String selected) =>
      options.contains(selected) && selected == answer;

  List<FuriganaSegment> get segments {
    final result = <FuriganaSegment>[];
    var offset = 0;
    var inserted = false;
    for (final segment in entry.example.sentenceSegments) {
      final segmentEnd = offset + segment.text.length;
      if (segmentEnd <= start || offset >= end) {
        result.add(segment);
      } else {
        // A partial ruby run cannot retain its original reading: it may reveal
        // the missing answer or annotate the remaining text incorrectly.
        if (offset < start) {
          result.add(
            FuriganaSegment(segment.text.substring(0, start - offset)),
          );
        }
        if (!inserted) {
          result.add(const FuriganaSegment(placeholder));
          inserted = true;
        }
        if (segmentEnd > end) {
          result.add(FuriganaSegment(segment.text.substring(end - offset)));
        }
      }
      offset = segmentEnd;
    }
    return result;
  }
}

ShortQuiz? buildShortQuiz(
  Vocabulary entry,
  List<Vocabulary> candidates, {
  Random? random,
}) {
  final example = entry.example;
  final blank = RegExp(r'[＿_]+').firstMatch(example.quizSentence);
  var answer = example.answer.trim();
  int start;
  if (blank != null && answer.isNotEmpty) {
    final prefix = example.quizSentence.substring(0, blank.start);
    final suffix = example.quizSentence.substring(blank.end);
    if ('$prefix$answer$suffix' != example.sentence) return null;
    start = prefix.length;
  } else {
    answer = entry.word.trim();
    start = example.sentence.indexOf(answer);
    if (answer.isEmpty || start < 0) return null;
  }
  final rng = random ?? Random();
  final preferred =
      candidates
          .where(
            (item) =>
                item.id != entry.id && item.partOfSpeech == entry.partOfSpeech,
          )
          .map(
            (item) => item.example.answer.trim().isNotEmpty
                ? item.example.answer.trim()
                : item.word.trim(),
          )
          .where((option) => option.isNotEmpty && option != answer)
          .toSet()
          .toList()
        ..shuffle(rng);
  final fallback =
      candidates
          .where((item) => item.id != entry.id)
          .map(
            (item) => item.example.answer.trim().isNotEmpty
                ? item.example.answer.trim()
                : item.word.trim(),
          )
          .where((option) => option.isNotEmpty && option != answer)
          .toSet()
          .toList()
        ..shuffle(rng);
  final distractors = <String>{
    ...example.distractors
        .map((option) => option.trim())
        .where((option) => option.isNotEmpty && option != answer),
    ...preferred,
    ...fallback,
  }.take(3);
  final options = [answer, ...distractors]..shuffle(rng);
  if (options.length < 2) return null;
  return ShortQuiz(
    entry: entry,
    start: start,
    end: start + answer.length,
    answer: answer,
    options: List.unmodifiable(options),
  );
}
