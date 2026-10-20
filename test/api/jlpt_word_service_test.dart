import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jlpt_practice/core/api/jlpt_api_client.dart';
import 'package:jlpt_practice/core/api/jlpt_word_service.dart';

Map<String, dynamic> wordResponse() => {
  'reading': 'じゅんび',
  'meanings': [
    {
      'meaning': 'Preparation',
      'part_of_speech': 'Noun / する verb',
      'examples': [
        {
          'japanese': '旅行の準備をする。',
          'reading': 'りょこうのじゅんびをする。',
          'translation': 'Prepare for a trip.',
          'usage_note': 'Used with をする.',
        },
      ],
    },
  ],
  'nuances': ['Practical preparations in advance.'],
  'follow_up_questions': ['How is it used?', 'What is 用意?', 'Another example?'],
  'verified_past_exam_examples': [],
};

void main() {
  test(
    'word request uses exact endpoint, normalized language and one call',
    () async {
      var calls = 0;
      final client = JlptApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          calls++;
          expect(request.method, 'POST');
          expect(request.url.path, '/api/words/explain');
          expect(jsonDecode(request.body), {
            'word': '準備',
            'context': '旅行の準備',
            'level': 'N4',
            'explanation_language': 'Korean',
          });
          return _jsonResponse(jsonEncode(wordResponse()), 200);
        }),
      );
      addTearDown(client.close);
      final result = await JlptWordService(
        client,
      ).explain(word: ' 準備 ', context: ' 旅行の準備 ', level: 'N4', language: 'ko');
      expect(calls, 1);
      expect(result.reading, 'じゅんび');
      expect(result.followUpQuestions, hasLength(3));
      expect(
        result.sections
            .where((s) => s.titleKey == 'wordOriginalExamples')
            .single
            .text,
        contains('Prepare for a trip.'),
      );
      expect(
        result.sections.where((s) => s.titleKey == 'wordPastExamExamples'),
        isEmpty,
      );
      expect(result.tutorContext['question_text'], contains('準備'));
      expect(result.tutorContext['passage'], contains('Preparation'));
    },
  );

  test('server furigana is preserved and malformed annotations fail', () async {
    for (final marked in [
      '{旅行|りょこう}の{準備|じゅんび}をする。',
      '旅行の{準備|じゅんび}をする。',
      '{旅行|りょこう}の{準備|じゅんび}をした。',
    ]) {
      final data = wordResponse();
      data['meanings'][0]['examples'][0]['sentence_furigana'] = marked;
      final client = JlptApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((_) async => _jsonResponse(jsonEncode(data), 200)),
      );
      addTearDown(client.close);
      final result = JlptWordService(
        client,
      ).explain(word: '準備', context: '', level: 'N4', language: 'en');
      if (marked.startsWith('{旅行') && marked.endsWith('をする。')) {
        final explanation = await result;
        expect(
          explanation.sections
              .where((s) => s.titleKey == 'wordOriginalExamples')
              .single
              .text,
          startsWith(marked),
        );
      } else {
        await expectLater(result, throwsA(isA<JlptApiException>()));
      }
    }
  });

  for (final invalid in [
    null,
    ['One?'],
    ['Why?', ' WHY? ', 'How?'],
    ['One?', 'Two?', 'あ' * 501],
  ]) {
    test(
      'invalid follow-ups fail atomically without another call: $invalid',
      () async {
        var calls = 0;
        final client = JlptApiClient(
          baseUrl: 'https://example.test',
          client: MockClient((_) async {
            calls++;
            return _jsonResponse(
              jsonEncode({...wordResponse(), 'follow_up_questions': invalid}),
              200,
            );
          }),
        );
        addTearDown(client.close);
        await expectLater(
          JlptWordService(
            client,
          ).explain(word: '準備', context: '', level: 'N4', language: 'en'),
          throwsA(
            isA<JlptApiException>().having(
              (e) => e.messageKey,
              'key',
              'aiResponseInvalid',
            ),
          ),
        );
        expect(calls, 1);
      },
    );
  }

  test(
    'legacy metadata does not create excluded explanation sections',
    () async {
      final client = JlptApiClient(
        baseUrl: 'https://example.test',
        client: MockClient(
          (_) async => _jsonResponse(
            jsonEncode({
              ...wordResponse(),
              'approximate_difficulty_label': 'Approximate JLPT difficulty',
              'notice': 'Study notice',
              'verified_past_exam_examples': [
                {
                  'japanese': '準備してください。',
                  'reading': null,
                  'source_title': 'Curated archive',
                  'source_reference': 'Archive page 5',
                  'source_type': 'past_exam',
                  'verified_from_curated_collection': true,
                  'ai_generated': false,
                },
              ],
            }),
            200,
          ),
        ),
      );
      addTearDown(client.close);
      final result = await JlptWordService(
        client,
      ).explain(word: '準備', context: '', level: 'N4', language: 'en');
      expect(
        result.sections.where(
          (s) => const [
            'wordPastExamExamples',
            'wordDifficulty',
            'wordNotice',
          ].contains(s.titleKey),
        ),
        isEmpty,
      );
    },
  );

  test('oversized inputs are rejected before sending', () async {
    final client = JlptApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((_) async => throw StateError('Must not send')),
    );
    addTearDown(client.close);
    for (final word in ['', 'あ' * 101]) {
      await expectLater(
        JlptWordService(
          client,
        ).explain(word: word, context: '', level: 'N4', language: 'en'),
        throwsA(
          isA<JlptApiException>().having(
            (e) => e.messageKey,
            'key',
            'aiRequestInvalid',
          ),
        ),
      );
    }
  });
}

http.Response _jsonResponse(String body, int status) => http.Response(
  body,
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
