import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/features/grammar/grammar_detail_screen.dart';
import 'package:jlpt_practice/features/grammar/grammar_list_screen.dart';
import 'package:jlpt_practice/features/grammar/grammar_providers.dart';

import 'package:jlpt_practice/data/models/grammar_point.dart';

void main() {
  testWidgets('selected app rank filters grammar selection screen', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          grammarCatalogProvider.overrideWith((ref) async => _grammar),
          selectedGrammarLevelProvider.overrideWithValue('N3'),
        ],
        child: const MaterialApp(home: GrammarListScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('N3 Grammar'), findsOneWidget);
    expect(find.text(_n3.title), findsOneWidget);
    expect(find.text(_n5.title), findsNothing);
  });

  testWidgets('plain grammar card opens detail screen with every example', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/grammar',
      routes: [
        GoRoute(path: '/grammar', builder: (_, _) => const GrammarListScreen()),
        GoRoute(
          path: '/grammar/detail/:id',
          builder: (_, state) =>
              GrammarDetailScreen(grammarId: state.pathParameters['id']!),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          grammarCatalogProvider.overrideWith((ref) async => _grammar),
          selectedGrammarLevelProvider.overrideWithValue('N5'),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ExpansionTile), findsNothing);
    expect(find.byIcon(Icons.expand_more), findsNothing);
    await tester.tap(find.text(_n5.title));
    await tester.pumpAndSettle();

    expect(find.text(_n5.explanation), findsOneWidget);
    expect(find.text(_n5.formation), findsOneWidget);
    for (final example in _n5.examples) {
      expect(find.textContaining(example.japanese), findsOneWidget);
      expect(find.text(example.english), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Korean locale displays Korean grammar detail', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          grammarCatalogProvider.overrideWith((ref) async => _grammar),
        ],
        child: const MaterialApp(
          locale: Locale('ko'),
          supportedLocales: [Locale('en'), Locale('ko')],
          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: GrammarDetailScreen(grammarId: 'N5_1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(_n5.summaryKo), findsOneWidget);
    expect(find.text(_n5.explanationKo), findsOneWidget);
    expect(find.text(_n5.formationKo), findsOneWidget);
    for (final example in _n5.examples) {
      expect(find.text(example.korean), findsOneWidget);
    }
    expect(find.text(_n5.explanation), findsNothing);
  });
}

const _grammar = [_n5, _n3];

const _n5 = GrammarPoint(
  id: 'N5_1',
  level: 'N5',
  rank: 1,
  title: 'A が いちばん～',
  summary: 'Expresses the superlative.',
  explanation: 'English explanation.',
  formation: 'Noun + が + いちばん',
  summaryKo: '최상급을 나타냅니다.',
  explanationKo: '한국어 문법 설명입니다.',
  formationKo: 'Noun + が + いちばん',
  examples: [
    GrammarExample(
      japanese: '寿司が一番好きです。',
      romaji: 'Sushi ga ichiban suki desu.',
      english: 'I like sushi the most.',
      korean: '저는 초밥을 가장 좋아합니다.',
    ),
    GrammarExample(
      japanese: '彼女はクラスで一番速く泳げます。',
      romaji: 'Kanojo wa kurasu de ichiban hayaku oyogemasu.',
      english: 'She can swim the fastest in the class.',
      korean: '그녀는 반에서 가장 빨리 수영할 수 있습니다.',
    ),
  ],
);

const _n3 = GrammarPoint(
  id: 'N3_1',
  level: 'N3',
  rank: 1,
  title: 'A その上 B',
  summary: 'Expresses additional information.',
  explanation: 'N3 explanation.',
  formation: 'A + その上 + B',
  examples: [],
);
