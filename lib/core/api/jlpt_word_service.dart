import 'package:jlpt_practice/core/api/jlpt_api_client.dart';

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
              _text(example['japanese']),
              _text(example['reading']),
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
          '✓ ${_text(contrast['natural_example'])}\n'
              '✗ ${_text(contrast['unnatural_example'])}\n${_text(contrast['explanation'])}',
        );
      }
      // Keep server-provided exam references in a separate section from AI examples.
      final sources = _optionalObjects(data['verified_past_exam_examples']);
      if (sources.isEmpty) {
        sections.add(const WordExplanationSection('wordPastExamExamples', ''));
      }
      for (final source in sources) {
        if (source['source_type'] != 'past_exam' ||
            source['verified_from_curated_collection'] != true ||
            source['ai_generated'] != false) {
          throw const FormatException();
        }
        section(
          'wordPastExamExamples',
          [
            _text(source['japanese']),
            if (source['reading'] != null) _text(source['reading']),
            _text(source['source_title']),
            _text(source['source_reference']),
            if (source['exam_year'] != null) source['exam_year'].toString(),
            if (source['exam_level'] != null) _text(source['exam_level']),
            if (source['question_or_page_ref'] != null)
              _text(source['question_or_page_ref']),
            if (source['source_url'] != null) _text(source['source_url']),
          ].join('\n'),
        );
      }
      section('wordDifficulty', data['approximate_difficulty_label']);
      section('wordNotice', data['notice']);
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
