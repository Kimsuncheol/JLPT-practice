import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jlpt_practice/core/api/jlpt_api_client.dart';
import 'package:jlpt_practice/core/api/jlpt_tutor_service.dart';

const example = {
  'japanese': '週末は映画を見ます。',
  'sentence_furigana': '{週末|しゅうまつ}は{映画|えいが}を{見|み}ます。',
  'translation': 'I watch a movie on the weekend.',
};

void main() {
  Future<TutorReply> fetch(Map<String, dynamic> data) {
    final client = JlptApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        expect(jsonDecode(request.body)['structured_examples'], isTrue);
        return http.Response(
          jsonEncode(data),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    addTearDown(client.close);
    return JlptTutorService(client).fetchReply(
      practiceItem: false,
      structuredExamples: true,
      level: 'N4',
      language: 'en',
      context: const {},
      message: 'Explain とか',
      history: const [],
    );
  }

  Map<String, dynamic> response({
    Object? examples = const [example],
    String reply = 'Examples\n\n[[example:1]]',
  }) => {
    'reply': reply,
    'examples': examples,
    'follow_up_questions': ['Why?', 'When?', 'How?'],
  };

  test(
    'structured examples become whole-sentence widgets with separate translations',
    () async {
      final result = await fetch(response());
      expect(result.text, contains('```jlpt-example'));
      expect(result.text, contains(example['sentence_furigana']!));
      expect(result.text, isNot(contains('[[example:')));
      expect(result.followUpQuestions, hasLength(3));
    },
  );

  test(
    'missing or malformed readings and misplaced markers cannot silently display plain text',
    () async {
      for (final data in [
        response(examples: null),
        response(examples: []),
        response(
          examples: [
            {...example, 'sentence_furigana': '週末は{映画|えいが}を{見|み}ます。'},
          ],
        ),
        response(
          examples: [
            {...example, 'sentence_furigana': '{週末|しゅうまつ}は{映画|えいが}を{見ます|みます}。'},
          ],
        ),
        response(
          examples: [
            {...example, 'sentence_furigana': '{週末|しゅうまつ}は{映画|えいが}を{見|み}ました。'},
          ],
        ),
        response(reply: 'Example without marker'),
        response(reply: '[[example:2]]'),
        response(reply: '[[example:1]] [[example:unknown]]'),
        response(reply: '[[example:1]] [[example:1]]'),
      ]) {
        await expectLater(
          fetch(data),
          throwsA(
            isA<JlptApiException>().having(
              (e) => e.messageKey,
              'error',
              'aiResponseInvalid',
            ),
          ),
        );
      }
    },
  );
}
