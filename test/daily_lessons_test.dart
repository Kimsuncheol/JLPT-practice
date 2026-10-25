import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/app/theme/app_theme.dart';
import 'package:jlpt_practice/core/api/daily_lesson_service.dart';
import 'package:jlpt_practice/core/api/jlpt_api_client.dart';
import 'package:jlpt_practice/core/services/tts_service.dart';
import 'package:jlpt_practice/data/models/app_state.dart';
import 'package:jlpt_practice/data/models/daily_lesson.dart';
import 'package:jlpt_practice/data/models/study_preferences.dart';
import 'package:jlpt_practice/features/daily_lessons/daily_lesson_screens.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> _article({
  String id = 'opaque-123',
  String date = '2026-01-01',
}) => {
  'id': id,
  'status': 'ready',
  'date': date,
  'title': '일본어 표현',
  'url': 'https://example.test/source/$id',
  'lesson': {
    'expressions': [
      {
        'japanese': '努力する',
        'reading': 'どりょくする',
        'translation': '노력하다',
        'explanation': '꾸준히 힘쓰는 것을 뜻합니다.',
        'examples': [
          {
            'japanese': '毎日勉強します。',
            'reading': 'まいにちべんきょうします。',
            'translation': '매일 공부합니다.',
          },
          {'japanese': 'そうですね。', 'translation': '그렇네요.'},
        ],
      },
    ],
    'notes': ['학습 노트'],
    'uncertain_text': ['원문 확인'],
  },
};

Map<String, dynamic> _page({
  int page = 1,
  List<Map<String, dynamic>>? articles,
}) => {
  'articles': articles ?? [_article()],
  'page': page,
  'pages': 2,
  'total': 11,
};

