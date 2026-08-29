import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
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
      if (!kIsWeb) {
        await FirebaseAppCheck.instance.activate(
          providerAndroid: kDebugMode
              ? const AndroidDebugProvider()
              : const AndroidPlayIntegrityProvider(),
          providerApple: kDebugMode
              ? const AppleDebugProvider()
              : const AppleAppAttestWithDeviceCheckFallbackProvider(),
        );
      }
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
      );
      final auth = FirebaseAuth.instance;
      updateUser(auth.currentUser);
      isAvailable = true;
      if (userId != null) await ensureUserDocument();
      auth.userChanges().listen(updateUser);
    } catch (error, stackTrace) {
      isAvailable = false;
      if (kDebugMode) {
        debugPrint('Firebase unavailable; using local mode: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
  }

  static void updateUser(User? user) {
    userId = user?.uid;
  }

  static Future<void> ensureUserDocument() async {
    final id = userId;
    if (id == null) return;
    final reference = FirebaseFirestore.instance.collection('users').doc(id);
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(reference);
      transaction.set(reference, {
        'updatedAt': FieldValue.serverTimestamp(),
        if (!snapshot.exists) 'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }
}
