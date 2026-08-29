import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:jlpt_practice/data/models/app_state.dart';
import 'package:jlpt_practice/data/models/grammar_progress.dart';
import 'package:jlpt_practice/data/models/review_progress.dart';
import 'package:jlpt_practice/data/models/study_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalSettings {
  const LocalSettings({
    required this.onboardingComplete,
    required this.selectedLevel,
    required this.languageCode,
    required this.meaningLanguage,
    required this.dailyGoal,
    required this.showFurigana,
    required this.autoPlayAudio,
    required this.themeMode,
    required this.notificationsEnabled,
    required this.reminderHour,
    required this.reminderMinute,
    required this.studySeconds,
    required this.quizAnswered,
    required this.quizCorrect,
    required this.currentStreak,
    required this.longestStreak,
    required this.totalXp,
  });

  final bool onboardingComplete;
  final String selectedLevel;
  final String languageCode;
  final String meaningLanguage;
  final int dailyGoal;
  final bool showFurigana;
  final bool autoPlayAudio;
  final ThemeMode themeMode;
  final bool notificationsEnabled;
  final int reminderHour;
  final int reminderMinute;
  final int studySeconds;
  final int quizAnswered;
  final int quizCorrect;
  final int currentStreak;
  final int longestStreak;
  final int totalXp;
}

class LocalStore {
  LocalStore(this._preferences);

  final SharedPreferences _preferences;

  static Future<LocalStore> create() async =>
      LocalStore(await SharedPreferences.getInstance());

  LocalSettings loadSettings(String deviceLanguage) {
    final themeName = _preferences.getString('themeMode') ?? 'system';
    return LocalSettings(
      onboardingComplete: _preferences.getBool('onboardingComplete') ?? false,
      selectedLevel: _preferences.getString('selectedLevel') ?? 'N5',
      languageCode: _preferences.getString('languageCode') ?? 'system',
      meaningLanguage:
          _preferences.getString('meaningLanguage') ??
          (deviceLanguage == 'ko' ? 'ko' : 'en'),
      dailyGoal: 30,
      showFurigana: _preferences.getBool('showFurigana') ?? true,
      autoPlayAudio: _preferences.getBool('autoPlayAudio') ?? false,
      themeMode: ThemeMode.values.firstWhere(
        (value) => value.name == themeName,
        orElse: () => ThemeMode.system,
      ),
      notificationsEnabled:
          _preferences.getBool('notificationsEnabled') ?? false,
      reminderHour: _preferences.getInt('reminderHour') ?? 20,
      reminderMinute: _preferences.getInt('reminderMinute') ?? 0,
      studySeconds: _preferences.getInt('studySeconds') ?? 0,
      quizAnswered: _preferences.getInt('quizAnswered') ?? 0,
      quizCorrect: _preferences.getInt('quizCorrect') ?? 0,
      currentStreak: _preferences.getInt('currentStreak') ?? 0,
      longestStreak: _preferences.getInt('longestStreak') ?? 0,
      totalXp: _preferences.getInt('totalXp') ?? 0,
    );
  }

  String? get lastStudyDate => _preferences.getString('lastStudyDate');

  Future<void> saveAppState(AppState state, {String? lastStudyDate}) async {
    await Future.wait([
      setValue('onboardingComplete', state.onboardingComplete),
      setValue('selectedLevel', state.selectedLevel),
      setValue('languageCode', state.languageCode),
      setValue('meaningLanguage', state.meaningLanguage),
      setValue('showFurigana', state.showFurigana),
      setValue('autoPlayAudio', state.autoPlayAudio),
      setValue('themeMode', state.themeMode.name),
      setValue('notificationsEnabled', state.notificationsEnabled),
      setValue('reminderHour', state.reminderHour),
      setValue('reminderMinute', state.reminderMinute),
      setValue('studySeconds', state.studySeconds),
      setValue('quizAnswered', state.quizAnswered),
      setValue('quizCorrect', state.quizCorrect),
      setValue('currentStreak', state.currentStreak),
      setValue('longestStreak', state.longestStreak),
      setValue('totalXp', state.totalXp),
      saveProgress(state.progress),
      saveStudySessions(state.studySessions),
      saveCompletedStudyDays(state.completedStudyDays),
      if (lastStudyDate != null) setValue('lastStudyDate', lastStudyDate),
    ]);
  }

