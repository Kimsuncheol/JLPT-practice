import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jlpt_practice/core/services/firebase_bootstrap.dart';
import 'package:jlpt_practice/data/models/app_state.dart';
import 'package:jlpt_practice/data/models/review_progress.dart';

class CloudSyncService {
  const CloudSyncService();

  DocumentReference<Map<String, dynamic>>? get _user {
    final userId = FirebaseBootstrap.userId;
    if (!FirebaseBootstrap.isAvailable || userId == null) return null;
    return FirebaseFirestore.instance.collection('users').doc(userId);
  }

  Future<void> syncProfile(AppState state) async {
    final user = _user;
    if (user == null) return;
    await user.set({
      'isAnonymous': true,
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
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> syncProgress(ReviewProgress progress) async {
    final user = _user;
    if (user == null) return;
    await user.collection('vocabularyProgress').doc(progress.vocabularyId).set({
      ...progress.toJson(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
