import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/data/models/app_state.dart';
import 'package:jlpt_practice/data/models/mock_test.dart';
import 'package:jlpt_practice/data/models/mock_test_problem.dart';
import 'package:jlpt_practice/features/test/mock_test_providers.dart';
import 'package:jlpt_practice/features/test/mock_test_result_screen.dart';
import 'package:jlpt_practice/features/test/practice_ai_tutor_service.dart';
import 'package:jlpt_practice/features/test/practice_test_screen.dart';

void main() {
  for (final section in ProblemSection.values) {
    testWidgets(
      'answering a ${section.name} practice test reaches a result screen',
      (tester) async {
        final segment = sectionPathSegment(section);
        final container = ProviderContainer(
          overrides: [
            appControllerProvider.overrideWith(_FakeAppController.new),
            generatedPracticeSetProvider((
              level: 'N5',
              practiceNumber: 1,
            )).overrideWith(
              (ref) async => GeneratedPracticeSet(
                items: _problems.where((p) => p.section == section).toList(),
                vocabularyQuestions: const [],
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        await container.read(appControllerProvider.future);

        final router = GoRouter(
          initialLocation: '/test/practice/N5/$segment/practice-1',
          routes: [
            GoRoute(
              path: '/test/practice/N5/$segment/practice-1',
              builder: (_, _) => PracticeTestScreen(
                level: 'N5',
                section: section,
                practiceNumber: 1,
              ),
            ),
            GoRoute(
              path: '/test/practice/N5/$segment/practice-1/result',
              builder: (_, _) => MockTestResultScreen(
                retryPath: '/test/practice/N5/$segment/practice-1',
              ),
            ),
            GoRoute(
              path: '/home',
              builder: (_, _) => const Scaffold(body: Text('Home')),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final expectedCount = _problems
            .where((p) => p.section == section)
            .length;
        const firstChoiceKey = ValueKey('practice_test_choice_0');
        for (var i = 0; i < expectedCount; i++) {
          expect(find.byKey(firstChoiceKey), findsOneWidget);
          await tester.tap(find.byKey(firstChoiceKey));
          await tester.pumpAndSettle();
          for (var choiceIndex = 0; choiceIndex < 4; choiceIndex++) {
            expect(
              find.byKey(ValueKey('practice_test_choice_$choiceIndex')),
              findsNothing,
            );
          }
          expect(
            find.byKey(const ValueKey('practice_feedback')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('practice_ask_ai_tutor')),
            findsOneWidget,
          );
          final continueButton = find.byKey(
            const ValueKey('practice_continue'),
          );
          await tester.ensureVisible(continueButton);
          await tester.tap(continueButton);
          await tester.pumpAndSettle();
        }
        await tester.pump(const Duration(seconds: 1));

        expect(tester.takeException(), isNull);
        expect(find.text('Test complete'), findsOneWidget);

        final result = container
            .read(appControllerProvider)
            .requireValue
            .lastMockTestResult!;
        expect(result.total, expectedCount);
      },
    );
  }

  testWidgets('AI Tutor preserves the stored explanation and opens guidance', (
    tester,
  ) async {
    final tutor = _FakePracticeAiTutorEvaluator();
    final container = ProviderContainer(
      overrides: [
        appControllerProvider.overrideWith(_FakeAppController.new),
        generatedPracticeSetProvider((
          level: 'N5',
          practiceNumber: 1,
        )).overrideWith(
          (ref) async => GeneratedPracticeSet(
            items: [_problems[2]],
            vocabularyQuestions: const [],
          ),
        ),
        practiceAiTutorProvider.overrideWith((ref) async => tutor),
      ],
    );
    addTearDown(container.dispose);
    await container.read(appControllerProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: PracticeTestScreen(
            level: 'N5',
            section: ProblemSection.reading,
            practiceNumber: 1,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('practice_test_choice_0')));
    await tester.pumpAndSettle();

    expect(find.text('The passage says 7 o\'clock.'), findsOneWidget);
    expect(find.byKey(const ValueKey('practice_continue')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('practice_ask_ai_tutor')));
    await tester.pumpAndSettle();

    expect(find.text('AI Tutor'), findsOneWidget);
    expect(find.text('The passage explicitly gives the time.'), findsOneWidget);
    expect(find.text('“7じ”'), findsOneWidget);
    expect(find.byKey(const ValueKey('practice_ai_continue')), findsOneWidget);

    const question = 'Can you explain that more simply?';
    await tester.enterText(
      find.byKey(const ValueKey('practice_ai_chat_input')),
      question,
    );
    await tester.tap(find.byKey(const ValueKey('practice_ai_chat_send')));
    await tester.pumpAndSettle();

    expect(find.text(question), findsOneWidget);
    expect(find.text('Here is a simpler chat reply.'), findsOneWidget);
    expect(tutor.histories.single, isEmpty);

    const secondQuestion = 'What should I notice first?';
    await tester.enterText(
      find.byKey(const ValueKey('practice_ai_chat_input')),
      secondQuestion,
    );
    await tester.tap(find.byKey(const ValueKey('practice_ai_chat_send')));
    await tester.pumpAndSettle();

    expect(tutor.histories, hasLength(2));
    expect(tutor.histories.last, hasLength(2));
    expect(tutor.histories.last.first.text, question);
    expect(tutor.histories.last.last.text, 'Here is a simpler chat reply.');

    await tester.tap(find.byKey(const ValueKey('practice_ai_close')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('practice_ask_ai_tutor')));
    await tester.pumpAndSettle();

    expect(find.text(question), findsNothing);
    expect(find.text(secondQuestion), findsNothing);
    expect(
      find.byKey(const ValueKey('practice_ai_chat_input')),
      findsOneWidget,
    );
    expect(
      find.text('This conversation is deleted when you close it.'),
      findsOneWidget,
    );
  });
}

class _FakePracticeAiTutorEvaluator implements PracticeAiTutorEvaluator {
  final List<List<PracticeTutorMessage>> histories = [];

  @override
  Future<PracticeTutorFeedback> explain({
    required MockTestProblem problem,
    required String selectedAnswer,
    required String explanationLanguage,
    PracticeTutorFocus focus = PracticeTutorFocus.overview,
  }) async => const PracticeTutorFeedback(
    summary: 'The passage explicitly gives the time.',
    whyCorrect: 'The person wakes at 7.',
    whySelectedIsWrong: 'The selected time is not in the passage.',
    keyEvidence: ['7じ'],
    learningPoints: ['Look for time expressions.'],
  );

  @override
  Future<String> ask({
    required MockTestProblem problem,
    required String selectedAnswer,
    required String explanationLanguage,
    required List<PracticeTutorMessage> history,
    required String question,
  }) async {
    histories.add(List<PracticeTutorMessage>.of(history));
    return 'Here is a simpler chat reply.';
  }
}

class _FakeAppController extends AppController {
  @override
  Future<AppState> build() async {
    return AppState(
      vocabulary: const [],
      progress: const {},
      onboardingComplete: true,
      selectedLevel: 'N5',
      languageCode: 'system',
      meaningLanguage: 'en',
      dailyGoal: 10,
      showFurigana: true,
      autoPlayAudio: false,
      themeMode: ThemeMode.system,
      notificationsEnabled: false,
      studySeconds: 0,
      quizAnswered: 0,
      quizCorrect: 0,
      currentStreak: 0,
      longestStreak: 0,
    );
  }

  @override
  Future<void> recordMockTestResult(
    MockTestResult result, {
    required List<dynamic> vocabularyQuestions,
  }) async {
    state = AsyncData(state.requireValue.copyWith(lastMockTestResult: result));
  }
}

const _problems = [
  MockTestProblem(
    id: 'n5-vocab-01',
    level: 'N5',
    section: ProblemSection.vocabulary,
    passage: '',
    question: 'あさ、＿＿＿をたべます。',
    choices: ['パン', 'くつ', 'かさ', 'つくえ'],
    correctAnswer: 'パン',
    explanationEn: 'Bread fits the context.',
    explanationKo: '빵이 알맞습니다.',
  ),
  MockTestProblem(
    id: 'n5-grammar-01',
    level: 'N5',
    section: ProblemSection.grammar,
    passage: '',
    question: 'わたし＿＿＿がくせいです。',
    choices: ['は', 'を', 'に', 'で'],
    correctAnswer: 'は',
    explanationEn: "'は' marks the topic.",
    explanationKo: "'は'는 주제를 나타냅니다.",
  ),
  MockTestProblem(
    id: 'n5-reading-a-1',
    level: 'N5',
    section: ProblemSection.reading,
    passage: 'たなかさんはまいあさ7じにおきます。',
    question: 'たなかさんは なんじに おきますか。',
    choices: ['6じ', '7じ', '8じ', '9じ'],
    correctAnswer: '7じ',
    explanationEn: 'The passage says 7 o\'clock.',
    explanationKo: '본문에 7시라고 나와 있습니다.',
  ),
  MockTestProblem(
    id: 'n5-listening-a-1',
    level: 'N5',
    section: ProblemSection.listening,
    passage: 'M：コーヒーとお茶、どちらがいいですか。\nF：お茶をお願いします。',
    question: '女の人は何を頼みましたか。',
    choices: ['コーヒー', 'お茶', '水', 'ジュース'],
    correctAnswer: 'お茶',
    explanationEn: 'The woman asks for tea (お茶).',
    explanationKo: '여자는 차(お茶)를 부탁했습니다.',
  ),
];
