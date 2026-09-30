import 'package:flutter/material.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/features/vocabulary/sentence_reorder_quiz.dart';

class ReorderErrorView extends StatelessWidget {
  const ReorderErrorView({
    required this.error,
    required this.onRetry,
    super.key,
  });
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(error.toString()),
          TextButton(onPressed: onRetry, child: Text(context.strings('retry'))),
        ],
      ),
    ),
  );
}

class ReorderEmptyView extends StatelessWidget {
  const ReorderEmptyView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.strings('sentenceReordering'))),
    body: Center(child: Text(context.strings('noReorderSentences'))),
  );
}

class ReorderSummaryView extends StatelessWidget {
  const ReorderSummaryView({
    required this.summary,
    required this.onRetry,
    super.key,
  });
  final QuizSessionSummary summary;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.strings('sentenceReordering'))),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${summary.correct} / ${summary.total}',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: onRetry,
            child: Text(context.strings('retry')),
          ),
        ],
      ),
    ),
  );
}
