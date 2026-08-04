import 'dart:math';

import 'package:jlpt_practice/data/models/grammar_point.dart';
import 'package:jlpt_practice/data/models/mock_test_problem.dart';
import 'package:jlpt_practice/data/models/vocabulary.dart';
import 'package:jlpt_practice/data/repositories/mock_test_repository.dart';
import 'package:jlpt_practice/data/repositories/quiz_repository.dart';

const _kVocabularyCount = 12;
const _kGrammarCount = 12;

/// Builds vocabulary and grammar practice problems for [level] from the
/// app's own word and grammar-point catalogs, seeded by [seed] so that each
/// scheduled test date draws a different (but reproducible) selection.
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

  final vocabularyProblems = vocabularyQuestions.map((question) {
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
    );
  }).toList(growable: false);

  final grammarProblems = grammarQuestions.map((question) {
    final point = question.grammarPoint;
    return MockTestProblem(
      id: point.id,
      level: level,
      section: ProblemSection.grammar,
      passage: point.examples.isNotEmpty ? point.examples.first.japanese : '',
      question: point.title,
      choices: question.choices,
      correctAnswer: question.correctAnswer,
      explanationEn: point.explanation,
      explanationKo: point.explanationKo,
    );
  }).toList(growable: false);

  return GeneratedPracticeSet(
    items: [...vocabularyProblems, ...grammarProblems],
    vocabularyQuestions: vocabularyQuestions,
  );
}
