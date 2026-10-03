import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/data/models/kanji.dart';
import 'package:jlpt_practice/features/vocabulary/cover_tape.dart';
import 'package:jlpt_practice/features/vocabulary/example_furigana_text.dart';

void main() {
  Widget example(
    String marked, {
    double width = 300,
    bool hideReadings = false,
    WrapAlignment alignment = WrapAlignment.center,
  }) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: width,
          child: ExampleFuriganaText(
            segments: parseFurigana(marked),
            style: const TextStyle(fontSize: 22),
            wordTargets: const [],
            hideReadings: hideReadings,
            alignment: alignment,
          ),
        ),
      ),
    ),
  );

  testWidgets('only kanji receive readings above the written form', (
    tester,
  ) async {
    await tester.pumpWidget(example('パンを{食|た}べます。'));

    final ruby = find.text('た', findRichText: true);
    final base = find.text('食');
    expect(ruby, findsOneWidget);
    expect(base, findsOneWidget);
    expect(
      tester.getBottomLeft(ruby).dy,
      lessThanOrEqualTo(tester.getTopLeft(base).dy),
    );
    expect(find.text('パンをたべます。'), findsNothing);
    expect(find.text('(た)'), findsNothing);
    expect(find.text('（た）'), findsNothing);
  });

  for (final hideReadings in [false, true]) {
    for (final separator in [' ', '\n']) {
      testWidgets(
        'speaker turns have a 20px gap (hidden: $hideReadings, separator: ${separator.codeUnits})',
        (tester) async {
          await tester.pumpWidget(
            example(
              'A: {手伝|てつだ}いましょうか?${separator}B: ええ、{願|ねが}います。',
              width: 600,
              hideReadings: hideReadings,
            ),
          );
          final firstBase = find.text('手伝');
          final secondBase = find.text('願');
          // Each ruby unit reserves 16px above its base, including its tape.
          final secondRowTop = tester.getTopLeft(secondBase).dy - 16;
          expect(
            secondRowTop - tester.getBottomLeft(firstBase).dy,
            closeTo(20, 0.01),
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('kana-only dialogue also separates speaker turns by 20px', (
    tester,
  ) async {
    await tester.pumpWidget(example('A: はい。 B: ええ。', width: 600));
    expect(
      tester.getTopLeft(find.text('B')).dy -
          tester.getBottomLeft(find.text('A')).dy,
      closeTo(20, 0.01),
    );
  });

  testWidgets('speaker turns align to the leading edge', (tester) async {
    await tester.pumpWidget(
      example(
        'A: {手伝|てつだ}いましょうか? B: ええ、{願|ねが}います。',
        width: 600,
        alignment: WrapAlignment.start,
      ),
    );
    expect(
      tester.getTopLeft(find.text('A')).dx,
      tester.getTopLeft(find.text('B')).dx,
    );
  });

  testWidgets('kana-only sentences have no ruby', (tester) async {
    await tester.pumpWidget(example('パンをたべます。'));
    expect(find.byKey(const ValueKey('example-ruby-0')), findsNothing);
    expect(find.byType(Text), findsNWidgets(8));
  });

  testWidgets('hiding readings covers all ruby, including inflected kanji', (
    tester,
  ) async {
    const marked = '{毎朝|まいあさ}パンを{食|た}べます。';
    await tester.pumpWidget(example(marked, hideReadings: true));
    expect(find.text('まいあさ', findRichText: true), findsNothing);
    expect(find.text('た', findRichText: true), findsNothing);
    expect(find.byType(CoverTape), findsNWidgets(2));
    expect(find.text('毎朝'), findsOneWidget);
    expect(find.text('食'), findsOneWidget);
    expect(find.text('べ'), findsOneWidget);

    await tester.pumpWidget(example(marked));
    expect(find.text('まいあさ', findRichText: true), findsOneWidget);
    expect(find.text('た', findRichText: true), findsOneWidget);
    expect(find.byType(CoverTape), findsNothing);
  });

  testWidgets('a long example wraps while each ruby stays with its kanji', (
    tester,
  ) async {
    await tester.pumpWidget(
      example('{毎朝|まいあさ}パンを{食|た}べます。{今日|きょう}もパンを{食|た}べます。', width: 120),
    );

    expect(tester.takeException(), isNull);
    final first = find.text('毎朝');
    final later = find.text('今日');
    expect(
      tester.getTopLeft(later).dy,
      greaterThan(tester.getTopLeft(first).dy),
    );
    expect(find.text('た', findRichText: true), findsNWidgets(2));
  });

  for (final hideReadings in [false, true]) {
    testWidgets(
      'period wraps with preceding kana (hideReadings: $hideReadings)',
      (tester) async {
        await tester.pumpWidget(
          example('あいう。', width: 70, hideReadings: hideReadings),
        );

        expect(tester.takeException(), isNull);
        expect(
          tester.getTopLeft(find.text('う')).dy,
          greaterThan(tester.getTopLeft(find.text('あ')).dy),
        );
        expect(
          tester.getTopLeft(find.text('。')).dy,
          tester.getTopLeft(find.text('う')).dy,
        );
      },
    );
  }

  testWidgets('period stays with kanji across segment boundaries', (
    tester,
  ) async {
    await tester.pumpWidget(example('あい{犬|いぬ}。', width: 70));

    expect(tester.takeException(), isNull);
    expect(
      tester.getTopLeft(find.text('。')).dy,
      tester.getTopLeft(find.text('犬')).dy,
    );
    expect(find.text('いぬ', findRichText: true), findsOneWidget);
  });

  testWidgets('wrapped kana-only rows use the hidden-reading spacing', (
    tester,
  ) async {
    const marked = '{犬|いぬ}あいう。{毎朝|まいあさ}か。';
    await tester.pumpWidget(example(marked, width: 70));

    double gap(String before, String after) =>
        tester.getTopLeft(find.text(after)).dy -
        tester.getBottomLeft(find.text(before)).dy;

    final kanaGap = gap('犬', 'う');
    final readingGap = gap('う', '毎朝');
    expect(kanaGap, closeTo(2, 0.01));
    expect(readingGap, greaterThan(kanaGap));
    expect(gap('毎朝', 'か'), kanaGap);
    expect(
      tester.getTopLeft(find.text('まいあさ', findRichText: true)).dy,
      greaterThanOrEqualTo(tester.getBottomLeft(find.text('う')).dy),
    );

    await tester.pumpWidget(example(marked, width: 70, hideReadings: true));
    expect(gap('犬', 'う'), kanaGap);
    // Hidden ruby still reserves space for its masking tape.
    expect(gap('う', '毎朝'), closeTo(kanaGap + 16, 0.01));
    expect(gap('毎朝', 'か'), kanaGap);
    expect(tester.takeException(), isNull);
  });
}
