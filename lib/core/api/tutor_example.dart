import 'dart:convert';
import 'package:jlpt_practice/data/models/kanji.dart';

/// A validated sentence; Markdown is never used to infer its kanji readings.
class TutorExample {
  const TutorExample({
    required this.japanese,
    required this.sentenceFurigana,
    required this.translation,
  });

  factory TutorExample.fromJson(Map<String, dynamic> json) {
    String text(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty || value.length > 6000) {
        throw const FormatException('Invalid tutor example field');
      }
      return value.trim();
    }

    final result = TutorExample(
      japanese: text('japanese'),
      sentenceFurigana: text('sentence_furigana'),
      translation: text('translation'),
    );
    final segments = result.segments;
    if (segments.map((s) => s.text).join() != result.japanese ||
        segments.any(
          (s) => s.ruby == null
              ? RegExp(r'[㐀-䶿一-鿿々〆{}|]').hasMatch(s.text)
              : !RegExp(r'^[㐀-䶿一-鿿々〆]+$').hasMatch(s.text) ||
                    !RegExp(r'^[ぁ-ゖー]+$').hasMatch(s.ruby!),
        )) {
      throw const FormatException('Incomplete tutor furigana');
    }
    return result;
  }

  final String japanese, sentenceFurigana, translation;
  List<FuriganaSegment> get segments => parseFurigana(sentenceFurigana);
  Map<String, String> toJson() => {
    'japanese': japanese,
    'sentence_furigana': sentenceFurigana,
    'translation': translation,
  };

  // App-owned code blocks are rendered as sentence widgets, never as source code.
  String get markdownBlock =>
      '\n\n```jlpt-example\n${jsonEncode(toJson())}\n```\n\n';
}
