import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jlpt_practice/app/app_controller.dart';
import 'package:jlpt_practice/app/theme/app_theme.dart';
import 'package:jlpt_practice/data/models/kanji.dart';
import 'package:jlpt_practice/data/repositories/kanji_repository.dart';
import 'package:jlpt_practice/features/kanji/kanji_finish_screen.dart';
import 'package:jlpt_practice/features/kanji/kanji_study_screen.dart';
import 'package:jlpt_practice/features/vocabulary/cover_tape.dart';
import 'package:jlpt_practice/features/vocabulary/day_selection_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/kanji_test_support.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('speech text drops dictionary markers for okurigana and affixes', () {
    expect(kanjiReadingForSpeech('ひと.つ'), 'ひとつ');
    expect(kanjiReadingForSpeech('ひと-'), 'ひと');
    expect(kanjiReadingForSpeech('いち'), 'いち');
  });

  test('furigana markup splits into segments with and without readings', () {
    expect(parseFurigana('りんごを{一|ひと}つください。'), const [
      FuriganaSegment('りんごを'),
      FuriganaSegment('一', 'ひと'),
      FuriganaSegment('つください。'),
    ]);
    expect(parseFurigana('かな'), const [FuriganaSegment('かな')]);
    expect(parseFurigana(''), isEmpty);
  });

  test('a sentence without readings is one plain segment', () {
    final example = KanjiExample.fromJson({'sentence_jp': 'ある。'});
    expect(example.sentenceSegments, const [FuriganaSegment('ある。')]);
  });

  test('every bundled example sentence has matching furigana', () {
    final raw = jsonDecode(
      File('assets/data/JLPT_Kanji.json').readAsStringSync(),
    );
    var checked = 0;
    for (final item in raw as List<dynamic>) {
      final kanji = Kanji.fromJson(item as Map<String, dynamic>);
      for (final example in [...kanji.kunExamples, ...kanji.onExamples]) {
        final plain = example.sentenceSegments.map((s) => s.text).join();
        for (final segment in example.sentenceSegments) {
          if (segment.ruby != null) {
            expect(RegExp(r'^[㐀-䶿一-鿿々〆]+$').hasMatch(segment.text), isTrue);
          }
        }
        expect(plain, example.sentence, reason: kanji.character);
        checked++;
      }
    }
    expect(checked, greaterThan(9000));
  });

  test('the bundled kanji data parses into every JLPT level', () {
    final raw = jsonDecode(
      File('assets/data/JLPT_Kanji.json').readAsStringSync(),
    );
    final catalog = [
      for (final item in raw as List<dynamic>)
        Kanji.fromJson(item as Map<String, dynamic>),
    ];

    for (final level in ['N5', 'N4', 'N3', 'N2', 'N1']) {
      expect(kanjiForLevel(catalog, level), isNotEmpty, reason: level);
    }
    final first = kanjiForLevel(catalog, 'N5').first;
    expect(first.character, '一');
    expect(first.frontKunYomi, ['ひと-']);
    expect(first.frontOnYomi, ['いち', 'いつ']);
    expect(first.kunExamples, isNotEmpty);
    expect(first.onExamples.first.meaning('en'), isNotEmpty);
  });

  testWidgets('front shows the kanji, first kun and first two on readings', (
    tester,
  ) async {
    await _pumpStudy(tester);

    final front = find.byKey(const ValueKey('kanji-front'));
    expect(_inFront(find.text('一')), findsOneWidget);
    expect(_inFront(find.text('ひと-')), findsOneWidget);
    expect(_inFront(find.text('ひと.つ')), findsNothing);
    expect(_inFront(find.text('いち')), findsOneWidget);
    expect(_inFront(find.text('いつ')), findsOneWidget);
    expect(_inFront(find.text('イチ')), findsNothing);
    expect(front, findsOneWidget);
  });

  testWidgets('a kanji without kun readings shows only the on readings', (
    tester,
  ) async {
    await _pumpStudy(tester);
    await _swipeNext(tester);

    expect(_inFront(find.text('に')), findsOneWidget);
    expect(_inFront(find.text("Kun'yomi")), findsNothing);
  });

  testWidgets('tapping a reading speaks that reading alone', (tester) async {
    final speech = await _pumpStudy(tester);

    await tester.tap(_inFront(find.text('ひと-')));
    await tester.pumpAndSettle();
    await tester.tap(_inFront(find.text('いつ')));
    await tester.pumpAndSettle();

    expect(speech.spoken, ['ひと', 'いつ']);
    // Tapping a reading never flips the card.
    expect(_inFront(find.text('一')), findsOneWidget);
    expect(speech.events.where((event) => event == 'stop'), isEmpty);
  });

  testWidgets('back lists every reading with its examples', (tester) async {
    await _pumpStudy(tester);
    await _flip(tester);

    expect(_inBack(find.text('ひと.つ')), findsOneWidget);
    expect(_inBack(find.text('イチ')), findsOneWidget);
    expect(_inBack(find.text('いつ')), findsOneWidget);
    expect(_inBack(find.text('一つ')), findsOneWidget);
    expect(_inBack(find.text('one thing')), findsOneWidget);
    expect(_inBack(find.text('一部')), findsWidgets);
    expect(_inBack(find.text('part')), findsOneWidget);
    expect(_inBack(find.text("Kun'yomi")), findsOneWidget);
    expect(_inBack(find.text("On'yomi")), findsOneWidget);
  });

  testWidgets('tapping a back-side reading speaks that reading alone', (
    tester,
  ) async {
    final speech = await _pumpStudy(tester);
    await _flip(tester);
    speech.events.clear();

    await tester.tap(_inBack(find.text('ひと.つ')));
    await tester.pumpAndSettle();

    expect(speech.spoken, ['ひとつ']);
  });

  testWidgets('flipping the card stops speech that is playing', (tester) async {
    final speech = await _pumpStudy(tester);
    await tester.tap(_inFront(find.text('いち')));
    await tester.pumpAndSettle();
    expect(speech.events, ['speak:いち']);

    await tester.tap(_inFront(find.text('一')));
    await tester.pumpAndSettle();

    expect(speech.events, ['speak:いち', 'stop']);
  });

  testWidgets('swiping to another kanji stops speech that is playing', (
    tester,
  ) async {
    final speech = await _pumpStudy(tester);
    await _flip(tester);
    await tester.tap(_inBack(find.text('ひと.つ')));
    await tester.pumpAndSettle();
    expect(speech.events, ['speak:ひとつ']);
    speech.events.clear();

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(speech.events, ['stop']);
    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets('leaving the screen stops speech', (tester) async {
    final speech = await _pumpStudy(tester);
    await tester.tap(_inFront(find.text('いち')));
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox());

    expect(speech.events.last, 'stop');
  });

  testWidgets('automatic pronunciation reads the first front reading', (
    tester,
  ) async {
    final speech = await _pumpStudy(tester, autoPlayAudio: true);
    expect(speech.spoken, ['ひと']);

    await _swipeNext(tester);
    expect(speech.spoken, ['ひと', 'に']);
  });

  testWidgets('front hide group covers kanji, kun and on separately', (
    tester,
  ) async {
    await _pumpStudy(tester);
    expect(find.byKey(const ValueKey('hide-group-front')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('hide-front-kanji')));
    await tester.pumpAndSettle();
    expect(_inFront(find.text('一')), findsNothing);
    expect(_inFront(find.byType(CoverTape)), findsOneWidget);
    expect(find.text('Show kanji'), findsOneWidget);
    // Toggling never flips the card.
    expect(_inFront(find.text('いち')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('hide-front-kun')));
    await tester.pumpAndSettle();
    expect(_inFront(find.text('ひと-')), findsNothing);
    expect(_inFront(find.text('いち')), findsOneWidget);
    expect(_inFront(find.byType(CoverTape)), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('hide-front-on')));
    await tester.pumpAndSettle();
    expect(_inFront(find.text('いち')), findsNothing);
    expect(_inFront(find.text('いつ')), findsNothing);
    expect(_inFront(find.byType(CoverTape)), findsNWidgets(4));

    for (final id in ['kanji', 'kun', 'on']) {
      await tester.tap(find.byKey(ValueKey('hide-front-$id')));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(_inFront(find.text('ひと-')), findsOneWidget);
    expect(_inFront(find.text('一')), findsOneWidget);
    expect(_inFront(find.text('いち')), findsOneWidget);
  });

  testWidgets('covered readings can still be tapped to hear them', (
    tester,
  ) async {
    final speech = await _pumpStudy(tester);
    await tester.tap(find.byKey(const ValueKey('hide-front-on')));
    await tester.pumpAndSettle();

    await tester.tap(_inFront(find.byKey(const ValueKey('reading-いち'))));
    await tester.pumpAndSettle();

    expect(speech.spoken, ['いち']);
  });

  testWidgets('back hide group covers kun, on, reading and meanings', (
    tester,
  ) async {
    await _pumpStudy(tester);
    await _flip(tester);
    expect(find.byKey(const ValueKey('hide-group-back')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('hide-back-meanings')));
    await tester.pumpAndSettle();
    expect(_inBack(find.text('one thing')), findsNothing);
    expect(_inBack(find.text('part')), findsNothing);
    expect(_inBack(find.text('一つ')), findsOneWidget);
    expect(_inBack(find.text('ひとつ')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('hide-back-kun')));
    await tester.pumpAndSettle();
    expect(_inBack(find.text('ひと.つ')), findsNothing);
    expect(_inBack(find.text('ひとつ')), findsNothing);
    expect(_inBack(find.text('一つ')), findsOneWidget);
    // On'yomi stays visible until it is covered on its own.
    expect(_inBack(find.text('いつ')), findsOneWidget);
    expect(_inBack(find.text('いちぶ')), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('hide-back-on')));
    await tester.pumpAndSettle();
    expect(_inBack(find.text('いつ')), findsNothing);
    // Only the sentence furigana still shows いちぶ; the word reading is covered.
    expect(_inBack(find.text('いちぶ')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('hide-back-furigana')));
    await tester.pumpAndSettle();
    expect(_inBack(find.text('いちぶ')), findsNothing);
  });

  testWidgets('hidden state is shared by both sides and kept per kanji', (
    tester,
  ) async {
    await _pumpStudy(tester);
    await tester.tap(find.byKey(const ValueKey('hide-front-kun')));
    await tester.pumpAndSettle();
    await _flip(tester);
    expect(_inBack(find.text('ひと.つ')), findsNothing);

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(_inFront(find.text('に')), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(_inFront(find.text('ひと-')), findsNothing);
  });

  testWidgets('back shows the kanji even when it was covered on the front', (
    tester,
  ) async {
    await _pumpStudy(tester);
    await tester.tap(find.byKey(const ValueKey('hide-front-kanji')));
    await tester.pumpAndSettle();
    await _flip(tester);

    expect(_inBack(find.byKey(const ValueKey('sentence-一つ'))), findsOneWidget);
  });

  testWidgets('settings button opens the study settings screen', (
    tester,
  ) async {
    await _pumpStudy(tester);

    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Settings route'), findsOneWidget);
  });

  testWidgets('swiping past the last kanji opens the finish screen', (
    tester,
  ) async {
    final controller = KanjiTestAppController();
    await _pumpStudy(tester, controller: controller);
    expect(find.text('Finish'), findsNothing);

    await _swipeNext(tester);
    await _flip(tester);
    expect(find.text('Finish'), findsNothing);
    await _swipeForward(tester);

    expect(find.text('Great work!'), findsOneWidget);
    expect(controller.completions, isEmpty);
    await tester.tap(find.text('Finish'));
    await tester.pumpAndSettle();

    expect(controller.completions, [('kanji-N5', 1)]);
    expect(find.text('Kanji day list'), findsOneWidget);
  });

  testWidgets('start over sits in a four-item hide group on the last kanji', (
    tester,
  ) async {
    await _pumpStudy(tester);
    expect(find.byKey(const ValueKey('hide-front-action')), findsNothing);
    await _swipeForward(tester);
    expect(find.byKey(const ValueKey('hide-front-action')), findsOneWidget);
    await _flip(tester);

    expect(find.byKey(const ValueKey('hide-back-action')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('hide-group-back')),
        matching: find.text('Start over'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('start over returns to the first kanji', (tester) async {
    await _pumpStudy(tester);
    await _swipeNext(tester);
    await _flip(tester);

    await tester.tap(find.text('Start over').hitTestable());
    await tester.pumpAndSettle();

    expect(find.text('1 / 2'), findsOneWidget);
  });

  testWidgets('cannot swipe to the next kanji before flipping to the back', (
    tester,
  ) async {
    await _pumpStudy(tester);
    expect(
      find.text('Flip the card to continue').hitTestable(),
      findsOneWidget,
    );

    await _swipeForward(tester);
    await _swipeForward(tester);

    expect(find.text('1 / 2'), findsOneWidget);
    expect(_inFront(find.text('一')), findsOneWidget);
  }, skip: true); // flip-to-continue is switched off (_requireFlip)

  testWidgets('swiping on works once the back has been seen', (tester) async {
    await _pumpStudy(tester);
    await _flip(tester);
    expect(find.text('Flip the card to continue').hitTestable(), findsNothing);

    await _swipeForward(tester);

    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets('the next kanji is locked too, but going back is always free', (
    tester,
  ) async {
    await _pumpStudy(tester);
    await _swipeNext(tester);
    expect(
      find.text('Flip the card to continue').hitTestable(),
      findsOneWidget,
    );

    await _swipeForward(tester);
    expect(find.text('2 / 2'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(find.text('1 / 2'), findsOneWidget);
    // The first kanji was already seen, so it does not lock again.
    await _swipeForward(tester);
    expect(find.text('2 / 2'), findsOneWidget);
  }, skip: true); // flip-to-continue is switched off (_requireFlip)

  testWidgets('flipping back to the front keeps the swipe unlocked', (
    tester,
  ) async {
    await _pumpStudy(tester);
    await _flip(tester);
    await tester.tap(_inBack(find.byKey(const ValueKey('sentence-一つ'))).first);
    await tester.pumpAndSettle();

    await _swipeForward(tester);

    expect(find.text('2 / 2'), findsOneWidget);
  });

  testWidgets('tapping an example sentence speaks that sentence', (
    tester,
  ) async {
    final speech = await _pumpStudy(tester);
    await _flip(tester);

    for (final word in ['一つ', '一部']) {
      final sentence = _inBack(find.byKey(ValueKey('sentence-$word')));
      await tester.ensureVisible(sentence);
      await tester.pumpAndSettle();
      await tester.tap(sentence);
      await tester.pumpAndSettle();
    }

    expect(speech.spoken, ['りんごを一つください。', '一部が遅れた。']);
  });

  testWidgets('the card fills the screen width with no border or corners', (
    tester,
  ) async {
    await _pumpStudy(tester);

    expect(
      tester.getSize(find.byKey(const ValueKey('kanji-front'))).width,
      tester.getSize(find.byType(PageView)).width,
    );
    final face = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byKey(const ValueKey('kanji-front')),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final decoration = face.decoration as BoxDecoration;
    expect(decoration.border, isNull);
    expect(decoration.borderRadius, isNull);
    expect(
      decoration.color,
      Theme.of(tester.element(find.byType(PageView))).scaffoldBackgroundColor,
    );
  });

  testWidgets('the swipeable area reaches the bottom of the screen', (
    tester,
  ) async {
    await _pumpStudy(tester);

    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(tester.getBottomLeft(find.byType(PageView)).dy, screen.height);
    // The hide group sits in the lower part of the card, above the counter.
    final group = tester.getBottomLeft(
      find.byKey(const ValueKey('hide-group-front')),
    );
    expect(group.dy, greaterThan(screen.height * 0.75));
    expect(group.dy, lessThan(tester.getTopLeft(find.text('1 / 2')).dy));
  });

  testWidgets('the bottom system bar takes the screen background color', (
    tester,
  ) async {
    await _pumpStudy(tester, bottomInset: 40);

    // Flutter reads the navigation bar style from the screen's last pixel row.
    final layer = tester.binding.renderViews.first.debugLayer!;
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    final style = layer.find<SystemUiOverlayStyle>(
      Offset(size.width / 2, size.height - 1),
    );
    final screenColor = Theme.of(
      tester.element(find.byType(PageView)),
    ).scaffoldBackgroundColor;
    expect(style, isNotNull);
    expect(style!.systemNavigationBarColor, screenColor);
  });

  testWidgets('the hide group sits 5% of the screen above the indicator', (
    tester,
  ) async {
    await _pumpStudy(tester);

    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final gap =
        tester.getTopLeft(find.text('1 / 2')).dy -
        tester.getBottomLeft(find.byKey(const ValueKey('hide-group-front'))).dy;
    expect(gap, closeTo(screenHeight * 0.05, 6));
  });

  testWidgets('example sentences show furigana directly above their kanji', (
    tester,
  ) async {
    await _pumpStudy(tester);
    await _flip(tester);

    const pairs = {
      '一つ': ['ひと', '一'],
      '一部': ['いちぶ', '一部'],
    };
    for (final entry in pairs.entries) {
      final sentence = _inBack(find.byKey(ValueKey('sentence-${entry.key}')));
      await tester.ensureVisible(sentence);
      await tester.pumpAndSettle();
      final reading = find.descendant(
        of: sentence,
        matching: find.text(entry.value[0], findRichText: true),
      );
      final plain = find.descendant(
        of: sentence,
        matching: find.text(entry.value[1]),
      );
      expect(reading, findsOneWidget);
      expect(plain, findsOneWidget);
      expect(
        tester.getBottomLeft(reading).dy,
        lessThanOrEqualTo(tester.getTopLeft(plain).dy),
      );
    }
  });

  testWidgets('hide reading covers sentence furigana only', (tester) async {
    await _pumpStudy(tester);
    await _flip(tester);
    Finder ruby(String word, String text) => find.descendant(
      of: _inBack(find.byKey(ValueKey('sentence-$word'))),
      matching: find.text(text, findRichText: true),
    );
    expect(ruby('一つ', 'ひと'), findsOneWidget);
    expect(ruby('一部', 'いちぶ'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('hide-back-furigana')));
    await tester.pumpAndSettle();
    expect(ruby('一つ', 'ひと'), findsNothing);
    expect(ruby('一部', 'いちぶ'), findsNothing);
    // Readings and example word readings are not touched.
    expect(_inBack(find.text('ひと.つ')), findsOneWidget);
    expect(_inBack(find.text('ひとつ')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('hide-back-furigana')));
    await tester.pumpAndSettle();
    expect(ruby('一つ', 'ひと'), findsOneWidget);
  });

  testWidgets('hiding kun or on leaves sentence furigana shown', (
    tester,
  ) async {
    await _pumpStudy(tester);
    await _flip(tester);
    await tester.tap(find.byKey(const ValueKey('hide-back-kun')));
    await tester.tap(find.byKey(const ValueKey('hide-back-on')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: _inBack(find.byKey(const ValueKey('sentence-一つ'))),
        matching: find.text('ひと', findRichText: true),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a divider separates kun and on yomi only when both exist', (
    tester,
  ) async {
    await _pumpStudy(tester);
    await _flip(tester);
    expect(
      _inBack(find.byKey(const ValueKey('kun-on-divider'))),
      findsOneWidget,
    );

    await tester.tap(_inBack(find.byKey(const ValueKey('sentence-一つ'))).first);
    await tester.pumpAndSettle();
    await _swipeForward(tester);
    await _flip(tester);
    expect(_inBack(find.byKey(const ValueKey('kun-on-divider'))), findsNothing);
  });

  testWidgets('reading chips have no background color', (tester) async {
    await _pumpStudy(tester);
    await _flip(tester);

    for (final scope in [_inFront, _inBack]) {
      final chip = tester.widget<Material>(
        scope(find.byKey(const ValueKey('reading-いち'))),
      );
      expect(chip.color, Colors.transparent);
    }
  });

  testWidgets('the back scroll area reaches the hide group', (tester) async {
    await _pumpStudy(tester);
    await _flip(tester);

    final scroll = tester.getBottomLeft(
      _inBack(find.byType(SingleChildScrollView)),
    );
    final group = tester.getTopLeft(
      find.byKey(const ValueKey('hide-group-back')),
    );
    expect(scroll.dy, closeTo(group.dy, 0.5));
  });

  testWidgets('the kun and on divider is dashed', (tester) async {
    await _pumpStudy(tester);
    await _flip(tester);

    final divider = _inBack(find.byKey(const ValueKey('kun-on-divider')));
    expect(
      find.descendant(of: divider, matching: find.byType(CustomPaint)),
      findsWidgets,
    );
    expect(
      find.descendant(
        of: _inBack(find.byType(Column)),
        matching: find.byType(Divider),
      ),
      findsNothing,
    );
  });

  testWidgets('front readings are larger than back readings', (tester) async {
    await _pumpStudy(tester);
    final front = tester
        .widget<Text>(_inFront(find.text('いち')))
        .style!
        .fontSize!;

    await _flip(tester);
    final back = tester.widget<Text>(_inBack(find.text('いち'))).style!.fontSize!;

    expect(front, 32);
    expect(front, greaterThan(back));
  });

  testWidgets('front readings use the primary color', (tester) async {
    await _pumpStudy(tester);

    final primary = Theme.of(
      tester.element(find.byType(PageView)),
    ).colorScheme.primary;
    for (final reading in ['ひと-', 'いち', 'いつ']) {
      final text = tester.widget<Text>(_inFront(find.text(reading)));
      expect(text.style?.color, primary, reason: reading);
    }
  });

  testWidgets('the back scrolls from anywhere on the card', (tester) async {
    await _pumpStudy(tester);
    await _flip(tester);

    expect(
      tester.getSize(_inBack(find.byType(SingleChildScrollView))).width,
      tester.getSize(find.byKey(const ValueKey('kanji-back'))).width,
    );
    expect(
      tester.getTopLeft(_inBack(find.byType(SingleChildScrollView))),
      tester.getTopLeft(find.byKey(const ValueKey('kanji-back'))),
    );
  });

  testWidgets('the hide group has no background color', (tester) async {
    await _pumpStudy(tester);

    final group = tester.widget<Container>(
      find.byKey(const ValueKey('hide-group-front')),
    );
    expect(group.decoration, isNull);
    expect(group.color, isNull);
  });

  testWidgets('day selection lists kanji days and opens the kanji screen', (
    tester,
  ) async {
    await _pumpDaySelection(tester);

    expect(find.text('3 kanji'), findsOneWidget);
    expect(find.text('2 kanji per day · 2 days'), findsOneWidget);
    expect(find.text('Day 1'), findsOneWidget);
    expect(find.text('Day 2'), findsOneWidget);

    await tester.tap(find.text('Day 1'));
    await tester.pumpAndSettle();

    expect(find.text('Kanji study day 1'), findsOneWidget);
  });

  testWidgets('kanji days unlock from kanji progress, not vocabulary', (
    tester,
  ) async {
    await _pumpDaySelection(
      tester,
      controller: KanjiTestAppController(
        completed: const {
          'kanji-N5': {1},
        },
      ),
    );

    // No vocabulary day is completed, yet day 2 opens: the kanji course
    // reads its own 'kanji-N5' progress.
    await tester.tap(find.text('Day 2'));
    await tester.pumpAndSettle();
    expect(find.text('Kanji study day 2'), findsOneWidget);
  });
}

Finder _inFront(Finder finder) => find.descendant(
  of: find.byKey(const ValueKey('kanji-front')),
  matching: finder,
);

Finder _inBack(Finder finder) => find.descendant(
  of: find.byKey(const ValueKey('kanji-back')),
  matching: finder,
);

/// Flips the current card, then swipes to the next kanji.
Future<void> _swipeNext(WidgetTester tester) async {
  await _flip(tester);
  await _swipeForward(tester);
}

Future<void> _swipeForward(WidgetTester tester) async {
  await tester.drag(find.byType(PageView), const Offset(-500, 0));
  await tester.pumpAndSettle();
}

/// Reports the device volume as audible, so taps reach the speech service.
void _mockAudibleVolume(WidgetTester tester) {
  const volumeChannel = MethodChannel(
    'com.kurenai7968.volume_controller.method',
  );
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    volumeChannel,
    (call) async => call.method == 'isMuted' ? false : 0.8,
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      volumeChannel,
      null,
    ),
  );
}

/// Flips the card by tapping empty space on the front face, which works
/// whether or not the kanji itself is covered.
Future<void> _flip(WidgetTester tester) async {
  final face = tester.getRect(find.byKey(const ValueKey('kanji-front')));
  await tester.tapAt(face.topCenter + const Offset(0, 24));
  await tester.pumpAndSettle();
}

Future<RecordingTtsService> _pumpStudy(
  WidgetTester tester, {
  bool autoPlayAudio = false,
  KanjiTestAppController? controller,
  double bottomInset = 0,
}) async {
  _mockAudibleVolume(tester);
  final speech = RecordingTtsService();
  final container = ProviderContainer(
    overrides: [
      appControllerProvider.overrideWith(
        () =>
            controller ?? KanjiTestAppController(autoPlayAudio: autoPlayAudio),
      ),
      kanjiCatalogProvider.overrideWith((ref) async => kanjiTestCatalog),
      ttsServiceProvider.overrideWithValue(speech),
    ],
  );
  addTearDown(container.dispose);
  await container.read(appControllerProvider.future);
  final router = _router('/kanji/day/1');
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
        // Mirrors the app root, which keeps every screen inside a SafeArea.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            padding: EdgeInsets.only(bottom: bottomInset),
            viewPadding: EdgeInsets.only(bottom: bottomInset),
          ),
          child: SafeArea(child: child!),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return speech;
}

Future<void> _pumpDaySelection(
  WidgetTester tester, {
  KanjiTestAppController? controller,
}) async {
  final container = ProviderContainer(
    overrides: [
      appControllerProvider.overrideWith(
        () => controller ?? KanjiTestAppController(),
      ),
      kanjiCatalogProvider.overrideWith((ref) async => kanjiTestCatalog),
    ],
  );
  addTearDown(container.dispose);
  await container.read(appControllerProvider.future);
  final router = _router('/kanji');
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

/// Routes for the kanji course. With [daySelection] the real day list is
/// under test and the study route is a stub; otherwise the real study screen
/// is under test and the day list is a stub.
GoRouter _router(String initialLocation) {
  final daySelection = initialLocation == '/kanji';
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/home',
        builder: (_, _) => const Scaffold(body: Text('Home')),
      ),
      GoRoute(
        path: '/kanji',
        builder: (_, _) => daySelection
            ? const DaySelectionScreen(course: StudyCourse.kanji)
            : const Scaffold(body: Text('Kanji day list')),
      ),
      GoRoute(
        path: '/kanji/day/:day',
        builder: (_, state) => daySelection
            ? Scaffold(
                body: Text('Kanji study day ${state.pathParameters['day']}'),
              )
            : KanjiStudyScreen(
                day: int.parse(state.pathParameters['day'] ?? '1'),
              ),
      ),
      GoRoute(
        path: '/kanji/day/:day/finish',
        builder: (_, state) => daySelection
            ? const Scaffold()
            : KanjiFinishScreen(
                day: int.parse(state.pathParameters['day'] ?? '1'),
              ),
      ),
      GoRoute(
        path: '/settings/learning',
        builder: (_, _) => const Scaffold(body: Text('Settings route')),
      ),
    ],
  );
}
