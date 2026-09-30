import 'package:flutter/material.dart';

/// A horizontal line drawn as evenly spaced dashes.
class DashedDivider extends StatelessWidget {
  const DashedDivider({required this.color, super.key});

  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: const Size(double.infinity, 1),
    painter: DashedLinePainter(color),
  );
}

class DashedLinePainter extends CustomPainter {
  DashedLinePainter(this.color);

  final Color color;

  static const _dash = 6.0;
  static const _gap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += _dash + _gap) {
      canvas.drawLine(
        Offset(x, 0),
        Offset((x + _dash).clamp(0, size.width), 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(DashedLinePainter old) => old.color != color;
}
