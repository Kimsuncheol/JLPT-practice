import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/app/theme/app_theme.dart';
import 'package:jlpt_practice/shared/bootstrap_screen.dart';

void main() {
  testWidgets('splash screen shows cheerful Japanese JLPT message', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const SplashScreenContent()),
    );
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.text('合格まで、あと一歩！'), findsOneWidget);
    expect(find.text('今日の一歩が、明日の自信に。'), findsOneWidget);
    expect(find.text('KOTOBA FLOW  •  JLPT'), findsOneWidget);
    expect(find.text('語'), findsOneWidget);
  });
}
