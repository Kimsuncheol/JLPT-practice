import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
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
    await tester.pump();
    await tester.pump();
    await tester.pump();

    expect(
      (await LocalStore.create()).loadGrammarStudySessions()['N5']!.route,
      '/grammar/tutor/N5_1',
    );
    expect(find.text('Practise with AI'), findsOneWidget);
    expect(find.byType(AiChatWidget), findsOneWidget);
    expect(find.text('Check my understanding'), findsNothing);
    expect(find.text(_target.explanation), findsNothing);
    expect(find.text(_target.formation), findsNothing);
    expect(find.byType(ActionChip), findsNothing);
    final session = service.model.sessions.single;
    expect(session.queries, hasLength(1));
    expect(jsonDecode(session.queries.first)['practiceTask'], isTrue);
    expect(jsonDecode(session.queries.first)['title'], _target.title);
    await tester.pump();
    expect(session.queries, hasLength(1));
    expect(
      tester
          .widget<AiChatWidget>(find.byType(AiChatWidget))
          .controller
          .messages,
      isEmpty,
    );
    expect(
      find.byKey(const ValueKey('chat_suggestions_container')),
      findsNothing,
    );
    expect(find.byKey(const ValueKey('chat_suggestions_scroll')), findsNothing);
    final chat = tester.widget<AiChatWidget>(find.byType(AiChatWidget));
    final loadingBubble = tester.widget<Container>(
      find.byKey(const ValueKey('chat_ai_loading_bubble')),
    );
    final decoration = loadingBubble.decoration! as BoxDecoration;
    expect(decoration.color, chat.messageOptions!.bubbleStyle!.aiBubbleColor);
    expect(
      decoration.borderRadius,
      const BorderRadius.only(
        topLeft: Radius.circular(2),
        topRight: Radius.circular(22),
        bottomLeft: Radius.circular(22),
        bottomRight: Radius.circular(22),
      ),
    );
    session.responses.first.add('Write a sentence using A が いちばん～.');
    await tester.pump();
    expect(find.byType(ActionChip), findsNothing);
    expect(
      tester
          .widget<AiChatWidget>(find.byType(AiChatWidget))
          .controller
          .messages
          .where((message) => message.user.id == 'user'),
      isEmpty,
    );
    await session.responses.first.close();
    await tester.pumpAndSettle();
    expect(find.byType(ActionChip), findsNWidgets(3));
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
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
    await tester.enterText(find.byType(TextField), 'もう一つの文です。');
    await tester.tap(find.byKey(const ValueKey('grammar_practice_send')));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '三番目の文です。');
    await tester.tap(find.byKey(const ValueKey('grammar_practice_send')));
    await tester.pump();
    expect(session.queries, hasLength(2));
    expect(find.textContaining('2 waiting'), findsOneWidget);
    expect(
      tester
          .widget<AiChatWidget>(find.byType(AiChatWidget))
          .controller
          .messages
          .map((message) => message.text),
      contains('もう一つの文です。'),
    );
    session.responses[1].add('Practice reply');
    await session.responses[1].close();
    await tester.pump();
    expect(session.queries, hasLength(3));
    expect(jsonDecode(session.queries.last)['message'], 'もう一つの文です。');
    expect(find.textContaining('1 waiting'), findsOneWidget);
    session.responses[2].add('Second reply');
    await session.responses[2].close();
    await tester.pump();
    expect(session.queries, hasLength(4));
    expect(jsonDecode(session.queries.last)['message'], '三番目の文です。');
    expect(find.textContaining('1 waiting'), findsNothing);
    session.responses[3].add('Third reply');
    await session.responses[3].close();
    await tester.pumpAndSettle();
    expect(service.model.sessions, hasLength(1));
    expect(session.queries, hasLength(4));
    expect(
      tester
          .widget<AiChatWidget>(find.byType(AiChatWidget))
          .controller
          .messages
          .map((message) => message.text),
      contains('Practice reply'),
    );
    expect(
      tester
          .widget<AiChatWidget>(find.byType(AiChatWidget))
          .controller
          .messages
          .map((message) => message.text),
      contains('Second reply'),
    );
    expect(
      tester
          .widget<AiChatWidget>(find.byType(AiChatWidget))
          .controller
          .messages
          .map((message) => message.text),
      contains('Third reply'),
    );
  });

  testWidgets(
    'leaving during generation closes the session and re-entry is idle',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final service = _PracticeService();
      Widget screen() => ProviderScope(
        overrides: [
          grammarCatalogProvider.overrideWith((_) async => _items),
          grammarPracticeServiceProvider.overrideWith((_) async => service),
        ],
        child: const MaterialApp(home: GrammarTutorScreen(grammarId: 'N5_1')),
      );
      await tester.pumpWidget(screen());
      await tester.pump();
      await tester.pump();
      await tester.pump();
      final oldSession = service.model.sessions.single;
      expect(find.byType(ActionChip), findsNothing);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
      await tester.enterText(find.byType(TextField), '寿司が一番好きです。');
      await tester.tap(find.byKey(const ValueKey('grammar_practice_send')));
      await tester.pump();
      expect(find.textContaining('1 waiting'), findsOneWidget);
      expect(oldSession.queries, hasLength(1));
      expect(
        find.byKey(const ValueKey('chat_ai_loading_bubble')),
        findsOneWidget,
      );

      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      expect(oldSession.closed, isTrue);
      await tester.pumpWidget(screen());
      await tester.pump();
      await tester.pump();
      expect(
        find.byKey(const ValueKey('chat_ai_loading_bubble')),
        findsOneWidget,
      );
      expect(find.byType(ActionChip), findsNothing);
      expect(find.textContaining('waiting'), findsNothing);
      expect(service.model.sessions, hasLength(2));
      expect(service.model.sessions.last, isNot(same(oldSession)));
      expect(service.model.sessions.last.queries, hasLength(1));
    },
  );

  testWidgets('stream failure clears busy state', (tester) async {
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
    await tester.pump();
    await tester.pump();
    await tester.pump();
    service.model.sessions.single.responses.single.addError(
      StateError('failed'),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('The local model could not finish'),
      findsWidgets,
    );
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.byType(ActionChip), findsNothing);
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
  _PracticeService() : super(_FakeController());
  _FakeModel get model => (controller as _FakeController).model;
}

class _FakeController extends Fake implements OfflineAiController {
  final model = _FakeModel();
  @override
  Future<InferenceModel> getLoadedModel() async => model;
}

class _FakeModel extends Fake implements InferenceModel {
  @override
  final List<_FakeSession> sessions = [];
  @override
  Future<InferenceModelSession> openSession({
    double temperature = .8,
    int randomSeed = 1,
    int topK = 1,
    double? topP,
    String? loraPath,
    bool? enableVisionModality,
    bool? enableAudioModality,
    String? systemInstruction,
    bool enableThinking = false,
    List<Tool> tools = const [],
    int? maxOutputTokens,
  }) async {
    final session = _FakeSession();
    sessions.add(session);
    return session;
  }
}

class _FakeSession extends Fake implements InferenceModelSession {
  final queries = <String>[];
  final responses = <StreamController<String>>[];
  bool closed = false;

  @override
  Future<void> addQueryChunk(Message message) async =>
      queries.add(message.text);

  @override
  Stream<String> getResponseAsync() {
    final response = StreamController<String>();
    responses.add(response);
    return response.stream;
  }

  @override
  Future<void> close() async {
    closed = true;
  }
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
