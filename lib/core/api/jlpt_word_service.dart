import 'package:jlpt_practice/core/api/jlpt_api_client.dart';
import 'package:jlpt_practice/core/utils/furigana_alignment.dart';
import 'package:jlpt_practice/data/models/kanji.dart';

class WordExplanationSection {
  const WordExplanationSection(this.titleKey, this.text);
  final String titleKey;
  final String text;
}

class WordExplanation {
  const WordExplanation({
    required this.word,
    required this.reading,
    required this.sections,
    required this.followUpQuestions,
    required this.tutorContext,
  });
  final String word, reading;
  final List<WordExplanationSection> sections;
  final List<String> followUpQuestions;
  final Map<String, dynamic> tutorContext;
}

/// Stateless word explanations. No storage, logging, retries or suggestion calls.
class JlptWordService {
  const JlptWordService(this.client);
  final JlptApiClient client;

  Future<WordExplanation> explain({
    required String word,
    required String context,
    required String level,
    required String language,
  }) async {
    word = word.trim();
    context = context.trim();
    if (word.isEmpty ||
        word.runes.length > 100 ||
        context.runes.length > 500 ||
        !const ['N5', 'N4', 'N3', 'N2', 'N1'].contains(level)) {
      throw const JlptApiException('aiRequestInvalid');
    }
    final data = await client.request(
      '/api/words/explain',
      body: {
        'word': word,
        if (context.isNotEmpty) 'context': context,
        'level': level,
        'explanation_language': explanationLanguage(language),
      },
    );
    try {
      final reading = _text(data['reading']);
      final questions = _texts(data['follow_up_questions']);
      final normalized = questions
          .map((q) => q.toLowerCase().replaceAll(RegExp(r'\s+'), ' '))
          .toSet();
      if (questions.length != 3 ||
          normalized.length != 3 ||
          questions.any((q) => q.runes.length > 500)) {
        throw const FormatException();
      }
      final meanings = _objects(data['meanings']);
      if (meanings.isEmpty || meanings.length > 4) {
        throw const FormatException();
      }
      final sections = <WordExplanationSection>[];
      void section(String key, Object? value) {
        if (value != null) {
          final text = _text(value);
          sections.add(WordExplanationSection(key, text));
        }
      }

      section(
        'wordAlternateReadings',
        _optionalTexts(data['alternate_readings']).join(' · ').nullIfEmpty,
      );
      section('wordUncertainty', data['uncertainty_note']);
      section('wordContextFit', data['context_fit_explanation']);
      for (final meaning in meanings) {
        section(
          'wordMeanings',
          '${_text(meaning['meaning'])}\n${_text(meaning['part_of_speech'])}',
        );
        section('wordContextFit', meaning['context_fit']);
        section(
          'wordCollocations',
          _optionalTexts(meaning['collocations']).join(' · ').nullIfEmpty,
        );
        section(
          'wordGrammarPatterns',
          _optionalTexts(meaning['grammar_patterns']).join('\n').nullIfEmpty,
        );
        for (final example in _objects(meaning['examples'])) {
          section(
            'wordOriginalExamples',
            [
              _exampleSentence(example),
              _text(example['translation']),
              _text(example['usage_note']),
            ].join('\n'),
          );
        }
      }
      final nuances = _texts(data['nuances']);
      if (nuances.isEmpty) throw const FormatException();
      section('wordNuances', nuances.join('\n\n'));
      section('wordRegister', data['register_and_formality']);
      for (final comparison in _optionalObjects(
        data['synonyms_and_contrasts'],
      )) {
        section(
          'wordSynonyms',
          '${_text(comparison['term'])}\n${_text(comparison['comparison'])}',
        );
      }
      for (final contrast in _optionalObjects(data['natural_vs_unnatural'])) {
        section(
          'wordUsageContrast',
          '✓ ${_exampleSentence(contrast, japaneseKey: 'natural_example', furiganaKey: 'natural_example_furigana', readingKey: null)}\n'
              '✗ ${_exampleSentence(contrast, japaneseKey: 'unnatural_example', furiganaKey: 'unnatural_example_furigana', readingKey: null)}\n${_text(contrast['explanation'])}',
        );
      }
      return WordExplanation(
        word: word,
        reading: reading,
        sections: List.unmodifiable(sections),
        followUpQuestions: List.unmodifiable(questions),
        tutorContext: {
          'question_text': boundedText('$word ($reading)\n$context', 500),
          'passage': boundedText(
            [
              for (final meaning in meanings) _text(meaning['meaning']),
              ...nuances,
            ].join('\n'),
            800,
          ),
        },
      );
    } on FormatException {
      throw const JlptApiException('aiResponseInvalid');
    }
  }
}

String _text(Object? value) {
  if (value is! String || value.trim().isEmpty || value.length > 20000) {
    throw const FormatException();
  }
  return value.trim();
}

List<String> _texts(Object? value) {
  if (value is! List) throw const FormatException();
  return value.map(_text).toList();
}

List<String> _optionalTexts(Object? value) =>
    value == null ? [] : _texts(value);
List<Map<String, dynamic>> _objects(Object? value) {
  if (value is! List) throw const FormatException();
  return value.map((item) {
    if (item is! Map<String, dynamic>) throw const FormatException();
    return item;
  }).toList();
}

List<Map<String, dynamic>> _optionalObjects(Object? value) =>
    value == null ? [] : _objects(value);

extension on String {
  String? get nullIfEmpty => isEmpty ? null : this;
}

/// Preserve server annotations; older deployments provide a full kana reading.
String _exampleSentence(
  Map<String, dynamic> example, {
  String japaneseKey = 'japanese',
  String furiganaKey = 'sentence_furigana',
  String? readingKey = 'reading',
}) {
  final japanese = _text(example[japaneseKey]);
  final marked = example[furiganaKey];
  if (marked != null) {
    final annotation = _text(marked);
    final segments = parseFurigana(annotation);
    if (segments.map((s) => s.text).join() != japanese ||
        segments.any(
          (s) => s.ruby == null
              ? RegExp(r'[㐀-䶿一-鿿々〆{}|]').hasMatch(s.text)
              : !RegExp(r'^[㐀-䶿一-鿿々〆]+$').hasMatch(s.text) ||
                    !RegExp(r'^[ぁ-ゖー]+$').hasMatch(s.ruby!),
        )) {
      throw const FormatException();
    }
    return annotation;
  }
  if (readingKey == null) return japanese;
  final reading = _text(example[readingKey]);
  final segments = alignSentenceFurigana(japanese, reading);
  if (!segments.any((s) => s.ruby != null)) {
    return '$japanese\n$reading';
  }
  return segments
      .map((s) => s.ruby == null ? s.text : '{${s.text}|${s.ruby}}')
      .join();
}
