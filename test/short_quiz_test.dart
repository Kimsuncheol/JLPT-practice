import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/data/models/vocabulary.dart';
import 'package:jlpt_practice/features/vocabulary/short_quiz.dart';
import 'package:jlpt_practice/features/vocabulary/short_quiz_game.dart';

Vocabulary entry(String word, String answer, {String? quizSentence}) =>
    Vocabulary(
      id: word,
      word: word,
      reading: 'たべる',
      furigana: '',
      romaji: '',
      meanings: const {
        'en': ['eat'],
      },
      partOfSpeech: 'verb',
      jlptLevel: 'N5',
      tags: const [],
      example: VocabularyExample(
        sentence: '毎朝パンを$answer。',
        sentenceFurigana:
            '{毎朝|まいあさ}パンを{${answer.substring(0, 1)}|${word == '飲む'
                ? 'の'
                : word == '読む'
                ? 'よ'
                : 'た'}}${answer.substring(1)}。',
        translations: const {'en': 'I eat bread every morning.'},
        quizSentence: quizSentence ?? '毎朝パンを＿＿＿。',
        answer: answer,
      ),
    );

void main() {
  final eat = entry('食べる', '食べます');
  final drink = entry('飲む', '飲みます');
  final read = entry('読む', '読みます');
  final quiz = buildShortQuiz(eat, [eat, drink, read], random: Random(1))!;

  test('grades the inflected answer and removes its text and ruby', () {
    expect(quiz.grade('食べます'), isTrue);
    expect(quiz.grade('食べる'), isFalse);
    expect(quiz.grade('飲みます'), isFalse);
    expect(quiz.segments.map((segment) => segment.text).join(), '毎朝パンを\uFFFC。');
    expect(quiz.segments.map((segment) => segment.ruby), isNot(contains('た')));
    expect(quiz.segments.first.ruby, 'まいあさ');
    expect(quiz.options.toSet().length, quiz.options.length);
    expect(quiz.optionReadings['食べます'], 'たべます');
    expect(quiz.optionReadings['飲みます'], 'のみます');
    expect(quiz.optionReadings['読みます'], 'よみます');
  });

  test('declines mismatched examples and quizzes without distractors', () {
    expect(
      buildShortQuiz(entry('食べる', '食べます', quizSentence: '違う＿＿＿。'), [
        eat,
        drink,
      ]),
      isNull,
    );
    expect(buildShortQuiz(eat, [eat]), isNull);
  });

  testWidgets('options with and without furigana have equal heights', (
    tester,
  ) async {
    final mixedQuiz = ShortQuiz(
      entry: eat,
      start: quiz.start,
      end: quiz.end,
      answer: quiz.answer,
      options: const ['食べます', 'もっと', '飲みます'],
      optionReadings: quiz.optionReadings,
    );
    for (final scale in [1.0, 2.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: ShortQuizGame(quiz: mixedQuiz, showFurigana: false),
            ),
          ),
        ),
      );
      final heights = mixedQuiz.options.map(
        (option) =>
            tester.getSize(find.widgetWithText(ActionChip, option)).height,
      );
      expect(heights.toSet(), hasLength(1));
      expect(
        tester.getCenter(find.text('もっと')).dy,
        closeTo(
          tester.getCenter(find.widgetWithText(ActionChip, 'もっと')).dy,
          0.01,
        ),
      );
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('hover, answer travel and immediate centered feedback', (
    tester,
  ) async {
    Future<void> mountGame() async {
      String? selection;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    ShortQuizGame(
                      quiz: quiz,
                      showFurigana: false,
                      onSelected: (answer) =>
                          setState(() => selection = answer),
                    ),
                    if (selection != null)
                      ShortQuizFeedback(quiz: quiz, selection: selection!),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    await mountGame();
    expect(find.text('たべます'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('short-quiz-reading-飲みます')),
      findsOneWidget,
    );
    final wrong = find.widgetWithText(ActionChip, '飲みます');
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(wrong));
    await tester.pumpAndSettle();
    final hoverColor = tester.widget<ActionChip>(wrong).color?.resolve({
      WidgetState.hovered,
    });
    expect(hoverColor, isNotNull);
    await tester.tap(wrong);
    await tester.pump();
    expect(find.byIcon(Icons.cancel_rounded), findsNothing);
    expect(find.text('Not quite · Answer: 食べます'), findsOneWidget);
    final incorrectImage = tester.widget<Image>(
      find.byKey(const ValueKey('short-quiz-feedback-image')),
    );
    expect(
      (incorrectImage.image as AssetImage).assetName,
      'assets/images/short_quiz/incorrect-reference.png',
    );
    expect(incorrectImage.width, 24);
    expect(incorrectImage.height, 24);
    expect(find.widgetWithText(ActionChip, '飲みます'), findsNothing);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('short-quiz-blank'))).data,
      '飲みます',
    );
    expect(find.widgetWithText(Chip, '飲みます'), findsOneWidget);
    expect(
      tester
          .widget<Opacity>(
            find.ancestor(
              of: find.byKey(const ValueKey('short-quiz-selected-chip')),
              matching: find.byType(Opacity),
            ),
          )
          .opacity,
      1,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Try again'), findsNothing);
    await mountGame();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, '食べます'));
    await tester.pump();
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
    expect(find.text('Correct'), findsOneWidget);
    final correctImage = tester.widget<Image>(
      find.byKey(const ValueKey('short-quiz-feedback-image')),
    );
    expect(
      (correctImage.image as AssetImage).assetName,
      'assets/images/short_quiz/correct-reference.png',
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('short-quiz-blank'))).data,
      '食べます',
    );
    expect(find.widgetWithText(Chip, '食べます'), findsOneWidget);
    expect(find.text('たべます'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await mouse.removePointer();
  });
}
