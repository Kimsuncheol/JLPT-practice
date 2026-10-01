import 'package:flutter/material.dart';
import 'package:jlpt_practice/core/constants/app_sizes.dart';
import 'package:jlpt_practice/core/constants/app_font_weights.dart';

class WordChip extends StatelessWidget {
  const WordChip({required this.word, required this.onTap, super.key});

  final String word;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = Theme.of(context).colorScheme.outlineVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.radius999),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.size14,
          vertical: AppSizes.size8,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppSizes.radius999),
          border: Border.all(color: borderColor),
        ),
        child: Text(
          word,
          style: const TextStyle(
            fontSize: AppSizes.font14,
            fontWeight: AppFontWeights.medium,
          ),
        ),
      ),
    );
  }
}
