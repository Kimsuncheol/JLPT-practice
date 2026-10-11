import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/core/services/meaning_mask_service.dart';
import 'package:jlpt_practice/features/vocabulary/cover_tape.dart';
import 'package:jlpt_practice/features/vocabulary/masked_translation.dart';
import 'package:jlpt_practice/features/vocabulary/cover_masking.dart';

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
      final masked = tester.widget<Text>(find.byType(Text));
      final covered = (masked.textSpan! as TextSpan).children!
          .whereType<TextSpan>()
          .singleWhere((span) => span.text == '들었어요');
      expect(covered.style!.foreground!.color, Colors.transparent);
      expect(covered.semanticsLabel, isEmpty);
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(find.text('음악을 들었어요.')).textSpan, isNull);
      expect(find.byType(CoverTape), findsNothing);
    },
  );

  testWidgets('masked translations preserve wrapping and size', (tester) async {
    const translation = 'I use the wide vocabulary word every day to practice.';
    const style = TextStyle(fontSize: 16, height: 1.3);
    for (final width in [140.0, 230.0]) {
      Widget build(bool hide) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: hide
                  ? MaskedSegmentsText(
                      segments: maskSegments(translation, [
                        'wide vocabulary word',
                      ]),
                      style: style,
                      glyphWidth: 0.55,
                      textAlign: TextAlign.start,
                    )
                  : const Text(translation, style: style),
            ),
          ),
        ),
      );
      await tester.pumpWidget(build(false));
      final before = tester.getRect(find.byType(RichText));
      await tester.pumpWidget(build(true));
      expect(tester.getRect(find.byType(RichText)), before);
    }
  });

  testWidgets('empty Korean analysis keeps matching meanings hidden', (
    tester,
  ) async {
    final service = MeaningMaskService(_Analyzer());
    addTearDown(service.close);
    final container = ProviderContainer(
      overrides: [meaningMaskServiceProvider.overrideWithValue(service)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: Scaffold(
            body: MaskedTranslation(
              translation: '매일 연습합니다.',
              meanings: ['연습'],
              hideMeanings: true,
              style: TextStyle(fontSize: 16),
              glyphWidth: 0.55,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final text = tester.widget<Text>(find.byType(Text));
    final hidden = (text.textSpan! as TextSpan).children!
        .whereType<TextSpan>()
        .singleWhere((span) => span.text == '연습');
    expect(hidden.style!.foreground!.color, Colors.transparent);
    expect(hidden.semanticsLabel, isEmpty);
  });
}
