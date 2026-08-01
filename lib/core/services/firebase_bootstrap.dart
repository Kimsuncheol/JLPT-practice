import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:jlpt_practice/firebase_options.dart';

class FirebaseBootstrap {
  FirebaseBootstrap._();

  static bool isAvailable = false;
  static String? userId;

  static Future<void> initialize() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
      );
      final auth = FirebaseAuth.instance;
      final credential = auth.currentUser == null
          ? await auth.signInAnonymously()
          : null;
      userId = auth.currentUser?.uid ?? credential?.user?.uid;
      if (userId == null) return;
      isAvailable = true;
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'isAnonymous': auth.currentUser?.isAnonymous ?? true,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error, stackTrace) {
      isAvailable = false;
      if (kDebugMode) {
        debugPrint('Firebase unavailable; using local mode: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }
}
