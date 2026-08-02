import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/data/models/app_state.dart';
import 'package:jlpt_practice/data/models/study_session.dart';
import 'package:jlpt_practice/data/models/vocabulary.dart';
import 'package:jlpt_practice/features/dashboard/dashboard_screen.dart';
import 'package:jlpt_practice/features/vocabulary/study_screen.dart';

void main() {
  testWidgets('restores the saved word when reopening a study day', (
    tester,
  ) async {
    final container = _createContainer();
    addTearDown(container.dispose);
    await container.read(appControllerProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: StudyScreen(day: 1)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('3 / 5'), findsOneWidget);
    expect(find.text('単語3'), findsOneWidget);
  });

  testWidgets('dashboard offers the saved study session', (tester) async {
    final container = _createContainer();
    addTearDown(container.dispose);
    await container.read(appControllerProvider.future);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(body: DashboardScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Resume learning'), findsOneWidget);
    expect(find.text('Day 1 · 3/5'), findsOneWidget);
  });
}

ProviderContainer _createContainer() => ProviderContainer(
  overrides: [appControllerProvider.overrideWith(_ResumeAppController.new)],
);

class _ResumeAppController extends AppController {
  @override
  Future<AppState> build() async {
    return AppState(
      vocabulary: List.generate(5, _word),
      progress: const {},
      onboardingComplete: true,
      selectedLevel: 'N5',
      languageCode: 'system',
      meaningLanguage: 'en',
      dailyGoal: 5,
      showFurigana: true,
      autoPlayAudio: false,
      themeMode: ThemeMode.system,
      notificationsEnabled: false,
      studySeconds: 0,
      quizAnswered: 0,
      quizCorrect: 0,
      currentStreak: 0,
      longestStreak: 0,
      studySessions: {
        'N5': StudySession(
          level: 'N5',
          day: 1,
          wordId: 'word_2',
          indexFallback: 2,
          dailyGoal: 5,
          updatedAt: DateTime.utc(2026, 8, 2),
        ),
      },
    );
  }

  @override
  Future<void> saveStudySession(StudySession session) async {
    final current = state.requireValue;
    state = AsyncData(
      current.copyWith(
        studySessions: {...current.studySessions, session.level: session},
      ),
    );
  }
}

Vocabulary _word(int index) => Vocabulary(
  id: 'word_$index',
  word: '単語${index + 1}',
  reading: 'たんご',
  furigana: 'たんご',
  romaji: 'tango',
  meanings: const {
    'en': ['word'],
  },
  partOfSpeech: 'word',
  jlptLevel: 'N5',
  tags: const ['JLPT'],
  example: const VocabularyExample(
    sentence: '',
    reading: '',
    translations: {},
    quizSentence: '',
    answer: '',
  ),
  rank: index + 1,
);