  Map<String, ReviewProgress> loadProgress() {
    final raw = _preferences.getString('progress');
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (key, value) => MapEntry(
          key,
          ReviewProgress.fromJson(value as Map<String, dynamic>),
        ),
      );
    } on FormatException {
      return {};
    }
  }

  Map<String, StudySession> loadStudySessions() {
    final raw = _preferences.getString('studySessions');
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (key, value) =>
            MapEntry(key, StudySession.fromJson(value as Map<String, dynamic>)),
      );
    } on FormatException {
      return {};
    } on TypeError {
      return {};
    }
  }

  Map<String, Set<int>> loadCompletedStudyDays() {
    final raw = _preferences.getString('completedStudyDays');
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (level, days) => MapEntry(
          level,
          (days as List<dynamic>).map((day) => day as int).toSet(),
        ),
      );
    } on FormatException {
      return {};
    } on TypeError {
      return {};
    }
  }

  Map<String, GrammarProgress> loadGrammarProgress() {
    final raw = _preferences.getString('grammarProgress');
    if (raw == null) return {};
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map(
        (key, value) => MapEntry(
          key,
          GrammarProgress.fromJson(value as Map<String, dynamic>),
        ),
      );
    } on FormatException {
      return {};
    } on TypeError {
      return {};
    }
  }

  Future<void> saveProgress(Map<String, ReviewProgress> progress) =>
      _preferences.setString(
        'progress',
        jsonEncode(progress.map((key, value) => MapEntry(key, value.toJson()))),
      );

  Future<void> saveStudySessions(Map<String, StudySession> sessions) =>
      _preferences.setString(
        'studySessions',
        jsonEncode(sessions.map((key, value) => MapEntry(key, value.toJson()))),
      );

  Future<void> saveCompletedStudyDays(Map<String, Set<int>> completedDays) =>
      _preferences.setString(
        'completedStudyDays',
        jsonEncode(
          completedDays.map(
            (level, days) => MapEntry(level, days.toList()..sort()),
          ),
        ),
      );

  Future<void> saveGrammarProgress(Map<String, GrammarProgress> progress) =>
      _preferences.setString(
        'grammarProgress',
        jsonEncode(progress.map((key, value) => MapEntry(key, value.toJson()))),
      );

  Future<void> setValue(String key, Object value) async {
    switch (value) {
      case String():
        await _preferences.setString(key, value);
        return;
      case int():
        await _preferences.setInt(key, value);
        return;
      case bool():
        await _preferences.setBool(key, value);
        return;
      default:
        throw ArgumentError.value(value, key, 'Unsupported preference value');
    }
  }

  Future<void> clearLearningData() async {
    await Future.wait([
      _preferences.remove('progress'),
      _preferences.remove('studySeconds'),
      _preferences.remove('quizAnswered'),
      _preferences.remove('quizCorrect'),
      _preferences.remove('currentStreak'),
      _preferences.remove('longestStreak'),
      _preferences.remove('totalXp'),
      _preferences.remove('studySessions'),
      _preferences.remove('completedStudyDays'),
      _preferences.remove('grammarProgress'),
      _preferences.remove('lastStudyDate'),
    ]);
  }

  Future<void> clearAccountData() async {
    const keys = <String>{
      'onboardingComplete',
      'selectedLevel',
      'languageCode',
      'meaningLanguage',
      'showFurigana',
      'autoPlayAudio',
      'themeMode',
      'notificationsEnabled',
      'reminderHour',
      'reminderMinute',
      'progress',
      'studySeconds',
      'quizAnswered',
      'quizCorrect',
      'currentStreak',
      'longestStreak',
      'totalXp',
      'studySessions',
      'completedStudyDays',
      'grammarProgress',
      'lastStudyDate',
    };
    final dynamicKeys = _preferences.getKeys().where(
      (key) =>
          key.startsWith('unlockedDayBlocks_') ||
          key.startsWith('rewardedStudyDays_'),
    );
    await Future.wait({...keys, ...dynamicKeys}.map(_preferences.remove));
  }
}
