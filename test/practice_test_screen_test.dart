import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/data/models/app_state.dart';
import 'package:jlpt_practice/data/models/jlpt_test_schedule.dart';
import 'package:jlpt_practice/data/models/mock_test.dart';
import 'package:jlpt_practice/data/models/mock_test_problem.dart';
import 'package:jlpt_practice/features/test/mock_test_providers.dart';
import 'package:jlpt_practice/features/test/mock_test_result_screen.dart';
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
              scheduleId: '2025-july-n5',
            )).overrideWith(
              (ref) async => GeneratedPracticeSet(
                items: _problems.where((p) => p.section == section).toList(),
                vocabularyQuestions: const [],
              ),
            ),
            jlptTestSchedulesForLevelProvider(
              'N5',
            ).overrideWith((ref) async => _schedules),
          ],
        );
        addTearDown(container.dispose);
        await container.read(appControllerProvider.future);

        final router = GoRouter(
          initialLocation: '/test/practice/N5/2025-july-n5/$segment',
          routes: [
            GoRoute(
              path: '/test/practice/N5/2025-july-n5/$segment',
              builder: (_, _) => PracticeTestScreen(
                level: 'N5',
                scheduleId: '2025-july-n5',
                section: section,
              ),
            ),
            GoRoute(
              path: '/test/practice/N5/2025-july-n5/$segment/result',
              builder: (_, _) => MockTestResultScreen(
                retryPath: '/test/practice/N5/2025-july-n5/$segment',
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
          await tester.pump(const Duration(milliseconds: 2300));
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

final _schedules = [
  JlptTestSchedule(
    id: '2025-july-n5',
    year: 2025,
    session: 'July',
    examDate: DateTime(2025, 7, 6),
    level: 'N5',
    displayName: 'JLPT N5 · July 2025',
  ),
];

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
];
