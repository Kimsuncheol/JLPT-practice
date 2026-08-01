import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/data/models/grammar_point.dart';
import 'package:jlpt_practice/features/grammar/grammar_list_screen.dart';
import 'package:jlpt_practice/features/grammar/grammar_providers.dart';

void main() {
  testWidgets('grammar details expand without framework errors', (
    tester,
  ) async {
    const grammar = GrammarPoint(
      id: 'N5_1',
      level: 'N5',
      rank: 1,
      title: 'A が いちばん～ (A ga ichiban～)',
      summary: "Express the superlative degree; 'the most', 'the best'.",
      explanation: 'Explains how the grammar point is used.',
      formation: 'Noun + が + いちばん + Adjective/Verb',
      summaryKo: "최상급을 나타내며 '가장', '제일'이라는 뜻입니다.",
      explanationKo: '이 문법 항목의 사용법을 설명합니다.',
      formationKo: '명사 + が + いちばん + 형용사/동사',
      examples: [
        GrammarExample(
          japanese: '寿司が一番好きです。',
          romaji: 'Sushi ga ichiban suki desu.',
          english: 'I like sushi the most.',
          korean: '저는 초밥을 가장 좋아합니다.',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          grammarCatalogProvider.overrideWith((ref) async => [grammar]),
        ],
        child: const MaterialApp(home: GrammarListScreen(level: 'N5')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(grammar.title));
    await tester.pumpAndSettle();

    expect(find.text(grammar.formation), findsOneWidget);
    expect(find.text(grammar.explanation), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected app rank filters grammar study', (tester) async {
    final grammar = [
      const GrammarPoint(
        id: 'N5_1',
        level: 'N5',
        rank: 1,
        title: 'N5 grammar',
        summary: 'N5 summary',
        explanation: 'N5 explanation',
        formation: 'N5 formation',
        examples: [],
      ),
      const GrammarPoint(
        id: 'N3_1',
        level: 'N3',
        rank: 1,
        title: 'N3 grammar',
        summary: 'N3 summary',
        explanation: 'N3 explanation',
        formation: 'N3 formation',
        examples: [],
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          grammarCatalogProvider.overrideWith((ref) async => grammar),
          selectedGrammarLevelProvider.overrideWithValue('N3'),
        ],
        child: const MaterialApp(home: GrammarListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('N3 Grammar'), findsOneWidget);
    expect(find.text('N3 grammar'), findsOneWidget);
    expect(find.text('N5 grammar'), findsNothing);
  });

  testWidgets('Korean locale displays Korean grammar explanations', (
    tester,
  ) async {
    const grammar = GrammarPoint(
      id: 'N5_1',
      level: 'N5',
      rank: 1,
      title: 'A が いちばん～',
      summary: 'Expresses the superlative.',
      explanation: 'English explanation.',
      formation: 'Noun + が + いちばん',
      summaryKo: '최상급을 나타냅니다.',
      explanationKo: '한국어 문법 설명입니다.',
      formationKo: '명사 + が + いちばん',
      examples: [
        GrammarExample(
          japanese: '寿司が一番好きです。',
          romaji: 'Sushi ga ichiban suki desu.',
          english: 'I like sushi the most.',
          korean: '저는 초밥을 가장 좋아합니다.',
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          grammarCatalogProvider.overrideWith((ref) async => [grammar]),
        ],
        child: const MaterialApp(
          locale: Locale('ko'),
          supportedLocales: [Locale('en'), Locale('ko')],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: GrammarListScreen(level: 'N5'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(grammar.title));
    await tester.pumpAndSettle();

    expect(find.text(grammar.summaryKo), findsOneWidget);
    expect(find.text(grammar.explanationKo), findsOneWidget);
    expect(find.text(grammar.formationKo), findsOneWidget);
    expect(find.text(grammar.examples.single.korean), findsOneWidget);
    expect(find.text(grammar.explanation), findsNothing);
  });
}
