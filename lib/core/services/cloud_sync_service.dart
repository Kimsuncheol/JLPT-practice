import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:jlpt_practice/core/services/day_block_access.dart';
import 'package:jlpt_practice/core/services/firebase_bootstrap.dart';
import 'package:jlpt_practice/data/models/app_state.dart';
import 'package:jlpt_practice/data/models/grammar_progress.dart';
import 'package:jlpt_practice/data/models/mock_test.dart';
import 'package:jlpt_practice/data/models/quiz.dart';
import 'package:jlpt_practice/data/models/review_progress.dart';
import 'package:jlpt_practice/data/models/study_session.dart';

class CloudRestoreBundle {
  const CloudRestoreBundle({required this.state, required this.lastStudyDate});

  final AppState state;
  final String? lastStudyDate;
}

class CloudSyncService {
  const CloudSyncService();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>>? get _user {
    final userId = FirebaseBootstrap.userId;
    if (!FirebaseBootstrap.isAvailable || userId == null) return null;
    return _db.collection('users').doc(userId);
  }

  Future<CloudRestoreBundle> restore(AppState local) async {
    final user = _user;
    if (user == null) {
      return CloudRestoreBundle(state: local, lastStudyDate: null);
    }

    final results = await Future.wait([
      user.get(),
      user.collection('settings').doc('app').get(),
      user.collection('learning').doc('summary').get(),
      user.collection('learning').doc('access').get(),
      user.collection('vocabularyProgress').get(),
    ]);
    final profile = (results[0] as DocumentSnapshot<Map<String, dynamic>>)
        .data();
    final settings = (results[1] as DocumentSnapshot<Map<String, dynamic>>)
        .data();
    final summary = (results[2] as DocumentSnapshot<Map<String, dynamic>>)
        .data();
    final access = (results[3] as DocumentSnapshot<Map<String, dynamic>>)
        .data();
    final progressSnapshot = results[4] as QuerySnapshot<Map<String, dynamic>>;

    final progress = {...local.progress};
    for (final document in progressSnapshot.docs) {
      try {
        final remote = ReviewProgress.fromJson(document.data());
        final existing = progress[remote.vocabularyId];
        if (existing == null || remote.updatedAt.isAfter(existing.updatedAt)) {
          progress[remote.vocabularyId] = remote;
        }
      } on Object {
        // Ignore one malformed cloud record without blocking the whole restore.
      }
    }

    final sessions = {...local.studySessions};
    final remoteSessions = summary?['studySessions'];
    if (remoteSessions is Map) {
      for (final entry in remoteSessions.entries) {
        if (entry.key is! String || entry.value is! Map) continue;
        try {
          final remote = StudySession.fromJson(
            Map<String, dynamic>.from(entry.value as Map),
          );
          final existing = sessions[entry.key];
          if (existing == null ||
              remote.updatedAt.isAfter(existing.updatedAt)) {
            sessions[entry.key as String] = remote;
          }
        } on Object {
          // Keep the valid local session if this cloud record is malformed.
        }
      }
    }

    final completed = <String, Set<int>>{
      for (final entry in local.completedStudyDays.entries)
        entry.key: {...entry.value},
    };
    final remoteCompleted = summary?['completedStudyDays'];
    if (remoteCompleted is Map) {
      for (final entry in remoteCompleted.entries) {
        if (entry.key is! String || entry.value is! List) continue;
        completed
            .putIfAbsent(entry.key as String, () => <int>{})
            .addAll(
              (entry.value as List).whereType<num>().map(
                (value) => value.toInt(),
              ),
            );
      }
    }

    if (access != null) await DayBlockAccess.mergeAccess(access);

    final hasRemotePreferences =
        profile?['preferredLanguage'] is String ||
        settings?['themeMode'] is String;
    final restored = local.copyWith(
      progress: progress,
      studySessions: sessions,
      completedStudyDays: completed,
      onboardingComplete: hasRemotePreferences
          ? (profile?['onboardingComplete'] as bool? ??
                local.onboardingComplete)
          : local.onboardingComplete,
      selectedLevel:
          _validLevel(profile?['selectedJlptLevel']) ?? local.selectedLevel,
      languageCode:
          profile?['preferredLanguage'] as String? ?? local.languageCode,
      meaningLanguage:
          profile?['meaningLanguage'] as String? ?? local.meaningLanguage,
      dailyGoal: _positiveInt(profile?['dailyGoal']) ?? local.dailyGoal,
      currentStreak: _maxInt(local.currentStreak, summary?['currentStreak']),
      longestStreak: _maxInt(local.longestStreak, summary?['longestStreak']),
      studySeconds: _maxInt(local.studySeconds, summary?['studySeconds']),
      quizAnswered: _maxInt(local.quizAnswered, summary?['quizAnswered']),
      quizCorrect: _maxInt(local.quizCorrect, summary?['quizCorrect']),
      totalXp: _maxInt(local.totalXp, summary?['totalXp']),
      showFurigana: settings?['showFurigana'] as bool? ?? local.showFurigana,
      autoPlayAudio: settings?['autoPlayAudio'] as bool? ?? local.autoPlayAudio,
      themeMode: ThemeMode.values.firstWhere(
        (value) => value.name == settings?['themeMode'],
        orElse: () => local.themeMode,
      ),
      notificationsEnabled:
          settings?['notificationsEnabled'] as bool? ??
          local.notificationsEnabled,
      reminderHour:
          _boundedInt(settings?['reminderHour'], 0, 23) ?? local.reminderHour,
      reminderMinute:
          _boundedInt(settings?['reminderMinute'], 0, 59) ??
          local.reminderMinute,
      timeZone: settings?['timezone'] as String? ?? local.timeZone,
    );

    return CloudRestoreBundle(
      state: restored,
      lastStudyDate: summary?['lastStudyDate'] as String?,
    );
  }

