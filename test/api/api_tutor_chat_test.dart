import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_gen_ai_chat_ui/flutter_gen_ai_chat_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jlpt_practice/core/api/jlpt_api_client.dart';
import 'package:jlpt_practice/shared/api_tutor_chat.dart';

void main() {
  testWidgets('failed suggestion generation preserves the successful reply', (
    tester,
  ) async {
    var calls = 0;
    final client = JlptApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((_) async {
        calls++;
        return calls == 1
            ? http.Response('{"reply":"A successful explanation."}', 200)
            : http.Response('unavailable', 503);
      }),
    );
    addTearDown(client.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [jlptApiClientProvider.overrideWithValue(client)],
        child: const MaterialApp(
          home: ApiTutorChat(
            title: 'Tutor',
            icon: Icons.school,
            hint: 'Ask',
            suggestionKeys: [],
            closeKey: ValueKey('close'),
            level: 'N5',
            language: 'en',
            contextData: {'question_text': 'は'},
            initialMessage: 'Explain',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.byType(GptMarkdown), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
  });

  testWidgets(
    'AI-generated suggestions load inside the reply footer and send their text',
    (tester) async {
      final requests = <Map>[];
      final suggestions = Completer<http.Response>();
      final client = JlptApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          final data = jsonDecode(request.body) as Map;
          requests.add(data);
          if (requests.length == 1) {
            return http.Response(
              '{"reply":"Use this grammar for permission."}',
              200,
            );
          }
          if (requests.length == 2) {
            return suggestions.future;
          }
          return http.Response(
            '{"reply":"Another example.","follow_up_questions":["How formal is it?"]}',
            200,
          );
        }),
      );
      addTearDown(client.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [jlptApiClientProvider.overrideWithValue(client)],
          child: const MaterialApp(
            home: ApiTutorChat(
              title: 'Tutor',
              icon: Icons.school,
              hint: 'Ask',
              suggestionKeys: ['giveExample'],
              closeKey: ValueKey('close'),
              level: 'N5',
              language: 'ko',
              contextData: {'question_text': 'てもいい'},
              initialMessage: 'Explain',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(requests, hasLength(2));
      expect(requests.last['message'], contains('Write them in Korean'));
      expect(requests.last['history'], hasLength(2));
      expect(find.byType(GptMarkdown), findsOneWidget);
      expect(find.text('Give me another example'), findsNothing);
      suggestions.complete(
        http.Response(
          jsonEncode({
            'reply': '["When can I use it?", "Can you give an example?"]',
          }),
          200,
        ),
      );
      await tester.pumpAndSettle();
      final suggestion = find.text('Can you give an example?');
      expect(suggestion, findsOneWidget);
      expect(
        find.ancestor(
          of: suggestion,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget.key is ValueKey<String> &&
                (widget.key as ValueKey<String>).value.startsWith('followups_'),
          ),
        ),
        findsOneWidget,
      );
      await tester.tap(suggestion);
      await tester.pumpAndSettle();
      expect(requests, hasLength(3));
      expect(requests.last['message'], 'Can you give an example?');
      expect(requests.last['history'], hasLength(2));
      expect(find.text('How formal is it?'), findsOneWidget);
    },
  );

  testWidgets(
    'send and old-reply suggestion taps pin the newest content after manual scrolling',
    (tester) async {
      addTearDown(tester.view.resetViewInsets);
      var calls = 0;
      final second = Completer<http.Response>();
      final third = Completer<http.Response>();
      http.Response answer(int index) => http.Response(
        jsonEncode({
          'reply': List.filled(
            30,
            'Example line for this grammar.',
          ).join('\n\n'),
          'follow_up_questions': ['Follow-up $index?'],
        }),
        200,
      );
      final client = JlptApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((_) async {
          calls++;
          return calls == 1
              ? answer(1)
              : calls == 2
              ? second.future
              : third.future;
        }),
      );
      addTearDown(client.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [jlptApiClientProvider.overrideWithValue(client)],
          child: const MaterialApp(
            home: ApiTutorChat(
              title: 'Tutor',
              icon: Icons.school,
              hint: 'Ask',
              suggestionKeys: [],
              closeKey: ValueKey('close'),
              level: 'N5',
              language: 'en',
              contextData: {'question_text': 'は'},
              initialMessage: 'Explain',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scroll = tester
          .widget<AiChatWidget>(find.byType(AiChatWidget))
          .scrollController!;
      expect(
        scroll.position.pixels,
        closeTo(scroll.position.maxScrollExtent, 1),
      );
      await tester.drag(find.byType(AiChatWidget), const Offset(0, 400));
      await tester.pumpAndSettle();
      expect(scroll.position.extentAfter, greaterThan(100));
      tester.view.viewInsets = const FakeViewPadding(bottom: 180);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Typed question');
      await tester.tap(find.widgetWithIcon(IconButton, Icons.send_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        scroll.position.pixels,
        closeTo(scroll.position.maxScrollExtent, 1),
      );
      tester.view.resetViewInsets();
      await tester.pump();
      second.complete(answer(2));
      await tester.pumpAndSettle();
      expect(
        scroll.position.pixels,
        closeTo(scroll.position.maxScrollExtent, 1),
      );
      await tester.drag(find.byType(AiChatWidget), const Offset(0, 500));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Follow-up 1?'),
        -200,
        scrollable: find
            .descendant(
              of: find.byType(AiChatWidget),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(scroll.position.extentAfter, greaterThan(100));
      await Scrollable.ensureVisible(
        tester.element(find.text('Follow-up 1?')),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Follow-up 1?').hitTestable());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        scroll.position.pixels,
        closeTo(scroll.position.maxScrollExtent, 1),
      );
      third.complete(answer(3));
      await tester.pumpAndSettle();
      expect(
        scroll.position.pixels,
        closeTo(scroll.position.maxScrollExtent, 1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'unsupported context shows recoverable error instead of a build failure',
    (tester) async {
      final client = JlptApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((_) async {
          fail('Invalid context must not reach the network');
        }),
      );
      addTearDown(client.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [jlptApiClientProvider.overrideWithValue(client)],
          child: MaterialApp(
            home: ApiTutorChat(
              title: 'Tutor',
              icon: Icons.school,
              hint: 'Ask',
              suggestionKeys: const [],
              closeKey: const ValueKey('close'),
              level: 'N5',
              language: 'en',
              contextBuilder: () =>
                  throw const JlptApiException('aiRequestInvalid'),
              initialMessage: 'Explain',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Try again'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failure retains draft; retry succeeds once; busy input cannot duplicate requests',
    (tester) async {
      var calls = 0;
      final pending = Completer<http.Response>();
      final payloads = <Map>[];
      final client = JlptApiClient(
        baseUrl: 'https://example.test',
        client: MockClient((request) async {
          calls++;
          payloads.add(jsonDecode(request.body) as Map);
          if (calls == 1) return http.Response('busy', 503);
          return pending.future;
        }),
      );
      addTearDown(client.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [jlptApiClientProvider.overrideWithValue(client)],
          child: const MaterialApp(
            home: ApiTutorChat(
              title: 'Tutor',
              icon: Icons.school,
              hint: 'Ask',
              suggestionKeys: ['giveExample'],
              closeKey: ValueKey('close'),
              level: 'N5',
              language: 'en',
              contextData: {'question_text': 'は'},
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'When do I use は?');
      await tester.tap(find.widgetWithIcon(IconButton, Icons.send_rounded));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'When do I use は?',
      );
      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      tester
          .widget<AiChatWidget>(find.byType(AiChatWidget))
          .onSendMessage(
            ChatMessage(
              text: 'duplicate',
              user: const ChatUser(id: 'user'),
              createdAt: DateTime.now(),
            ),
          );
      expect(calls, 2);
      pending.complete(
        http.Response(
          '{"reply":"Use it for the topic.","follow_up_questions":["Another example?"]}',
          200,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        payloads.every((payload) => (payload['history'] as List).isEmpty),
        isTrue,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(
        find.text('Use it for the topic.', findRichText: true),
        findsOneWidget,
      );
      expect(find.byType(GptMarkdown), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    },
  );

  testWidgets('closing during a request avoids late UI writes', (tester) async {
    final pending = Completer<http.Response>();
    final client = JlptApiClient(
      baseUrl: 'https://example.test',
      client: MockClient((_) => pending.future),
    );
    addTearDown(client.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [jlptApiClientProvider.overrideWithValue(client)],
        child: const MaterialApp(
          home: ApiTutorChat(
            title: 'Tutor',
            icon: Icons.school,
            hint: 'Ask',
            suggestionKeys: [],
            closeKey: ValueKey('close'),
            level: 'N5',
            language: 'en',
            contextData: {'question_text': 'は'},
            initialMessage: 'Explain',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    pending.complete(http.Response('{"reply":"Late reply"}', 200));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
