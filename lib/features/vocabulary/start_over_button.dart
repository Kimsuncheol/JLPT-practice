import 'package:flutter/material.dart';

/// Action shown once the day's last word is reached, letting the user
/// restart today's study session from its first word. Styled like the
/// other card actions (icon + label, no background) so it fits the row.
class StartOverButton extends StatelessWidget {
  const StartOverButton({required this.label, required this.onPressed, super.key});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(16),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    onTap: onPressed,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Column(
        children: [
          const Icon(Icons.refresh_rounded),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    ),
  );
}
