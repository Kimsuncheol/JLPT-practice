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
        GoRoute(
          path: '/grammar/tutor/:id',
          builder: (_, state) =>
              Scaffold(body: Text('Practice ${state.pathParameters['id']}')),
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

    expect(find.byType(ExpansionTile), findsOneWidget);
    expect(find.textContaining('Part 1'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is IconButton && widget.tooltip == 'Practise with AI',
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text(_n5.title));
    await tester.pumpAndSettle();

    expect(find.text(_n5.explanation), findsOneWidget);
    expect(find.text(_n5.formation), findsOneWidget);
    for (final (index, example) in _n5.examples.indexed) {
      final sentence = find.byKey(ValueKey('grammar-example-${index + 1}'));
      await tester.scrollUntilVisible(
        sentence,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(sentence, findsOneWidget);
      expect(find.text(example.reading), findsNothing);
      expect(
        tester
            .widget<Container>(
              find.byKey(ValueKey('grammar-example-container-${index + 1}')),
            )
            .decoration,
        isNull,
      );
      for (final segment in example.sentenceSegments.where(
        (segment) => segment.ruby != null,
      )) {
        final ruby = find.descendant(
          of: sentence,
          matching: find.text(segment.ruby!, findRichText: true),
        );
        final base = find.descendant(
          of: sentence,
          matching: find.text(segment.text),
        );
        expect(ruby, findsOneWidget);
        expect(base, findsOneWidget);
        expect(
          tester.getBottomLeft(ruby).dy,
          lessThanOrEqualTo(tester.getTopLeft(base).dy),
        );
      }
      expect(find.text(example.english), findsOneWidget);
    }
    final actions = find.byKey(const ValueKey('grammar_detail_actions'));
    final trigger = find.byKey(const ValueKey('grammar_detail_ai_trigger'));
    final practiceButton = find.byKey(
      const ValueKey('grammar_detail_practice_with_ai'),
    );
    final tutorButton = find.byKey(const ValueKey('grammar_detail_tutor'));
    expect(actions, findsNothing);
    expect(trigger, findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(
      tester.widget<FloatingActionButton>(trigger).shape,
      const CircleBorder(),
    );
    expect(practiceButton, findsNothing);
    expect(tutorButton, findsNothing);

    await tester.tap(trigger);
    await tester.pumpAndSettle();

    expect(practiceButton, findsOneWidget);
    expect(tutorButton, findsOneWidget);
    expect(find.text('Practise with AI'), findsOneWidget);
    expect(find.text('Grammar Tutor'), findsOneWidget);
    expect(
      tester.getTopLeft(practiceButton).dy,
      lessThan(tester.getTopLeft(tutorButton).dy),
    );

    await tester.tap(tutorButton);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('grammar_chat_close')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('grammar_chat_close')));
    await tester.pumpAndSettle();

    await tester.tap(trigger);
    await tester.pumpAndSettle();
    await tester.tap(practiceButton);
    await tester.pumpAndSettle();
    expect(find.text('Practice N5_1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AI menu bar adapts to light and dark appearance modes', (
    tester,
  ) async {
    for (final brightness in Brightness.values) {
      final theme = brightness == Brightness.light
          ? ThemeData.light(useMaterial3: true)
          : ThemeData.dark(useMaterial3: true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            grammarCatalogProvider.overrideWith((ref) async => _grammar),
          ],
          child: MaterialApp(
            theme: theme,
            home: const GrammarDetailScreen(grammarId: 'N5_1'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final menuAnchor = tester.widget<MenuAnchor>(
        find.byKey(const ValueKey('grammar_detail_ai_menu')),
      );
      final resolvedBg = menuAnchor.style?.backgroundColor?.resolve(const {});
      final expectedBg = brightness == Brightness.dark
          ? theme.colorScheme.surfaceContainerHigh
          : theme.colorScheme.surface;
      expect(resolvedBg, expectedBg);
    }
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
    expect(find.text('AI로 연습하기'), findsNothing);
    expect(find.text('문법 튜터'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('grammar_detail_ai_trigger')));
    await tester.pumpAndSettle();

    expect(find.text('AI로 연습하기'), findsOneWidget);
    expect(find.text('문법 튜터'), findsOneWidget);
    for (final example in _n5.examples) {
      await tester.scrollUntilVisible(
        find.text(example.korean),
        200,
        scrollable: find.byType(Scrollable).last,
      );
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
      reading: 'すしがいちばんすきです。',
      english: 'I like sushi the most.',
      korean: '저는 초밥을 가장 좋아합니다.',
    ),
    GrammarExample(
      japanese: '彼女はクラスで一番速く泳げます。',
      reading: 'かのじょはクラスでいちばんはやくおよげます。',
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
