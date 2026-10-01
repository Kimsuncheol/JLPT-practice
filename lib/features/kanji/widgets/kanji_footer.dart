import 'package:flutter/material.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';

/// What sits above the hide group: a hint until the back has been seen.
class KanjiFooter extends StatelessWidget {
  const KanjiFooter({required this.seenBack, super.key});

  static const height = 72.0;

  final bool seenBack;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: seenBack
        ? null
        : Center(
            child: Text(
              context.strings('flipToContinue'),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
  );
}
