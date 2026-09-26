import 'package:flutter/material.dart';
import 'package:jlpt_practice/core/localization/app_strings.dart';

class ReorderActions extends StatelessWidget {
  const ReorderActions({
    required this.answered,
    required this.canReset,
    required this.canCheck,
    required this.onReset,
    required this.onCheck,
    required this.onContinue,
    super.key,
  });
  final bool answered;
  final bool canReset;
  final bool canCheck;
  final VoidCallback onReset;
  final VoidCallback onCheck;
  final VoidCallback onContinue;

  static final _shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  );
  static const _minimumSize = Size.fromHeight(54);

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final filled = FilledButton.styleFrom(
      minimumSize: _minimumSize,
      shape: _shape,
    );
    if (answered) {
      return FilledButton(
        style: filled,
        onPressed: onContinue,
        child: Text(strings('continue')),
      );
    }
    return Column(
      children: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            minimumSize: _minimumSize,
            shape: _shape,
          ),
          onPressed: canReset ? onReset : null,
          child: Text(strings('reset')),
        ),
        const SizedBox(height: 12),
        FilledButton(
          style: filled,
          onPressed: canCheck ? onCheck : null,
          child: Text(strings('checkAnswer')),
        ),
      ],
    );
  }
}
