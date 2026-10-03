import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/app/theme/app_theme.dart';
import 'package:jlpt_practice/shared/day_chip.dart';

void main() {
  Future<void> pumpChip(WidgetTester tester, ThemeData theme) =>
      tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: Align(alignment: Alignment.topLeft, child: DayChip(day: 7)),
          ),
        ),
      );

  BoxDecoration decoration(WidgetTester tester) =>
      tester
              .widget<DecoratedBox>(
                find.descendant(
                  of: find.byType(DayChip),
                  matching: find.byType(DecoratedBox),
                ),
              )
              .decoration
          as BoxDecoration;

  for (final (name, theme) in [
    ('light', AppTheme.light()),
    ('dark', AppTheme.dark()),
  ]) {
    testWidgets('is a pill coloured from the $name theme', (tester) async {
      await pumpChip(tester, theme);

      expect(find.text('Day 7'), findsOneWidget);
      final box = decoration(tester);
      expect(box.color, theme.colorScheme.primaryContainer);
      expect(
        box.borderRadius,
        isA<BorderRadius>().having(
          (radius) => radius.topLeft.x,
          'radius',
          greaterThanOrEqualTo(tester.getSize(find.byType(DayChip)).height / 2),
        ),
      );
      expect(
        tester.widget<Text>(find.text('Day 7')).style?.color,
        theme.colorScheme.onPrimaryContainer,
      );
    });
  }

  testWidgets('light and dark appearances use different colours', (
    tester,
  ) async {
    await pumpChip(tester, AppTheme.light());
    final light = decoration(tester).color;
    await pumpChip(tester, AppTheme.dark());
    await tester.pumpAndSettle();
    expect(decoration(tester).color, isNot(light));
  });
}
