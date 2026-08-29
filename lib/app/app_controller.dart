import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:jlpt_practice/core/services/cloud_sync_service.dart';
import 'package:jlpt_practice/core/services/day_block_access.dart';
import 'package:jlpt_practice/core/services/local_store.dart';
import 'package:jlpt_practice/core/services/notification_service.dart';
import 'package:jlpt_practice/core/services/srs_scheduler.dart';
import 'package:jlpt_practice/core/services/tts_service.dart';
import 'package:jlpt_practice/data/models/app_state.dart';
import 'package:jlpt_practice/data/models/mock_test.dart';
import 'package:jlpt_practice/data/models/quiz.dart';
import 'package:jlpt_practice/data/models/review_progress.dart';
import 'package:jlpt_practice/data/models/study_session.dart';
import 'package:jlpt_practice/data/repositories/quiz_repository.dart';
import 'package:jlpt_practice/data/repositories/vocabulary_repository.dart';

final vocabularyRepositoryProvider = Provider(
  (ref) => const VocabularyRepository(),
);
final quizRepositoryProvider = Provider((ref) => QuizRepository());
final srsSchedulerProvider = Provider((ref) => const SrsScheduler());
final cloudSyncProvider = Provider((ref) => const CloudSyncService());
final ttsServiceProvider = Provider((ref) {
  final service = TtsService();
  ref.onDispose(service.dispose);
  return service;
});

final appControllerProvider = AsyncNotifierProvider<AppController, AppState>(
  AppController.new,
);

class AppController extends AsyncNotifier<AppState> {
  late LocalStore _store;
  Future<void> _studySessionWrite = Future.value();

  @override
  Future<AppState> build() async {
    _store = await LocalStore.create();
    final language = ui.PlatformDispatcher.instance.locale.languageCode;
    final settings = _store.loadSettings(language);
    final vocabulary = await ref.read(vocabularyRepositoryProvider).load();
    var notificationsEnabled = settings.notificationsEnabled;
    if (notificationsEnabled) {
      notificationsEnabled = await NotificationService.instance.hasPermission();
      if (notificationsEnabled) {
        await NotificationService.instance.scheduleDailyReminder(
          hour: settings.reminderHour,
          minute: settings.reminderMinute,
          languageCode: settings.meaningLanguage,
        );
        unawaited(NotificationService.instance.setRemoteEnabled(true));
      } else {
        await _store.setValue('notificationsEnabled', false);
      }
    }
    final local = AppState(
      vocabulary: vocabulary,
      progress: _store.loadProgress(),
      onboardingComplete: settings.onboardingComplete,
      selectedLevel: settings.selectedLevel,
      languageCode: settings.languageCode,
      meaningLanguage: settings.meaningLanguage,
      dailyGoal: settings.dailyGoal,
      showFurigana: settings.showFurigana,
      autoPlayAudio: settings.autoPlayAudio,
      themeMode: settings.themeMode,
      notificationsEnabled: notificationsEnabled,
      reminderHour: settings.reminderHour,
      reminderMinute: settings.reminderMinute,
      timeZone: NotificationService.instance.timeZoneId,
      studySeconds: settings.studySeconds,
      quizAnswered: settings.quizAnswered,
      quizCorrect: settings.quizCorrect,
      currentStreak: settings.currentStreak,
      longestStreak: settings.longestStreak,
      totalXp: settings.totalXp,
      studySessions: _store.loadStudySessions(),
      completedStudyDays: _store.loadCompletedStudyDays(),
    );
    try {
      final restored = await ref.read(cloudSyncProvider).restore(local);
      await _store.saveAppState(
        restored.state,
        lastStudyDate: restored.lastStudyDate,
      );
      unawaited(
        ref
            .read(cloudSyncProvider)
            .syncAll(
              restored.state,
              lastStudyDate: restored.lastStudyDate ?? _store.lastStudyDate,
            ),
      );
      return restored.state;
    } on Object {
      return local;
    }
  }

