import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/core/services/local_store.dart';
import 'package:jlpt_practice/data/models/grammar_point.dart';
import 'package:jlpt_practice/features/grammar/grammar_part_tutor_screen.dart';
import 'package:jlpt_practice/features/grammar/grammar_practice_service.dart';
import 'package:jlpt_practice/features/grammar/grammar_providers.dart';
import 'package:jlpt_practice/features/grammar/grammar_tutor_screen.dart';
import 'package:jlpt_practice/features/offline_ai/offline_ai_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('rank tutor opens Gemma-backed practice chat', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = _PracticeService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          grammarCatalogProvider.overrideWith((_) async => _items),
          grammarPracticeServiceProvider.overrideWith((_) async => service),
        ],
        child: const MaterialApp(home: GrammarTutorScreen(grammarId: 'N5_1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      (await LocalStore.create()).loadGrammarStudySessions()['N5']!.route,
      '/grammar/tutor/N5_1',
    );
    expect(find.text('Practise with AI'), findsOneWidget);
    expect(find.byType(AiChatWidget), findsOneWidget);
    expect(find.text('Check my understanding'), findsNothing);
    expect(find.text(_target.explanation), findsNothing);
    expect(find.text(_target.formation), findsNothing);
    expect(
      find.byKey(const ValueKey('chat_suggestions_container')),
      findsOneWidget,
    );

    final pending = Completer<String>();
    service.nextAnswer = pending;
    await tester.tap(find.text('Give me a practice task'));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('chat_suggestions_container')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('chat_suggestions_scroll')),
      findsOneWidget,
    );
    expect(
      tester
          .widgetList<ActionChip>(find.byType(ActionChip))
          .every((chip) => chip.onPressed == null),
      isTrue,
    );
    pending.complete('Write a sentence using A が いちばん～.');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AiChatWidget>(find.byType(AiChatWidget))
          .controller
          .messages
          .map((message) => message.text),
      contains('Write a sentence using A が いちばん～.'),
    );

    await tester.enterText(find.byType(TextField), '寿司が一番好きです。');
    await tester.tap(find.byKey(const ValueKey('grammar_practice_send')));
    await tester.pumpAndSettle();
    expect(service.messages, ['Give me a practice task', '寿司が一番好きです。']);
    expect(service.practiceTaskRequests, [true, false]);
    expect(service.histories.last, hasLength(2));
    expect(
      tester
          .widget<AiChatWidget>(find.byType(AiChatWidget))
          .controller
          .messages
          .map((message) => message.text),
      contains('Practice reply'),
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

class _PracticeService extends GrammarPracticeService {
  _PracticeService() : super(_UnusedOfflineAiController());

  final List<String> messages = [];
  final List<bool> practiceTaskRequests = [];
  final List<List<GrammarPracticeTurn>> histories = [];
  Completer<String>? nextAnswer;

  @override
  Future<String> reply({
    required GrammarPoint grammar,
    required String message,
    required String languageCode,
    required List<GrammarPracticeTurn> history,
    bool practiceTask = false,
  }) async {
    messages.add(message);
    practiceTaskRequests.add(practiceTask);
    histories.add(history);
    final pending = nextAnswer;
    nextAnswer = null;
    return pending?.future ?? 'Practice reply';
  }
}

class _UnusedOfflineAiController extends Fake implements OfflineAiController {}

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
