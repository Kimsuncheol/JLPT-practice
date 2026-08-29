import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/core/services/account_service.dart';
import 'package:jlpt_practice/features/settings/account_screen.dart';

void main() {
  test('account identity safely handles empty Firebase provider fields', () {
    expect(accountAvatarInitial(displayName: '', email: ''), 'A');
    expect(
      accountDisplayLabel(
        displayName: '   ',
        email: ' learner@example.com ',
        fallback: 'Account',
      ),
      'learner@example.com',
    );
  });

  testWidgets('anonymous users can switch from sign in to sign up', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firebaseUserProvider.overrideWith((ref) => Stream<User?>.value(null)),
        ],
        child: const MaterialApp(home: AccountScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.text('Confirm password'), findsNothing);

    await tester.ensureVisible(find.text('New here? Create an account'));
    await tester.tap(find.text('New here? Create an account'));
    await tester.pump();

    expect(find.text('Create your account'), findsOneWidget);
    expect(find.text('Sign up'), findsOneWidget);
    expect(find.text('Confirm password'), findsOneWidget);
  });
}