  AppState get _value => state.requireValue;

  Future<void> completeOnboarding({
    required String level,
    required String languageCode,
    required bool autoPlayAudio,
  }) async {
    final resolvedLanguage = languageCode == 'system'
        ? (ui.PlatformDispatcher.instance.locale.languageCode == 'ko'
              ? 'ko'
              : 'en')
        : languageCode;
    final next = _value.copyWith(
      onboardingComplete: true,
      selectedLevel: level,
      languageCode: languageCode,
      meaningLanguage: resolvedLanguage,
      autoPlayAudio: autoPlayAudio,
    );
    state = AsyncData(next);
    await Future.wait([
      _store.setValue('onboardingComplete', true),
      _store.setValue('selectedLevel', level),
      _store.setValue('languageCode', languageCode),
      _store.setValue('meaningLanguage', resolvedLanguage),
      _store.setValue('autoPlayAudio', autoPlayAudio),
    ]);
    unawaited(ref.read(cloudSyncProvider).syncProfile(next));
  }

  Future<void> rateVocabulary(String vocabularyId, ReviewRating rating) async {
    final vocabulary = _value.vocabulary.firstWhere(
      (item) => item.id == vocabularyId,
    );
    final progress = {..._value.progress};
    final scheduled = ref
        .read(srsSchedulerProvider)
        .schedule(
          vocabularyId: vocabularyId,
          jlptLevel: vocabulary.jlptLevel,
          rating: rating,
          current: progress[vocabularyId],
        );
    progress[vocabularyId] = scheduled;
    var next = _value.copyWith(progress: progress);
    next = await _withRecordedActivity(next);
    state = AsyncData(next);
    await _store.saveProgress(progress);
    unawaited(ref.read(cloudSyncProvider).syncProgress(scheduled));
    unawaited(_syncLearningSummary(next));
  }

  Future<void> removeVocabularyProgress(String vocabularyId) async {
    final progress = {..._value.progress}..remove(vocabularyId);
    final next = _value.copyWith(progress: progress);
    state = AsyncData(next);
    await _store.saveProgress(progress);
    unawaited(ref.read(cloudSyncProvider).deleteProgress(vocabularyId));
  }

  Future<void> recordQuizResult(
    QuizResult result,
    List<QuizQuestion> questions,
  ) async {
    final progress = {..._value.progress};
    for (final question in questions) {
      final rating = result.incorrectIds.contains(question.vocabulary.id)
          ? ReviewRating.again
          : ReviewRating.good;
      progress[question.vocabulary.id] = ref
          .read(srsSchedulerProvider)
          .schedule(
            vocabularyId: question.vocabulary.id,
            jlptLevel: question.vocabulary.jlptLevel,
            rating: rating,
            current: progress[question.vocabulary.id],
          );
    }
    var next = _value.copyWith(
      progress: progress,
      quizAnswered: _value.quizAnswered + result.total,
      quizCorrect: _value.quizCorrect + result.correct,
      studySeconds: _value.studySeconds + result.duration.inSeconds,
      lastQuizResult: result,
    );
    next = await _withRecordedActivity(next);
    state = AsyncData(next);
    await Future.wait([
      _store.saveProgress(progress),
      _store.setValue('quizAnswered', next.quizAnswered),
      _store.setValue('quizCorrect', next.quizCorrect),
      _store.setValue('studySeconds', next.studySeconds),
    ]);
    for (final scheduled in progress.values) {
      unawaited(ref.read(cloudSyncProvider).syncProgress(scheduled));
    }
    unawaited(ref.read(cloudSyncProvider).recordQuizResult(result));
    unawaited(_syncLearningSummary(next));
  }

