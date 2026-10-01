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
}
