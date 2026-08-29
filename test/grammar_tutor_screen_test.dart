import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/data/models/grammar_point.dart';
import 'package:jlpt_practice/features/grammar/grammar_providers.dart';
import 'package:jlpt_practice/features/grammar/grammar_part_tutor_screen.dart';
import 'package:jlpt_practice/features/grammar/grammar_tutor_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('rank tutor moves through explanation and recognition', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [grammarCatalogProvider.overrideWith((_) async => _items)],
        child: const MaterialApp(home: GrammarTutorScreen(grammarId: 'N5_1')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Understand'), findsOneWidget);
    expect(find.text(_target.explanation), findsOneWidget);
    expect(find.text(_target.formation), findsOneWidget);

    await tester.tap(find.text('Check my understanding'));
    await tester.pumpAndSettle();

    expect(find.text('Recognize'), findsOneWidget);
    expect(find.text('What does this grammar point mean?'), findsOneWidget);
    await tester.tap(find.text(_target.summary));
    await tester.pump();

    expect(find.text('Correct'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('part checkpoint diagnoses multiple ranks', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [grammarCatalogProvider.overrideWith((_) async => _items)],
        child: const MaterialApp(
          home: GrammarPartTutorScreen(level: 'N5', part: 1),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Question 1/2'), findsOneWidget);
    await tester.tap(find.textContaining(_target.title));
    await tester.pump();
    await tester.tap(find.text('Next'));
    await tester.pump();

    expect(find.text('Question 2/2'), findsOneWidget);
    await tester.tap(find.textContaining(_distractor.title));
    await tester.pump();
    await tester.tap(find.text('See results'));
    await tester.pumpAndSettle();

    expect(find.text('Part checkpoint complete'), findsOneWidget);
    expect(find.text('Strong'), findsOneWidget);
  });
}

const _items = [_target, _distractor];

const _target = GrammarPoint(
  id: 'N5_1',
  level: 'N5',
  rank: 1,
  title: 'A が いちばん～',
  summary: 'Expresses the superlative.',
  explanation: 'Use it to say that something is the most in a group.',
  formation: 'Noun + が + いちばん',
  examples: [
    GrammarExample(
      japanese: '寿司が一番好きです。',
      reading: 'すしがいちばんすきです。',
      english: 'I like sushi the most.',
    ),
  ],
);

const _distractor = GrammarPoint(
  id: 'N5_2',
  level: 'N5',
  rank: 2,
  title: '～てもいい',
  summary: 'Expresses permission.',
  explanation: 'Use it to give permission.',
  formation: 'Verb て-form + もいい',
  examples: [
    GrammarExample(
      japanese: 'ここに座ってもいいです。',
      reading: 'ここにすわってもいいです。',
      english: 'You may sit here.',
    ),
  ],
);
