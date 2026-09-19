import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:jlpt_practice/core/services/firebase_bootstrap.dart';

final firebaseUserProvider = StreamProvider<User?>((ref) {
  if (!FirebaseBootstrap.isAvailable) return const Stream.empty();
  return FirebaseAuth.instance.userChanges();
});

final accountServiceProvider = Provider((ref) => AccountService.instance);

class AccountService {
  AccountService._();

  static final instance = AccountService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  Future<void>? _googleInitialization;

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
  }) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await result.user?.sendEmailVerification();
    await _afterAuthentication(result.user);
    return result;
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final result = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await _afterAuthentication(result.user);
    return result;
  }

  Future<UserCredential> continueWithGoogle() async {
    if (kIsWeb) {
      final result = await _auth.signInWithPopup(GoogleAuthProvider());
      await _afterAuthentication(result.user);
      return result;
    }

    _googleInitialization ??= GoogleSignIn.instance.initialize();
    await _googleInitialization;
    await GoogleSignIn.instance.signOut();
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw StateError('Google did not return an identity token.');
    }
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    final result = await _auth.signInWithCredential(credential);
    await _afterAuthentication(result.user);
    return result;
  }

  Future<UserCredential> continueWithApple() async {
    final provider = AppleAuthProvider()
      ..addScope('email')
      ..addScope('name');
    final result = await _auth.signInWithProvider(provider);
    await _afterAuthentication(result.user);
    return result;
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> resendVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    if (!kIsWeb) await GoogleSignIn.instance.signOut();
  }

  Future<void> deleteAccount() async {
    await FirebaseFunctions.instance
        .httpsCallable('deleteAccount')
        .call<Map<String, dynamic>>();
    await signOut();
  }

  Future<void> _afterAuthentication(User? user) async {
    FirebaseBootstrap.updateUser(user);
    await FirebaseBootstrap.ensureUserDocument();
  }
}
