import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/app/app.dart';
import 'package:jlpt_practice/core/services/app_startup.dart';

void main() {
  testWidgets('shows the loading screen while platform services initialize', (
    tester,
  ) async {
    final initialization = Completer<void>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStartupProvider.overrideWith((ref) => initialization.future),
        ],
        child: const JlptPracticeApp(),
      ),
    );

    expect(find.text('合格まで、あと一歩！'), findsOneWidget);
    expect(find.text('今日の一歩が、明日の自信に。'), findsOneWidget);
  });
}
