import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/shared/keep_screen_on.dart';

void main() {
  testWidgets('keeps the screen awake for the app lifetime', (tester) async {
    var enableCalls = 0;
    final controller = KeepScreenOnController(
      enable: () async => enableCalls++,
    );

    await tester.pumpWidget(
      KeepScreenOn(controller: controller, child: const SizedBox()),
    );
    await tester.pump();

    expect(enableCalls, 1);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    expect(enableCalls, 1);
  });

  testWidgets('re-enables the wake lock when the app resumes', (tester) async {
    var enableCalls = 0;
    final controller = KeepScreenOnController(
      enable: () async => enableCalls++,
    );

    await tester.pumpWidget(
      KeepScreenOn(controller: controller, child: const SizedBox()),
    );
    await tester.pump();

    expect(enableCalls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(enableCalls, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(enableCalls, 2);
  });
}
