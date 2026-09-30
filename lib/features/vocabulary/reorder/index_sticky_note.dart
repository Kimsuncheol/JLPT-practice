import 'package:flutter/material.dart';

class IndexStickyNote extends StatelessWidget {
  const IndexStickyNote({
    required this.noteKey,
    required this.label,
    required this.labelColor,
    required this.labelTextColor,
    required this.surfaceColor,
    required this.borderColor,
    required this.child,
    this.tabOnRight = false,
    super.key,
  });

  final Key noteKey;
  final String label;
  final Color labelColor;
  final Color labelTextColor;
  final Color surfaceColor;
  final Color borderColor;
  final Widget child;
  final bool tabOnRight;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Container(
              key: noteKey,
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor, width: 1.5),
              ),
              clipBehavior: Clip.antiAlias,
              child: child,
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: tabOnRight ? null : 32,
          right: tabOnRight ? 32 : null,
          child: Container(
            constraints: const BoxConstraints(minWidth: 112),
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
            decoration: BoxDecoration(
              color: labelColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: labelTextColor,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
                height: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class IndexNoteLinesPainter extends CustomPainter {
  const IndexNoteLinesPainter({
    required this.color,
    required this.firstLineY,
    required this.spacing,
    this.drawBottomRule = false,
  });

  final Color color;
  final double firstLineY;
  final double spacing;
  final bool drawBottomRule;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;

    for (var y = firstLineY; y < size.height; y += spacing) {
      canvas.drawLine(Offset(24, y), Offset(size.width - 24, y), paint);
    }

    if (drawBottomRule) {
      canvas.drawLine(
        Offset(24, size.height - 0.5),
        Offset(size.width - 24, size.height - 0.5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant IndexNoteLinesPainter oldDelegate) {
    return color != oldDelegate.color ||
        firstLineY != oldDelegate.firstLineY ||
        spacing != oldDelegate.spacing ||
        drawBottomRule != oldDelegate.drawBottomRule;
  }
}
