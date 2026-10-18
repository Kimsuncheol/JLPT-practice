import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jlpt_practice/core/api/jlpt_api_client.dart';
import 'package:jlpt_practice/core/api/jlpt_practice_service.dart';
import 'package:jlpt_practice/core/api/jlpt_tutor_service.dart';

void main() {
  test('structured follow-up questions are preserved and bounded', () async {
    final client = JlptApiClient(
      baseUrl: 'https://example.test',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'reply': 'Answer',
            'follow_up_questions': [
              '  Why?  ',
              '',
              2,
              'Why?',
              'How?',
              'あ' * 501,
              'When?',
              'Fourth?',
            ],
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    );
    addTearDown(client.close);
    final reply = await JlptTutorService(client).fetchReply(
      practiceItem: true,
      level: 'N5',
      language: 'en',
      context: {'question_text': 'は'},
      message: 'Explain',
      history: [],
    );
    expect(reply.text, 'Answer');
    expect(reply.followUpQuestions, ['Why?', 'How?', 'When?']);
  });

  for (final invalid in ['not JSON', '{"questions":["Why?"]}', '[1,null,""]']) {
    test('malformed suggestion output is ignored: $invalid', () async {
      final client = JlptApiClient(
        baseUrl: 'https://example.test',
        client: MockClient(
          (_) async => http.Response(jsonEncode({'reply': invalid}), 200),
        ),
      );
      addTearDown(client.close);
      expect(
        await JlptTutorService(client).suggestFollowUps(
          practiceItem: false,
          level: 'N5',
          language: 'en',
          context: {'question_text': 'は'},
          history: [],
        ),
        isEmpty,
      );
    });
  }

  test(
    'tutor sends selected item and six bounded prior turns without extra fields',
    () async {
      final client = JlptApiClient(
        baseUrl: 'https://example.test/',
        client: MockClient((request) async {
          expect(request.url.path, '/api/tutor');
          expect(request.headers['content-type'], 'application/json');
          final data = jsonDecode(request.body) as Map;
          expect(data.keys.toSet(), {
            'level',
            'explanation_language',
            'question',
            'message',
            'history',
          });
          expect(data['explanation_language'], 'Korean');
          expect(data['question'], {'question_text': '日本語です。'});
          expect(data['history'], hasLength(6));
          expect(data['history'][0]['content'], 'turn 4');
          expect(data['history'][5]['content'].runes.length, 500);
          return http.Response(
            jsonEncode({'reply': '좋아요.'}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(client.close);
      expect(
        await JlptTutorService(client).reply(
          practiceItem: true,
          level: 'N5',
          language: 'ko',
          context: {'question_text': '日本語です。'},
          message: '왜요?',
          history: [
            for (var i = 0; i < 10; i++)
              TutorTurn(isUser: i.isEven, text: i == 9 ? 'あ' * 700 : 'turn $i'),
          ],
        ),
        '좋아요.',
      );
    },
  );

  test(
    'grammar uses chat endpoint and UTF-8 request stays within server body limit',
    () async {
      final client = JlptApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          expect(request.url.path, '/api/tutor/chat');
          expect(request.bodyBytes.length, lessThanOrEqualTo(16384));
          return http.Response('{"reply":"ok"}', 200);
        }),
      );
      addTearDown(client.close);
      await JlptTutorService(client).reply(
        practiceItem: false,
        level: 'N1',
        language: 'en',
        context: {
          'question_text': 'あ' * 500,
          'passage': 'あ' * 800,
          'options': List.filled(4, 'あ' * 200),
        },
        message: 'あ' * 500,
        history: List.generate(
          6,
          (i) => TutorTurn(isUser: i.isEven, text: 'あ' * 500),
        ),
      );
    },
  );

  for (final (status, key) in [
    (429, 'aiServiceBusy'),
    (422, 'aiRequestInvalid'),
    (413, 'aiRequestInvalid'),
    (503, 'aiServiceUnavailable'),
    (504, 'aiServiceTimeout'),
  ]) {
    test('HTTP $status maps to localized recoverable error', () async {
      final client = JlptApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((_) async => http.Response('private error', status)),
      );
      addTearDown(client.close);
      await expectLater(
        client.request('/api/tutor', body: {}),
        throwsA(
          isA<JlptApiException>().having((e) => e.messageKey, 'key', key),
        ),
      );
    });
  }
  test('timeout and invalid JSON are recoverable', () async {
    final client = JlptApiClient(
      baseUrl: 'https://example.test',
      timeout: const Duration(milliseconds: 1),
      client: MockClient((_) => Completer<http.Response>().future),
    );
    addTearDown(client.close);
    await expectLater(
      client.health(),
      throwsA(
        isA<JlptApiException>().having(
          (e) => e.messageKey,
          'key',
          'aiServiceTimeout',
        ),
      ),
    );
    final malformed = JlptApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((_) async => http.Response('not json', 200)),
    );
    addTearDown(malformed.close);
    await expectLater(
      malformed.health(),
      throwsA(
        isA<JlptApiException>().having(
          (e) => e.messageKey,
          'key',
          'aiResponseInvalid',
        ),
      ),
    );
  });
  test('health checks only the server', () async {
    final client = JlptApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/health');
        return http.Response('{"status":"ok"}', 200);
      }),
    );
    addTearDown(client.close);
    expect(await client.health(), isTrue);
  });
  test(
    'batch practice keeps question choices, Korean explanations, and answer key aligned',
    () async {
      final client = JlptApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          expect(request.url.path, '/api/practice/generate');
          expect(jsonDecode(request.body), {
            'level': 'N5',
            'category': 'reading',
            'question_count': 1,
            'explanation_language': 'Korean',
          });
          return http.Response(
            jsonEncode(batch()),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(client.close);
      final item = (await JlptPracticeService(client).generate(
        level: 'N5',
        category: 'reading',
        language: 'ko',
        count: 1,
      )).single;
      expect(item.problem.correctAnswer, 'は');
      expect(item.problem.explanationKo, '한국어 해설');
      expect(item.problem.passage, '日本語の文章です。');
      expect(item.explanations, hasLength(4));
    },
  );
  test(
    'focused practice uses topic endpoint without unsupported language field',
    () async {
      final client = JlptApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          expect(request.url.path, '/api/practice/question');
          expect(jsonDecode(request.body), {
            'level': 'N5',
            'category': 'grammar',
            'topic': 'は',
          });
          return http.Response(
            jsonEncode({
              'level': 'N5',
              'category': 'grammar',
              'question': 'わたし（ ）学生です。',
              'options': ['は', 'を', 'に', 'で'],
              'correct_index': 0,
              'explanation': 'Use は.',
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(client.close);
      final item = (await JlptPracticeService(client).generate(
        level: 'N5',
        category: 'grammar',
        language: 'ko',
        topic: 'は',
      )).single;
      expect(item.problem.correctAnswer, 'は');
      expect(item.problem.explanationKo, isEmpty);
    },
  );
  for (final invalid in [
    'index',
    'choices',
    'count',
    'language',
    'passage',
    'answer',
  ]) {
    test('rejects malformed generated practice: $invalid', () async {
      final data = batch();
      final question = (data['questions'] as List).single as Map;
      switch (invalid) {
        case 'index':
          question['correct_index'] = -1;
        case 'choices':
          question['options'] = ['は', 'は', 'に', 'で'];
        case 'count':
          data['question_count'] = 2;
        case 'language':
          data['explanation_language'] = 'English';
        case 'passage':
          data['passage'] = '';
        case 'answer':
          question['correct_answer'] = 'に';
      }
      final client = JlptApiClient(
        baseUrl: 'https://example.test',
        client: MockClient(
          (_) async => http.Response(
            jsonEncode(data),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ),
        ),
      );
      addTearDown(client.close);
      await expectLater(
        JlptPracticeService(
          client,
        ).generate(level: 'N5', category: 'reading', language: 'ko', count: 1),
        throwsA(
          isA<JlptApiException>().having(
            (e) => e.messageKey,
            'key',
            'aiResponseInvalid',
          ),
        ),
      );
    });
  }
}

Map<String, dynamic> batch() => {
  'level': 'N5',
  'category': 'reading',
  'question_count': 1,
  'explanation_language': 'Korean',
  'passage': '日本語の文章です。',
  'questions': [
    {
      'id': 'test-id',
      'question_text': 'わたし（ ）学生です。',
      'options': ['は', 'を', 'に', 'で'],
      'correct_index': 0,
      'correct_answer': 'は',
      'option_explanations': ['한국어 해설', 'B', 'C', 'D'],
    },
  ],
};
