import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/services/tts_service.dart';
import 'package:jlpt_practice/data/models/app_state.dart';
import 'package:jlpt_practice/data/models/kanji.dart';
import 'package:jlpt_practice/data/models/study_session.dart';

/// Records what would be spoken, and when speech was stopped.
class KanjiTestAppController extends AppController {
  KanjiTestAppController({
    this.autoPlayAudio = false,
    this.completed = const {},
    this.sessions = const {},
    this.exampleFontScale = 1,
  });

  final bool autoPlayAudio;
  final Map<String, Set<int>> completed;
  final Map<String, StudySession> sessions;
  final double exampleFontScale;
  final List<(String, int)> completions = [];
  final List<StudySession> savedSessions = [];

  @override
  Future<AppState> build() async => AppState(
    vocabulary: const [],
    progress: const {},
    onboardingComplete: true,
    selectedLevel: 'N5',
    languageCode: 'system',
    meaningLanguageMode: 'en',
    meaningLanguage: 'en',
    dailyGoal: 2,
    showFurigana: true,
    autoPlayAudio: autoPlayAudio,
    exampleFontScale: exampleFontScale,
    themeMode: ThemeMode.system,
    notificationsEnabled: false,
    studySeconds: 0,
    quizAnswered: 0,
    quizCorrect: 0,
    currentStreak: 0,
    longestStreak: 0,
    completedStudyDays: completed,
    studySessions: sessions,
  );

  @override
  Future<void> completeStudySession(String level, int day) async =>
      completions.add((level, day));

  @override
  Future<void> saveStudySession(StudySession session) async {
    savedSessions.add(session);
    final current = state.requireValue;
    state = AsyncData(
      current.copyWith(
        studySessions: {...current.studySessions, session.level: session},
      ),
    );
  }
}

final kanjiTestCatalog = [
  Kanji.fromJson({
    'kanji': '一',
    'jlpt': 'N5',
    'hun': ['한'],
    'eum': ['일'],
    'strokes': 1,
    'kun_yomi': ['ひと-', 'ひと.つ'],
    'on_yomi': ['いち', 'いつ', 'イチ'],
    'kun_examples': [
      {
        'word': '一つ',
        'reading': 'ひとつ',
        'meaning_ko': '하나',
        'meaning_en': 'one thing',
        'sentence_jp': 'りんごを一つください。',
        'sentence_furigana': 'りんごを{一|ひと}つください。',
        'sentence_ko': '사과를 하나 주세요.',
      },
    ],
    'on_examples': [
      {
        'word': '一部',
        'reading': 'いちぶ',
        'meaning_ko': '일부',
        'meaning_en': 'part',
        'sentence_jp': '一部が遅れた。',
        'sentence_furigana': '{一部|いちぶ}が{遅|おく}れた。',
        'sentence_ko': '일부가 늦었다.',
      },
    ],
  }),
  Kanji.fromJson({
    'kanji': '二',
    'jlpt': 'N5',
    'hun': ['두'],
    'eum': ['이'],
    'strokes': 2,
    'kun_yomi': <String>[],
    'on_yomi': ['に'],
    'kun_examples': <Object>[],
    'on_examples': <Object>[],
  }),
  Kanji.fromJson({
    'kanji': '三',
    'jlpt': 'N5',
    'hun': ['석'],
    'eum': ['삼'],
    'strokes': 3,
    'kun_yomi': ['み'],
    'on_yomi': ['さん'],
    'kun_examples': <Object>[],
    'on_examples': <Object>[],
  }),
  Kanji.fromJson({
    'kanji': '日',
    'jlpt': 'N4',
    'hun': ['날'],
    'eum': ['일'],
    'strokes': 4,
    'kun_yomi': ['ひ'],
    'on_yomi': ['にち'],
    'kun_examples': <Object>[],
    'on_examples': <Object>[],
  }),
];

class RecordingTtsService implements TtsService {
  final spoken = <String>[];
  final events = <String>[];

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
    events.add('speak:$text');
  }

  @override
  Future<void> speakDialogue(List<DialogueTurn> turns) async {}

  @override
  Future<void> stop() async => events.add('stop');

  @override
  Future<void> dispose() async {}
}