  Future<void> syncAll(AppState state, {String? lastStudyDate}) async {
    await Future.wait([
      syncProfile(state),
      syncLearningSummary(state, lastStudyDate: lastStudyDate),
      _syncAllProgress(state.progress),
      syncAccess(),
    ]);
  }

  Future<void> syncProfile(AppState state) async {
    final user = _user;
    if (user == null) return;
    await user.set({
      'isAnonymous': FirebaseBootstrap.isAnonymous,
      'onboardingComplete': state.onboardingComplete,
      'preferredLanguage': state.languageCode,
      'meaningLanguage': state.meaningLanguage,
      'selectedJlptLevel': state.selectedLevel,
      'dailyGoal': state.dailyGoal,
      'currentStreak': state.currentStreak,
      'longestStreak': state.longestStreak,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await user.collection('settings').doc('app').set({
      'showFurigana': state.showFurigana,
      'autoPlayAudio': state.autoPlayAudio,
      'themeMode': state.themeMode.name,
      'notificationsEnabled': state.notificationsEnabled,
      'reminderHour': state.reminderHour,
      'reminderMinute': state.reminderMinute,
      'timezone': state.timeZone,
      'locale': state.meaningLanguage,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> syncLearningSummary(
    AppState state, {
    String? lastStudyDate,
  }) async {
    final user = _user;
    if (user == null) return;
    await user.collection('learning').doc('summary').set({
      'studySeconds': state.studySeconds,
      'quizAnswered': state.quizAnswered,
      'quizCorrect': state.quizCorrect,
      'currentStreak': state.currentStreak,
      'longestStreak': state.longestStreak,
      'totalXp': state.totalXp,
      'lastStudyDate': lastStudyDate,
      'studySessions': state.studySessions.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'completedStudyDays': state.completedStudyDays.map(
        (key, value) => MapEntry(key, value.toList()..sort()),
      ),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> syncProgress(ReviewProgress progress) async {
    final user = _user;
    if (user == null) return;
    await user.collection('vocabularyProgress').doc(progress.vocabularyId).set({
      ...progress.toJson(),
      'serverUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> syncGrammarProgress(GrammarProgress progress) async {
    final user = _user;
    if (user == null) return;
    await user.collection('grammarProgress').doc(progress.grammarId).set({
      ...progress.toJson(),
      'serverUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, GrammarProgress>> restoreGrammarProgress(
    Map<String, GrammarProgress> local,
  ) async {
    final user = _user;
    if (user == null) return local;
    final snapshot = await user.collection('grammarProgress').get();
    final merged = {...local};
    for (final document in snapshot.docs) {
      try {
        final remote = GrammarProgress.fromJson(document.data());
        final current = merged[remote.grammarId];
        if (current == null ||
            remote.lastPractisedAt.isAfter(current.lastPractisedAt)) {
          merged[remote.grammarId] = remote;
        }
      } on Object {
        // Ignore malformed records.
      }
    }
    return merged;
  }

  Future<void> recordQuizResult(QuizResult result) =>
      _addHistory('quizHistory', {
        'total': result.total,
        'correct': result.correct,
        'durationSeconds': result.duration.inSeconds,
        'incorrectIds': result.incorrectIds,
      });

  Future<void> recordMockTestResult(MockTestResult result) =>
      _addHistory('mockTestHistory', {
        'total': result.total,
        'correct': result.correct,
        'durationSeconds': result.duration.inSeconds,
        'sections': result.sections
            .map(
              (section) => {
                'type': section.type.name,
                'total': section.total,
                'correct': section.correct,
                'incorrectIds': section.incorrectIds,
              },
            )
            .toList(),
      });

  Future<void> _addHistory(String collection, Map<String, dynamic> data) async {
    final user = _user;
    if (user == null) return;
    await user.collection(collection).add({
      ...data,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> resetLearningData() async {
    final user = _user;
    if (user == null) return;
    for (final collection in [
      'vocabularyProgress',
      'grammarProgress',
      'quizHistory',
      'mockTestHistory',
    ]) {
      await _deleteCollection(user.collection(collection));
    }
    await Future.wait([
      user.collection('learning').doc('summary').delete(),
      user.collection('learning').doc('access').delete(),
    ]);
  }

  Future<void> _syncAllProgress(Map<String, ReviewProgress> progress) async {
    final user = _user;
    if (user == null || progress.isEmpty) return;
    final entries = progress.entries.toList();
    for (var offset = 0; offset < entries.length; offset += 400) {
      final batch = _db.batch();
      for (final entry in entries.skip(offset).take(400)) {
        batch.set(user.collection('vocabularyProgress').doc(entry.key), {
          ...entry.value.toJson(),
          'serverUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
    }
  }

  Future<void> syncAccess() async {
    final user = _user;
    if (user == null) return;
    final access = await DayBlockAccess.exportAccess();
    await user.collection('learning').doc('access').set({
      ...access,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    while (true) {
      final snapshot = await collection.limit(400).get();
      if (snapshot.docs.isEmpty) return;
      final batch = _db.batch();
      for (final document in snapshot.docs) {
        batch.delete(document.reference);
      }
      await batch.commit();
    }
  }

  static String? _validLevel(dynamic value) =>
      value is String && const {'N5', 'N4', 'N3', 'N2', 'N1'}.contains(value)
      ? value
      : null;

  static int? _positiveInt(dynamic value) =>
      value is num && value.toInt() > 0 ? value.toInt() : null;

  static int _maxInt(int local, dynamic cloud) =>
      cloud is num && cloud.toInt() > local ? cloud.toInt() : local;

  static int? _boundedInt(dynamic value, int min, int max) =>
      value is num && value.toInt() >= min && value.toInt() <= max
      ? value.toInt()
      : null;
}
