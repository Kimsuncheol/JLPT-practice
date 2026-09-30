import 'package:flutter/material.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';
import 'package:jlpt_practice/features/vocabulary/start_over_button.dart';

/// What sits above the hide group: a hint until the back has been seen, then,
/// on the last card, the start-over and finish actions.
class KanjiFooter extends StatelessWidget {
  const KanjiFooter({
    required this.seenBack,
    required this.isLast,
    required this.onStartOver,
    required this.onFinish,
    super.key,
  });

  static const height = 72.0;

  final bool seenBack;
  final bool isLast;
  final VoidCallback onStartOver;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return SizedBox(
      height: height,
      child: !seenBack
          ? Center(
              child: Text(
                strings('flipToContinue'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : isLast
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                StartOverButton(
                  label: strings('startOver'),
                  onPressed: onStartOver,
                ),
                const SizedBox(width: 24),
                FilledButton.icon(
                  onPressed: onFinish,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(strings('finish')),
                ),
              ],
            )
          : null,
    );
  }
}
