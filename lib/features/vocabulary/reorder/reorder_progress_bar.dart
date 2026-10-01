import 'package:flutter/material.dart';
import 'package:jlpt_practice/core/constants/app_sizes.dart';
import 'package:jlpt_practice/core/constants/app_font_weights.dart';

class ReorderProgressBar extends StatelessWidget {
  const ReorderProgressBar({
    required this.index,
    required this.total,
    super.key,
  });
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSizes.size22,
      AppSizes.size6,
      AppSizes.size22,
      0,
    ),
    child: Row(
      children: [
        Expanded(
          child: LinearProgressIndicator(
            value: (index + 1) / total,
            minHeight: AppSizes.size8,
            borderRadius: BorderRadius.circular(AppSizes.radius8),
          ),
        ),
        const SizedBox(width: AppSizes.space14),
        Text(
          '${index + 1}/$total',
          style: const TextStyle(fontWeight: AppFontWeights.bold700),
        ),
      ],
    ),
  );
}
