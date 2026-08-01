enum LearningState {
  newWord,
  learning,
  review,
  relearning,
  mastered,
  suspended,
}

enum ReviewRating { again, hard, good, easy }

class ReviewProgress {
  const ReviewProgress({
    required this.vocabularyId,
    required this.jlptLevel,
    required this.state,
    required this.nextReviewAt,
    required this.intervalDays,
    required this.easeFactor,
    required this.repetitionCount,
    required this.lapseCount,
    required this.correctCount,
    required this.incorrectCount,
    required this.consecutiveCorrectCount,
    required this.lastRating,
    required this.updatedAt,
  });

  factory ReviewProgress.fromJson(Map<String, dynamic> json) {
    return ReviewProgress(
      vocabularyId: json['vocabularyId'] as String,
      jlptLevel: json['jlptLevel'] as String,
      state: LearningState.values.firstWhere(
        (value) => value.name == json['state'],
        orElse: () => LearningState.learning,
      ),
      nextReviewAt: DateTime.parse(json['nextReviewAt'] as String),
      intervalDays: (json['intervalDays'] as num).toDouble(),
      easeFactor: (json['easeFactor'] as num).toDouble(),
      repetitionCount: json['repetitionCount'] as int,
      lapseCount: json['lapseCount'] as int,
      correctCount: json['correctCount'] as int,
      incorrectCount: json['incorrectCount'] as int,
      consecutiveCorrectCount: json['consecutiveCorrectCount'] as int,
      lastRating: ReviewRating.values.firstWhere(
        (value) => value.name == json['lastRating'],
        orElse: () => ReviewRating.good,
      ),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  final String vocabularyId;
  final String jlptLevel;
  final LearningState state;
  final DateTime nextReviewAt;
  final double intervalDays;
  final double easeFactor;
  final int repetitionCount;
  final int lapseCount;
  final int correctCount;
  final int incorrectCount;
  final int consecutiveCorrectCount;
  final ReviewRating lastRating;
  final DateTime updatedAt;

  bool get isDue => !nextReviewAt.isAfter(DateTime.now());
  bool get isLearned =>
      state == LearningState.review || state == LearningState.mastered;

  Map<String, dynamic> toJson() => {
    'vocabularyId': vocabularyId,
    'jlptLevel': jlptLevel,
    'state': state.name,
    'nextReviewAt': nextReviewAt.toIso8601String(),
    'intervalDays': intervalDays,
    'easeFactor': easeFactor,
    'repetitionCount': repetitionCount,
    'lapseCount': lapseCount,
    'correctCount': correctCount,
    'incorrectCount': incorrectCount,
    'consecutiveCorrectCount': consecutiveCorrectCount,
    'lastRating': lastRating.name,
    'updatedAt': updatedAt.toIso8601String(),
  };
}