  Future<void> recordMockTestResult(
    MockTestResult result, {
    required List<QuizQuestion> vocabularyQuestions,
  }) async {
    final progress = {..._value.progress};
    final vocabularySection = result.sectionFor(TestSectionType.vocabulary);
    if (vocabularySection != null) {
      for (final question in vocabularyQuestions) {
        final rating =
            vocabularySection.incorrectIds.contains(question.vocabulary.id)
            ? ReviewRating.again
            : ReviewRating.good;
        progress[question.vocabulary.id] = ref
            .read(srsSchedulerProvider)
            .schedule(
              vocabularyId: question.vocabulary.id,
              jlptLevel: question.vocabulary.jlptLevel,
              rating: rating,
              current: progress[question.vocabulary.id],
            );
      }
    }
    var next = _value.copyWith(
      progress: progress,
      quizAnswered: _value.quizAnswered + result.total,
      quizCorrect: _value.quizCorrect + result.correct,
      studySeconds: _value.studySeconds + result.duration.inSeconds,
      lastMockTestResult: result,
    );
    next = await _withRecordedActivity(next);
    state = AsyncData(next);
    await Future.wait([
      _store.saveProgress(progress),
      _store.setValue('quizAnswered', next.quizAnswered),
      _store.setValue('quizCorrect', next.quizCorrect),
      _store.setValue('studySeconds', next.studySeconds),
    ]);
    for (final scheduled in progress.values) {
      unawaited(ref.read(cloudSyncProvider).syncProgress(scheduled));
    }
    unawaited(ref.read(cloudSyncProvider).recordMockTestResult(result));
    unawaited(_syncLearningSummary(next));
  }

  Future<void> addBonusXp(int amount) async {
    final next = _value.copyWith(totalXp: _value.totalXp + amount);
    state = AsyncData(next);
    await _store.setValue('totalXp', next.totalXp);
    unawaited(_syncLearningSummary(next));
  }

