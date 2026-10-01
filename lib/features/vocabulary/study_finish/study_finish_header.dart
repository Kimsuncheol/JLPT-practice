import 'package:flutter/material.dart';
import 'package:jlpt_practice/core/constants/app_sizes.dart';

class StudyFinishHeader extends StatelessWidget {
  const StudyFinishHeader({required this.title, required this.body, super.key});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: AppSizes.size92,
          height: AppSizes.size92,
          child: Icon(Icons.celebration_rounded, size: AppSizes.size42),
        ),
        const SizedBox(height: AppSizes.space22),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: AppSizes.space8),
        Text(
          body,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
