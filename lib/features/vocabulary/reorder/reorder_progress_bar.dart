import 'package:flutter/material.dart';

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
    padding: const EdgeInsets.fromLTRB(22, 6, 22, 0),
    child: Row(
      children: [
        Expanded(
          child: LinearProgressIndicator(
            value: (index + 1) / total,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(width: 14),
        Text(
          '${index + 1}/$total',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}
