import 'package:flutter/material.dart';
import 'package:jlpt_practice/core/constants/app_sizes.dart';

/// Full-width action on a finish screen that restarts the current study day.
class StartOverButton extends StatelessWidget {
  const StartOverButton({
    required this.label,
    required this.onPressed,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(AppSizes.size54),
      ),
      onPressed: onPressed,
      icon: const Icon(Icons.refresh_rounded),
      label: Text(label),
    ),
  );
}
