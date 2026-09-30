import 'package:flutter/material.dart';

/// The plain surface a kanji card face is drawn on: edge to edge, in the
/// screen's own background color, with no border or corners.
class KanjiFace extends StatelessWidget {
  const KanjiFace({required this.child, required this.padding, super.key});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor),
    child: SizedBox.expand(
      child: Padding(padding: padding, child: child),
    ),
  );
}
