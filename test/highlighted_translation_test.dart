import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/services/meaning_mask_service.dart';
import 'package:jlpt_practice/features/vocabulary/cover_tape.dart';
import 'package:jlpt_practice/features/vocabulary/masked_translation.dart';

import 'core/kiwi_fixtures.dart';

class _Analyzer implements MorphemeAnalyzer {
  @override
  Future<List<Morpheme>> analyze(String text) async => kiwiFixtures[text] ?? [];

  @override
  Future<void> close() async {}
}

void main() {
  testWidgets(
    'highlights Korean inflection and restores masking when quiz ends',
    (tester) async {
      final service = MeaningMaskService(_Analyzer());
      addTearDown(service.close);
      final container = ProviderContainer(
        overrides: [meaningMaskServiceProvider.overrideWithValue(service)],
      );
      addTearDown(container.dispose);
      Widget build({TextStyle? highlight, bool hide = false}) =>
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: MaskedTranslation(
                  translation: '음악을 들었어요.',
                  meanings: const ['듣다'],
                  hideMeanings: hide,
                  highlightStyle: highlight,
                  style: const TextStyle(fontSize: 16),
                  glyphWidth: 0.55,
                ),
              ),
            ),
          );
      const highlight = TextStyle(fontWeight: FontWeight.bold);
      await tester.pumpWidget(build(highlight: highlight));
      await tester.pumpAndSettle();
      final text = tester.widget<Text>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text && widget.textSpan?.toPlainText() == '음악을 들었어요.',
        ),
      );
      final spans = (text.textSpan! as TextSpan).children!
          .whereType<TextSpan>();
      expect(spans.singleWhere((span) => span.text == '들었어요').style, highlight);
      expect(spans.first.style, isNull);
      expect(find.byType(CoverTape), findsNothing);
      await tester.pumpWidget(build(hide: true));
      await tester.pumpAndSettle();
      expect(find.byType(CoverTape), findsWidgets);
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.text('음악을 들었어요.')).textSpan, isNull);
      expect(find.byType(CoverTape), findsNothing);
    },
  );
}
