import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/shared/keep_screen_on.dart';

void main() {
  testWidgets(
    'keeps the screen awake only while an eligible screen is mounted',
    (tester) async {
      var enableCalls = 0;
      var disableCalls = 0;
      final controller = KeepScreenOnController(
        enable: () async => enableCalls++,
        disable: () async => disableCalls++,
      );

      await tester.pumpWidget(
        KeepScreenOn(controller: controller, child: const SizedBox()),
      );
      await tester.pump();

      expect(enableCalls, 1);
      expect(disableCalls, 0);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      expect(disableCalls, 1);
    },
  );

  testWidgets('does not disable while another eligible screen is mounted', (
    tester,
  ) async {
    var enableCalls = 0;
    var disableCalls = 0;
    final controller = KeepScreenOnController(
      enable: () async => enableCalls++,
      disable: () async => disableCalls++,
    );

    await tester.pumpWidget(
      KeepScreenOn(
        controller: controller,
        child: KeepScreenOn(controller: controller, child: const SizedBox()),
      ),
    );
    await tester.pump();

    expect(enableCalls, 1);

    await tester.pumpWidget(
      KeepScreenOn(controller: controller, child: const SizedBox()),
    );
    await tester.pump();

    expect(disableCalls, 0);

    await tester.pumpWidget(const SizedBox());
    await tester.pump();

    expect(disableCalls, 1);
  });
}
