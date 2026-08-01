import 'package:flutter/material.dart';
import 'package:jlpt_practice/data/models/quiz.dart';
import 'package:jlpt_practice/data/models/review_progress.dart';
import 'package:jlpt_practice/data/models/vocabulary.dart';

class AppState {
  const AppState({
    required this.vocabulary,
    required this.progress,
    required this.onboardingComplete,
    required this.selectedLevel,
    required this.languageCode,
    required this.meaningLanguage,
    required this.dailyGoal,
    required this.showFurigana,
    required this.autoPlayAudio,
    required this.themeMode,
    required this.notificationsEnabled,
    required this.studySeconds,
    required this.quizAnswered,
    required this.quizCorrect,
    required this.currentStreak,
    required this.longestStreak,
    this.lastQuizResult,
  });

  final List<Vocabulary> vocabulary;
  final Map<String, ReviewProgress> progress;
  final bool onboardingComplete;
  final String selectedLevel;
  final String languageCode;
  final String meaningLanguage;
  final int dailyGoal;
  final bool showFurigana;
  final bool autoPlayAudio;
  final ThemeMode themeMode;
  final bool notificationsEnabled;
  final int studySeconds;
  final int quizAnswered;
  final int quizCorrect;
  final int currentStreak;
  final int longestStreak;
  final QuizResult? lastQuizResult;

  List<Vocabulary> get selectedVocabulary =>
      vocabulary
          .where((item) => item.jlptLevel == selectedLevel)
          .toList(growable: false)
        ..sort((a, b) => a.rank.compareTo(b.rank));

  List<Vocabulary> get dueVocabulary {
    final due = vocabulary.where((item) {
      final itemProgress = progress[item.id];
      return itemProgress != null &&
          itemProgress.jlptLevel == selectedLevel &&
          itemProgress.isDue;
    }).toList();
    due.sort(
      (a, b) =>
          progress[a.id]!.nextReviewAt.compareTo(progress[b.id]!.nextReviewAt),
    );
    return due;
  }

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
    String? meaningLanguage,
    int? dailyGoal,
    bool? showFurigana,
    bool? autoPlayAudio,
    ThemeMode? themeMode,
    bool? notificationsEnabled,
    int? studySeconds,
    int? quizAnswered,
    int? quizCorrect,
    int? currentStreak,
    int? longestStreak,
    QuizResult? lastQuizResult,
  }) {
    return AppState(
      vocabulary: vocabulary ?? this.vocabulary,
      progress: progress ?? this.progress,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      selectedLevel: selectedLevel ?? this.selectedLevel,
      languageCode: languageCode ?? this.languageCode,
      meaningLanguage: meaningLanguage ?? this.meaningLanguage,
      dailyGoal: dailyGoal ?? this.dailyGoal,
      showFurigana: showFurigana ?? this.showFurigana,
      autoPlayAudio: autoPlayAudio ?? this.autoPlayAudio,
      themeMode: themeMode ?? this.themeMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      studySeconds: studySeconds ?? this.studySeconds,
      quizAnswered: quizAnswered ?? this.quizAnswered,
      quizCorrect: quizCorrect ?? this.quizCorrect,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastQuizResult: lastQuizResult ?? this.lastQuizResult,
    );
  }
}
