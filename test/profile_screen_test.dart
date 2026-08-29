import 'package:jlpt_practice/features/profile/profile_screen.dart';
import 'package:flutter_test/flutter_test.dart';

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
}