http.Response _json(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'date labels use publication date; optional source fields can be absent',
    () {
      final lesson = DailyLesson.fromJson(_article());
      expect(lesson.publishedToday(DateTime(2026, 1, 1)), isTrue);
      expect(lesson.publishedToday(DateTime(2026, 1, 2)), isFalse);
      final source = _article();
      (source['lesson'] as Map)['expressions'] = [
        {'japanese': 'こんにちは'},
      ];
      expect(DailyLesson.fromJson(source).expressions.first.reading, isEmpty);
      source['status'] = 'pending';
      expect(() => DailyLesson.fromJson(source), throwsFormatException);
    },
  );

  test(
    'requests ready articles with correctly encoded Japanese/Korean search',
    () async {
      final service = DailyLessonService(
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.path, '/api/articles');
          expect(request.url.queryParameters, {
            'page': '2',
            'status': 'ready',
            'q': '努力 노력 &',
          });
          return _json(_page(page: 2));
        }),
      );
      addTearDown(service.close);
      final values = await service.pages(page: 2, query: ' 努力 노력 & ').toList();
      expect(
        values.single.value.lessons.first.expressions.first.translation,
        '노력하다',
      );
    },
  );

  test(
    'saved pages and their lesson details survive a service restart offline',
    () async {
      final online = DailyLessonService(
        client: MockClient((_) async => _json(_page())),
      );
      await online.pages().toList();
      online.close();
      final offline = DailyLessonService(
        client: MockClient((_) async => throw http.ClientException('offline')),
      );
      addTearDown(offline.close);
      final pages = await offline.pages().toList();
      expect(pages.length, 2);
      expect(pages.first.saved, isTrue);
      expect(pages.last.offline, isTrue);
      final details = await offline.lesson('opaque-123').toList();
      expect(details.first.value.expressions.first.japanese, '努力する');
      expect(details.last.offline, isTrue);
    },
  );

  test(
    'cache emits immediately then updates with fresh server content',
    () async {
      var date = '2026-01-01';
      final service = DailyLessonService(
        client: MockClient(
          (_) async => _json(_page(articles: [_article(date: date)])),
        ),
      );
      addTearDown(service.close);
      await service.pages().toList();
      date = '2026-01-02';
      final results = await service.pages().toList();
      expect(results.first.value.lessons.first.date, '2026-01-01');
      expect(results.last.value.lessons.first.date, '2026-01-02');
      expect(results.last.saved, isFalse);
    },
  );

  for (final response in [
    http.Response('<h1>Not Found</h1>', 404),
    http.Response('not json', 200),
    _json({'articles': []}),
  ]) {
    test(
      'uncached invalid response fails instead of presenting a lesson: ${response.body}',
      () async {
        final service = DailyLessonService(
          client: MockClient((_) async => response),
        );
        addTearDown(service.close);
        await expectLater(service.pages(), emitsError(anything));
      },
    );
  }

  test('timeouts preserve saved content and cache stays bounded', () async {
    final service = DailyLessonService(
      client: MockClient((_) async => _json(_page())),
    );
    for (var i = 0; i < 35; i++) {
      await service.pages(query: '$i').toList();
    }
    await service.pages().toList();
    service.close();
    final preferences = await SharedPreferences.getInstance();
    expect(
      preferences
          .getKeys()
          .where((k) => k.startsWith('daily_lessons_v1:'))
          .length,
      30,
    );
    final timedOut = DailyLessonService(
      timeout: const Duration(milliseconds: 1),
      client: MockClient((_) => Completer<http.Response>().future),
    );
    addTearDown(timedOut.close);
    expect((await timedOut.pages().toList()).last.offline, isTrue);
  });

  for (final language in ['en', 'ko']) {
    testWidgets('home → browse → detail → TTS → contextual tutor ($language)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <http.Request>[];
      final source = DailyLessonService(
        client: MockClient((request) async {
          requests.add(request);
          return _json(
            request.url.path == '/api/articles' ? _page() : _article(),
          );
        }),
      );
      final tutorRequests = <Map<String, dynamic>>[];
      final tutor = JlptApiClient(
        baseUrl: 'https://tutor.test',
        client: MockClient((request) async {
          tutorRequests.add(jsonDecode(request.body) as Map<String, dynamic>);
          return _json({
            'reply': 'Explanation of 努力する',
            'follow_up_questions': ['Why?', 'When?', 'How?'],
          });
        }),
      );
      addTearDown(source.close);
      addTearDown(tutor.close);
      final tts = _FakeTts();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(
              body: SingleChildScrollView(child: LatestExpressionCard()),
            ),
          ),
          GoRoute(
            path: '/daily-lessons',
            builder: (_, _) => const DailyLessonListScreen(),
          ),
          GoRoute(
            path: '/daily-lessons/:id',
            builder: (_, state) =>
                DailyLessonDetailScreen(id: state.pathParameters['id']!),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dailyLessonServiceProvider.overrideWithValue(source),
            jlptApiClientProvider.overrideWithValue(tutor),
            appControllerProvider.overrideWith(_FakeController.new),
            ttsServiceProvider.overrideWithValue(tts),
          ],
          child: MaterialApp.router(
            theme: language == 'ko' ? AppTheme.dark() : AppTheme.light(),
            locale: Locale(language),
            supportedLocales: const [Locale('en'), Locale('ko')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(language == 'en' ? 'Latest expression' : '최신 표현'),
        findsOneWidget,
      );
      // Direct home-card navigation opens detail.
      await tester.tap(find.text('努力する'));
      await tester.pumpAndSettle();
      expect(find.text('꾸준히 힘쓰는 것을 뜻합니다.'), findsOneWidget);
      router.pop();
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(language == 'en' ? 'Browse lessons' : '레슨 둘러보기'),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '努力');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();
      expect(requests.last.url.queryParameters['q'], '努力');
      await tester.tap(find.byIcon(Icons.chevron_right).last);
      await tester.pumpAndSettle();
      expect(requests.last.url.queryParameters['page'], '2');
      await tester.tap(find.text('努力する'));
      await tester.pumpAndSettle();
      final expressionSection = find.byKey(
        const ValueKey('lesson_expression_0'),
      );
      final conversationSection = find.byKey(
        const ValueKey('lesson_conversation_0'),
      );
      expect(expressionSection, findsOneWidget);
      expect(conversationSection, findsOneWidget);
      for (var turn = 0; turn < 2; turn++) {
        final avatar = find.byKey(ValueKey('lesson_speaker_$turn'));
        final bubble = find.byKey(ValueKey('lesson_bubble_$turn'));
        expect(
          tester.widget<CircleAvatar>(avatar).child,
          isA<Text>().having(
            (text) => text.data,
            'speaker',
            turn == 0 ? 'A' : 'B',
          ),
        );
        final avatarRect = tester.getRect(avatar);
        final bubbleRect = tester.getRect(bubble);
        expect(avatarRect.top, greaterThan(bubbleRect.bottom));
        if (turn == 0) {
          expect(bubbleRect.left, greaterThan(avatarRect.right));
        } else {
          expect(bubbleRect.right, lessThan(avatarRect.left));
        }
        expect(
          avatarRect.center.dx,
          turn == 0
              ? lessThan(bubbleRect.center.dx)
              : greaterThan(bubbleRect.center.dx),
        );
      }
      expect(
        find.descendant(of: expressionSection, matching: conversationSection),
        findsNothing,
      );
      expect(
        find.text(language == 'en' ? 'Play audio' : '음성 재생'),
        findsNothing,
      );
      final expressionSpeech = find.byKey(const ValueKey('lesson_speech_努力する'));
      tts.playback = Completer<void>();
      await tester.ensureVisible(expressionSpeech);
      await tester.tap(expressionSpeech);
      await tester.pumpAndSettle();
      expect(tts.spoken, ['どりょくする']);
      // A second tap on the active sentence stops playback.
      await tester.tap(expressionSpeech);
      await tester.pumpAndSettle();
      expect(tts.stopped, isTrue);
      final exampleSpeech = find.byKey(
        const ValueKey('lesson_speech_毎日勉強します。'),
      );
      await tester.ensureVisible(exampleSpeech);
      await tester.tap(exampleSpeech);
      await tester.pumpAndSettle();
      expect(tts.spoken, ['どりょくする', 'まいにちべんきょうします。']);
      final expressionTutor = find.descendant(
        of: expressionSection,
        matching: find.text(language == 'en' ? 'Ask AI Tutor' : 'AI 튜터에게 질문'),
      );
      await Scrollable.ensureVisible(
        tester.element(expressionTutor),
        alignment: 0.5,
      );
      await tester.pumpAndSettle();
      await tester.tap(expressionTutor);
      await tester.pumpAndSettle();
      expect(tutorRequests.single['question']['question_text'], '努力する');
      expect(tutorRequests.single['explanation_language'], 'Korean');
      expect(tutorRequests.single['level'], 'N4');
      expect(find.textContaining('Explanation of 努力する'), findsWidgets);
      expect(tts.stopped, isTrue);
      expect(tester.takeException(), isNull);
    });
  }
}

class _FakeTts implements TtsService {
  final spoken = <String>[];
  var stopped = false;
  Completer<void>? playback;
  @override
  Future<void> speak(String text) async {
    spoken.add(text);
    await playback?.future;
  }

  @override
  Future<void> stop() async {
    stopped = true;
    if (playback != null && !playback!.isCompleted) playback!.complete();
    playback = null;
  }

  @override
  Future<void> dispose() async {}
  @override
  Future<void> speakDialogue(List<DialogueTurn> turns) async {}
}

class _FakeController extends AppController {
  @override
  Future<AppState> build() async => const AppState(
    vocabulary: [],
    progress: {},
    onboardingComplete: true,
    selectedLevel: 'N4',
    languageCode: 'en',
    meaningLanguageMode: 'ko',
    meaningLanguage: 'ko',
    dailyGoal: 10,
    showFurigana: true,
    autoPlayAudio: false,
    themeMode: ThemeMode.light,
    ttsVolumeMode: TtsVolumeMode.slider,
    ttsVolume: 0.5,
    notificationsEnabled: false,
    studySeconds: 0,
    quizAnswered: 0,
    quizCorrect: 0,
    currentStreak: 0,
    longestStreak: 0,
  );
}
