import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jlpt_practice/core/api/jlpt_api_client.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/core/services/local_store.dart';
import 'package:jlpt_practice/data/models/grammar_point.dart';
import 'package:jlpt_practice/features/grammar/grammar_part_tutor_screen.dart';
import 'package:jlpt_practice/features/grammar/grammar_providers.dart';
import 'package:jlpt_practice/features/grammar/grammar_tutor_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('rank tutor loads intro from API and sends grammar follow-up', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final requests = <Map<String, dynamic>>[];
    final client = JlptApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((request) async {
        expect(request.url.path, '/api/tutor/chat');
        requests.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response(
          jsonEncode({
            'follow_up_questions': ['What is another example?'],
            'reply': requests.length == 1
                ? 'Grammar introduction'
                : 'Sentence feedback',
          }),
          200,
        );
      }),
    );
    addTearDown(client.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          grammarCatalogProvider.overrideWith((_) async => _items),
          jlptApiClientProvider.overrideWithValue(client),
        ],
        child: const MaterialApp(home: GrammarTutorScreen(grammarId: 'N5_1')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Practise with AI'), findsOneWidget);
    expect(find.byType(AiChatWidget), findsOneWidget);
    expect(requests, hasLength(1));
    expect(
      (requests.single['question'] as Map)['passage'],
      contains(_target.explanation),
    );
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
    await tester.enterText(find.byType(TextField), '寿司が一番好きです。');
    await tester.tap(find.byKey(const ValueKey('grammar_practice_send')));
    await tester.pumpAndSettle();
    expect(requests, hasLength(2));
    expect(requests.last['history'], hasLength(2));
    expect(
      (await LocalStore.create()).loadGrammarStudySessions()['N5']!.grammarId,
      'N5_1',
    );
  });

  testWidgets('part checkpoint diagnoses multiple ranks', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [grammarCatalogProvider.overrideWith((_) async => _items)],
        child: const MaterialApp(
          home: GrammarPartTutorScreen(level: 'N5', part: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      (await LocalStore.create()).loadGrammarStudySessions()['N5']!.route,
      '/grammar/part/N5/1',
    );
    expect(find.text('Question 1/2'), findsOneWidget);
    await tester.tap(find.textContaining(_target.title));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pump();

    expect(find.text('Question 2/2'), findsOneWidget);
    await tester.tap(find.textContaining(_distractor.title));
    await tester.pump();
    await tester.tap(find.text('See results'));
    await tester.pumpAndSettle();

    expect(find.text('Part checkpoint complete'), findsOneWidget);
    expect(find.text('Strong'), findsOneWidget);
  });
}

const _items = [_target, _distractor];

const _target = GrammarPoint(
  id: 'N5_1',
  level: 'N5',
  rank: 1,
  title: 'A が いちばん～',
  summary: 'Expresses the superlative.',
  explanation: 'Use it to say that something is the most in a group.',
  formation: 'Noun + が + いちばん',
  examples: [
    GrammarExample(
      japanese: '寿司が一番好きです。',
      reading: 'すしがいちばんすきです。',
      english: 'I like sushi the most.',
    ),
  ],
);

const _distractor = GrammarPoint(
  id: 'N5_2',
  level: 'N5',
  rank: 2,
  title: '～てもいい',
  summary: 'Expresses permission.',
  explanation: 'Use it to give permission.',
  formation: 'Verb て-form + もいい',
  examples: [
    GrammarExample(
      japanese: 'ここに座ってもいいです。',
      reading: 'ここにすわってもいいです。',
      english: 'You may sit here.',
    ),
  ],
);
