import 'dart:math';

import 'package:jlpt_practice/data/models/grammar_point.dart';
import 'package:jlpt_practice/data/models/jlpt_exam_blueprint.dart';
import 'package:jlpt_practice/data/models/mock_test_problem.dart';
import 'package:jlpt_practice/data/models/vocabulary.dart';
import 'package:jlpt_practice/data/repositories/mock_test_repository.dart';
import 'package:jlpt_practice/data/repositories/quiz_repository.dart';

const _kVocabularyCount = 12;
const _kGrammarCount = 12;

int stablePracticeSeed(String value) {
  var hash = 0x811c9dc5;
  for (final unit in value.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}

/// Builds vocabulary and grammar practice problems for [level] from the
/// app's own word and grammar-point catalogs, seeded by [seed] so that each
/// practice part draws a different (but reproducible) selection.
GeneratedPracticeSet buildGeneratedPracticeSet({
  required List<Vocabulary> vocabulary,
  required List<GrammarPoint> grammarPoints,
  required String level,
  required String meaningLanguage,
  required int seed,
}) {
  final random = Random(seed);
  final mockTestRepository = MockTestRepository(
    quizRepository: QuizRepository(random: random),
    random: random,
  );

  final vocabularyQuestions = mockTestRepository.buildVocabularySection(
    vocabulary,
    level: level,
    count: _kVocabularyCount,
  );
  final grammarQuestions = mockTestRepository.buildGrammarSection(
    grammarPoints,
    level: level,
    language: meaningLanguage,
    count: _kGrammarCount,
  );

  final vocabularyProblems = vocabularyQuestions
      .map((question) {
        final index = vocabularyQuestions.indexOf(question);
        final blueprint = blueprintParts(level, ProblemSection.vocabulary);
        final examPart = blueprint[index % blueprint.length];
        final vocab = question.vocabulary;
        return MockTestProblem(
          id: vocab.id,
          level: level,
          section: ProblemSection.vocabulary,
          passage: '',
          question: vocab.example.quizSentence,
          choices: question.choices,
          correctAnswer: question.correctAnswer,
          explanationEn: '${vocab.reading} · ${vocab.meaning('en')}',
          explanationKo: '${vocab.reading} · ${vocab.meaning('ko')}',
          part: examPart.number,
          rank: (index ~/ blueprint.length) + 1,
          itemType: examPart.itemType,
          source: 'ranked_catalog_generator',
        );
      })
      .toList(growable: false);

  final grammarProblems = grammarQuestions
      .map((question) {
        final index = grammarQuestions.indexOf(question);
        final blueprint = blueprintParts(level, ProblemSection.grammar);
        final examPart = blueprint[index % blueprint.length];
        final point = question.grammarPoint;
        return MockTestProblem(
          id: point.id,
          level: level,
          section: ProblemSection.grammar,
          passage: point.examples.isNotEmpty
              ? point.examples.first.japanese
              : '',
          question: point.title,
          choices: question.choices,
          correctAnswer: question.correctAnswer,
          explanationEn: point.explanation,
          explanationKo: point.explanationKo,
          part: examPart.number,
          rank: (index ~/ blueprint.length) + 1,
          itemType: examPart.itemType,
          source: 'ranked_catalog_generator',
        );
      })
      .toList(growable: false);

  return GeneratedPracticeSet(
    items: [...vocabularyProblems, ...grammarProblems],
    vocabularyQuestions: vocabularyQuestions,
  );
}

String practiceSetId(int number) => 'practice-$number';

int practiceSetNumber(String practiceId) {
  final match = RegExp(r'^practice-(\d+)$').firstMatch(practiceId);
  return int.tryParse(match?.group(1) ?? '') ?? 1;
}

/// Selects one variant for every official reading/listening item type from the
/// combined historical pool. Mixed-radix indexing gives Practices 1–10
/// different combinations even when an individual item type has only two
/// available variants.
List<MockTestProblem> selectRankedStaticProblems(
  List<MockTestProblem> bank, {
  required String level,
  required int practiceNumber,
}) {
  final selected = <MockTestProblem>[];
  for (final section in [ProblemSection.reading, ProblemSection.listening]) {
    var combinationIndex = practiceNumber - 1;
    for (final examPart in blueprintParts(level, section)) {
      final candidates =
          bank
              .where(
                (item) =>
                    item.level == level &&
                    item.section == section &&
                    item.part == examPart.number &&
                    item.itemType == examPart.itemType,
              )
              .toList(growable: false)
            ..sort((a, b) => a.rank.compareTo(b.rank));
      if (candidates.isEmpty) continue;
      selected.add(candidates[combinationIndex % candidates.length]);
      combinationIndex ~/= candidates.length;
    }
  }
  return selected;
}
