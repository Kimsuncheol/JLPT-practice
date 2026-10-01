import 'package:flutter/material.dart';
import 'package:jlpt_practice/core/constants/app_sizes.dart';

/// Action shown once the day's last word is reached, letting the user
/// restart today's study session from its first word. Styled like the
/// other card actions (icon + label, no background) so it fits the row.
class StartOverButton extends StatelessWidget {
  const StartOverButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(AppSizes.radius16),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    onTap: onPressed,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSizes.size10,
        horizontal: AppSizes.size12,
      ),
      child: Column(
        children: [
          const Icon(Icons.refresh_rounded),
          const SizedBox(height: AppSizes.space6),
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
