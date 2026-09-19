import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/app/router.dart';
import 'package:jlpt_practice/features/kana/kana_chart_screen.dart';
import 'package:jlpt_practice/features/kana/kana_data.dart';

void main() {
  test('catalog contains 46 basic kana in each script', () {
    expect(KanaCatalog.forScript(KanaScript.hiragana), hasLength(46));
    expect(KanaCatalog.forScript(KanaScript.katakana), hasLength(46));
  });

  testWidgets('kana chart switches between hiragana and katakana', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: KanaChartScreen()));

    expect(find.text('あ'), findsOneWidget);
    await tester.tap(find.text('Katakana'));
    await tester.pumpAndSettle();
    expect(find.text('ア'), findsOneWidget);
  });

  testWidgets('/kana route opens the kana chart', (tester) async {
    final router = createAppRouter(initialLocation: '/kana');
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.byType(KanaChartScreen), findsOneWidget);
    expect(find.text('Hiragana & Katakana'), findsOneWidget);
  });
}
