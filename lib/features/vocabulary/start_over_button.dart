import 'package:flutter/material.dart';

/// Circular AppBar action that lets the user restart today's study session
/// from its first word. Colors are theme-driven so it adapts automatically
/// to light/dark mode.
class StartOverButton extends StatelessWidget {
  const StartOverButton({required this.onPressed, super.key});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onPressed,
      icon: const Icon(Icons.refresh_rounded),
      style: IconButton.styleFrom(
        shape: const CircleBorder(),
        backgroundColor: colorScheme.surfaceContainerHighest,
        foregroundColor: colorScheme.onSurfaceVariant,
      ),
    );
  }
}
