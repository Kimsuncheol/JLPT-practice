import 'package:flutter/material.dart';
import 'package:jlpt_practice/data/models/mock_test.dart';
import 'package:jlpt_practice/data/models/quiz.dart';
import 'package:jlpt_practice/data/models/review_progress.dart';
import 'package:jlpt_practice/data/models/study_preferences.dart';
import 'package:jlpt_practice/data/models/study_session.dart';
import 'package:jlpt_practice/data/models/vocabulary.dart';

class AppState {
  const AppState({
    required this.vocabulary,
    required this.progress,
    required this.onboardingComplete,
    required this.selectedLevel,
    required this.languageCode,
    required this.meaningLanguageMode,
    required this.meaningLanguage,
    required this.dailyGoal,
    required this.showFurigana,
    required this.autoPlayAudio,
    required this.themeMode,
    this.eyeComfortEnabled = false,
    this.eyeComfortLevel = 0.5,
    this.hideWord = false,
    this.hideMeanings = false,
    this.meaningCoverMode = MeaningCoverMode.meaningAndTranslation,
    this.ttsVolumeMode = TtsVolumeMode.system,
    this.ttsVolume = 0.5,
    this.ttsVoiceId = 'f1',
    required this.notificationsEnabled,
    this.reminderHour = 20,
    this.reminderMinute = 0,
    this.timeZone = 'UTC',
    required this.studySeconds,
    required this.quizAnswered,
    required this.quizCorrect,
    required this.currentStreak,
    required this.longestStreak,
    this.totalXp = 0,
    this.studySessions = const {},
    this.completedStudyDays = const {},
    this.lastQuizResult,
    this.lastMockTestResult,
  });

  final List<Vocabulary> vocabulary;
  final Map<String, ReviewProgress> progress;
  final bool onboardingComplete;
  final String selectedLevel;
  final String languageCode;
  final String meaningLanguageMode;
  final String meaningLanguage;
  final int dailyGoal;
  final bool showFurigana;
  final bool autoPlayAudio;
  final ThemeMode themeMode;
  final bool eyeComfortEnabled;
  final double eyeComfortLevel;
  final bool hideWord;
  final bool hideMeanings;
  final MeaningCoverMode meaningCoverMode;
  final TtsVolumeMode ttsVolumeMode;
  final double ttsVolume;
  final String ttsVoiceId;
  final bool notificationsEnabled;
  final int reminderHour;
  final int reminderMinute;
  final String timeZone;
  final int studySeconds;
  final int quizAnswered;
  final int quizCorrect;
  final int currentStreak;
  final int longestStreak;
  final int totalXp;
  final Map<String, StudySession> studySessions;
  final Map<String, Set<int>> completedStudyDays;
  final QuizResult? lastQuizResult;
  final MockTestResult? lastMockTestResult;

  List<Vocabulary> get selectedVocabulary =>
      vocabulary
          .where((item) => item.jlptLevel == selectedLevel)
          .toList(growable: false)
        ..sort((a, b) => a.rank.compareTo(b.rank));

  int get learnedCount =>
      progress.values.where((item) => item.isLearned).length;
  int get studiedCount => progress.length;
  double get dailyProgress =>
      dailyGoal == 0 ? 0 : (studiedCount / dailyGoal).clamp(0, 1);
  double get quizAccuracy => quizAnswered == 0 ? 0 : quizCorrect / quizAnswered;

  AppState copyWith({
    List<Vocabulary>? vocabulary,
    Map<String, ReviewProgress>? progress,
    bool? onboardingComplete,
    String? selectedLevel,
    String? languageCode,
    String? meaningLanguageMode,
    String? meaningLanguage,
    int? dailyGoal,
    bool? showFurigana,
    bool? autoPlayAudio,
    ThemeMode? themeMode,
    bool? eyeComfortEnabled,
    double? eyeComfortLevel,
    bool? hideWord,
    bool? hideMeanings,
    MeaningCoverMode? meaningCoverMode,
    TtsVolumeMode? ttsVolumeMode,
    double? ttsVolume,
    String? ttsVoiceId,
    bool? notificationsEnabled,
    int? reminderHour,
    int? reminderMinute,
    String? timeZone,
    int? studySeconds,
    int? quizAnswered,
    int? quizCorrect,
    int? currentStreak,
    int? longestStreak,
    int? totalXp,
    Map<String, StudySession>? studySessions,
    Map<String, Set<int>>? completedStudyDays,
    QuizResult? lastQuizResult,
    MockTestResult? lastMockTestResult,
  }) {
    return AppState(
      vocabulary: vocabulary ?? this.vocabulary,
      progress: progress ?? this.progress,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      selectedLevel: selectedLevel ?? this.selectedLevel,
      languageCode: languageCode ?? this.languageCode,
      meaningLanguageMode: meaningLanguageMode ?? this.meaningLanguageMode,
      meaningLanguage: meaningLanguage ?? this.meaningLanguage,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      showFurigana: showFurigana ?? this.showFurigana,
      autoPlayAudio: autoPlayAudio ?? this.autoPlayAudio,
      themeMode: themeMode ?? this.themeMode,
      eyeComfortEnabled: eyeComfortEnabled ?? this.eyeComfortEnabled,
      eyeComfortLevel: eyeComfortLevel ?? this.eyeComfortLevel,
      hideWord: hideWord ?? this.hideWord,
      hideMeanings: hideMeanings ?? this.hideMeanings,
      meaningCoverMode: meaningCoverMode ?? this.meaningCoverMode,
      ttsVolumeMode: ttsVolumeMode ?? this.ttsVolumeMode,
      ttsVolume: ttsVolume ?? this.ttsVolume,
      ttsVoiceId: ttsVoiceId ?? this.ttsVoiceId,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
      reminderMinute: reminderMinute ?? this.reminderMinute,
      timeZone: timeZone ?? this.timeZone,
      studySeconds: studySeconds ?? this.studySeconds,
      quizAnswered: quizAnswered ?? this.quizAnswered,
      quizCorrect: quizCorrect ?? this.quizCorrect,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      totalXp: totalXp ?? this.totalXp,
      studySessions: studySessions ?? this.studySessions,
      completedStudyDays: completedStudyDays ?? this.completedStudyDays,
      lastQuizResult: lastQuizResult ?? this.lastQuizResult,
      lastMockTestResult: lastMockTestResult ?? this.lastMockTestResult,
    );
  }
}
