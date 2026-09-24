import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:jlpt_practice/core/services/tts_service.dart';
import 'package:jlpt_practice/data/models/vocabulary.dart';
import 'package:jlpt_practice/features/vocabulary/sentence_reorder_quiz.dart';

Vocabulary entry(List<String>? tokens, {String level = 'N5'}) => Vocabulary(
  id: '$level-${tokens?.join()}',
  word: '猫',
  reading: 'ねこ',
  furigana: '猫',
  romaji: '',
  meanings: const {
    'ko': ['고양이'],
  },
  partOfSpeech: 'noun',
  jlptLevel: level,
  tags: const [],
  example: VocabularyExample(
    sentence: '${tokens?.join() ?? ''}。',
    reading: '',
    translations: const {'ko': '고양이'},
    quizSentence: '',
    answer: '',
    tokens: tokens,
  ),
);

void main() {
  test('answer comparison preserves positions and duplicate tokens', () {
    expect(isAnswerCorrect(['猫も', '犬も', '猫も'], ['猫も', '犬も', '猫も']), isTrue);
    expect(isAnswerCorrect(['猫も', '猫も', '犬も'], ['猫も', '犬も', '猫も']), isFalse);
    expect(isAnswerCorrect(['猫も'], ['猫も', '犬も']), isFalse);
  });

  test('shuffle changes order, including with duplicate tokens', () {
    final original = ['猫も', '犬も', '猫も'];
    for (var seed = 0; seed < 100; seed++) {
      final shuffled = shuffleTokens(original, random: Random(seed));
      expect(shuffled, isNot(original));
      expect([...shuffled]..sort(), [...original]..sort());
    }
  });

  test('eligibility uses inclusive 3 to 8 token bounds', () {
    expect(isReorderEligible(entry(['私', 'は'])), isFalse);
    expect(isReorderEligible(entry(['私', 'は', '行く'])), isTrue);
    expect(isReorderEligible(entry(List.generate(8, (i) => '語$i'))), isTrue);
    expect(isReorderEligible(entry(List.generate(9, (i) => '語$i'))), isFalse);
    expect(isReorderEligible(entry(null)), isFalse);
  });

  test('quiz set reports shortage and level with no eligible entries', () {
    final words = [
      entry(['私', 'は', '行く']),
    ];
    final set = buildQuizSet(words, count: 10, level: 'N5');
    expect(set.requestedCount, 10);
    expect(set.actualCount, 1);
    expect(set.hasNoEligibleEntries, isFalse);
    expect(buildQuizSet(words, level: 'N1').hasNoEligibleEntries, isTrue);
    expect(buildQuizSet([...words, ...words]).actualCount, 1);
  });

  test('submission marks wrong positions', () {
    final quiz = buildQuizFromEntry(entry(['私', 'は', '行く']));
    final result = submitAnswer(quiz, ['私', '行く', 'は']);
    expect(result.isCorrect, isFalse);
    expect(result.wrongPositions, [1, 2]);
  });

  test('audio failure does not interrupt a quiz', () async {
    final quiz = buildQuizFromEntry(entry(['私', 'は', '行く']));
    await expectLater(playQuizSentenceAudio(quiz, _FailingTts()), completes);
  });

  test('enrichment retains matching catalog tiles', () {
    final catalog = entry(['私', 'は', '行く']);
    final detail = Vocabulary(
      id: 'detail',
      word: catalog.word,
      reading: catalog.reading,
      furigana: catalog.furigana,
      romaji: '',
      meanings: catalog.meanings,
      partOfSpeech: 'noun',
      jlptLevel: 'N5',
      tags: const [],
      example: const VocabularyExample(
        sentence: '私は行く。',
        reading: '',
        translations: {},
        quizSentence: '',
        answer: '',
      ),
    );
    expect(catalog.enrichedWith(detail).example.tokens, ['私', 'は', '行く']);
  });
}

class _FailingTts implements TtsService {
  @override
  Future<void> speak(String text) async => throw StateError('no audio');
  @override
  Future<void> speakDialogue(List<DialogueTurn> turns) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}