  Future<AppState> _withRecordedActivity(AppState current) async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (_store.lastStudyDate == today) return current;
    final yesterday = DateFormat(
      'yyyy-MM-dd',
    ).format(DateTime.now().subtract(const Duration(days: 1)));
    final streak = _store.lastStudyDate == yesterday
        ? current.currentStreak + 1
        : 1;
    final longest = streak > current.longestStreak
        ? streak
        : current.longestStreak;
    await Future.wait([
      _store.setValue('lastStudyDate', today),
      _store.setValue('currentStreak', streak),
      _store.setValue('longestStreak', longest),
    ]);
    return current.copyWith(currentStreak: streak, longestStreak: longest);
  }

  Future<void> setLevel(String value) =>
      _updatePreference('selectedLevel', value, (current) {
        return current.copyWith(selectedLevel: value);
      });

  Future<void> setLanguage(String value) async {
    final resolved = value == 'system'
        ? (ui.PlatformDispatcher.instance.locale.languageCode == 'ko'
              ? 'ko'
              : 'en')
        : value;
    final next = _value.copyWith(
      languageCode: value,
      meaningLanguage: resolved,
    );
    state = AsyncData(next);
    await Future.wait([
      _store.setValue('languageCode', value),
      _store.setValue('meaningLanguage', resolved),
    ]);
    if (next.notificationsEnabled) {
      await NotificationService.instance.scheduleDailyReminder(
        hour: next.reminderHour,
        minute: next.reminderMinute,
        languageCode: resolved,
      );
    }
    unawaited(ref.read(cloudSyncProvider).syncProfile(next));
  }

  Future<void> setShowFurigana(bool value) =>
      _updatePreference('showFurigana', value, (current) {
        return current.copyWith(showFurigana: value);
      });

  Future<void> setAutoPlayAudio(bool value) =>
      _updatePreference('autoPlayAudio', value, (current) {
        return current.copyWith(autoPlayAudio: value);
      });

  Future<bool> setNotifications(bool value) async {
    var enabled = value;
    if (value) {
      enabled = await NotificationService.instance.enableDailyReminder(
        hour: _value.reminderHour,
        minute: _value.reminderMinute,
        languageCode: _value.meaningLanguage,
      );
    } else {
      await NotificationService.instance.disableNotifications();
    }
    await _updatePreference('notificationsEnabled', enabled, (current) {
      return current.copyWith(notificationsEnabled: enabled);
    });
    return enabled;
  }

  Future<void> setReminderTime(TimeOfDay value) async {
    final next = _value.copyWith(
      reminderHour: value.hour,
      reminderMinute: value.minute,
    );
    state = AsyncData(next);
    await Future.wait([
      _store.setValue('reminderHour', value.hour),
      _store.setValue('reminderMinute', value.minute),
    ]);
    if (next.notificationsEnabled) {
      await NotificationService.instance.scheduleDailyReminder(
        hour: value.hour,
        minute: value.minute,
        languageCode: next.meaningLanguage,
      );
    }
    unawaited(ref.read(cloudSyncProvider).syncProfile(next));
  }

  Future<void> setThemeMode(ThemeMode value) =>
      _updatePreference('themeMode', value.name, (current) {
        return current.copyWith(themeMode: value);
      });

  Future<void> saveStudySession(StudySession session) async {
    final sessions = {..._value.studySessions, session.level: session};
    state = AsyncData(_value.copyWith(studySessions: sessions));
    await _persistStudySessions(sessions);
    unawaited(_syncLearningSummary(_value));
  }

  Future<void> completeStudySession(String level, int day) async {
    final sessions = {..._value.studySessions}..remove(level);
    final completedStudyDays = {
      ..._value.completedStudyDays,
      level: {...?_value.completedStudyDays[level], day},
    };
    state = AsyncData(
      _value.copyWith(
        studySessions: sessions,
        completedStudyDays: completedStudyDays,
      ),
    );
    await Future.wait([
      _persistStudySessions(sessions),
      _store.saveCompletedStudyDays(completedStudyDays),
    ]);
    unawaited(_syncLearningSummary(_value));
  }

  Future<void> _persistStudySessions(Map<String, StudySession> sessions) {
    final snapshot = Map<String, StudySession>.unmodifiable(sessions);
    _studySessionWrite = _studySessionWrite.then(
      (_) => _store.saveStudySessions(snapshot),
    );
    return _studySessionWrite;
  }

  Future<void> _updatePreference(
    String key,
    Object value,
    AppState Function(AppState) update,
  ) async {
    final next = update(_value);
    state = AsyncData(next);
    await _store.setValue(key, value);
    unawaited(ref.read(cloudSyncProvider).syncProfile(next));
  }

  Future<void> resetLearningProgress() async {
    final next = _value.copyWith(
      progress: {},
      studySeconds: 0,
      quizAnswered: 0,
      quizCorrect: 0,
      currentStreak: 0,
      longestStreak: 0,
      totalXp: 0,
      studySessions: {},
      completedStudyDays: {},
    );
    await ref.read(cloudSyncProvider).resetLearningData();
    state = AsyncData(next);
    await _studySessionWrite;
    await _store.clearLearningData();
    await DayBlockAccess.clearRewardedDays();
  }

  Future<void> mergeCurrentAccount() async {
    final restored = await ref.read(cloudSyncProvider).restore(_value);
    state = AsyncData(restored.state);
    await _store.saveAppState(
      restored.state,
      lastStudyDate: restored.lastStudyDate ?? _store.lastStudyDate,
    );
    await ref
        .read(cloudSyncProvider)
        .syncAll(
          restored.state,
          lastStudyDate: restored.lastStudyDate ?? _store.lastStudyDate,
        );
  }

  Future<void> clearLocalForAccountSwitch() async {
    await _studySessionWrite;
    await _store.clearAccountData();
  }

  Future<void> _syncLearningSummary(AppState value) => ref
      .read(cloudSyncProvider)
      .syncLearningSummary(value, lastStudyDate: _store.lastStudyDate);
}
