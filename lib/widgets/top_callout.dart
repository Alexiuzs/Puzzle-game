import 'package:flutter/material.dart';

class TopCallout extends StatelessWidget {
  final Widget child;
  final Color color;
  final Color textColor;

  const TopCallout({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.textColor = Colors.black87,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      height: 100,
      child: CustomPaint(
        painter: _CalloutPainter(color),
        child: Padding(
          // Leave space for the arrow at the top
          padding: const EdgeInsets.only(top: 10.0),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _CalloutPainter extends CustomPainter {
  final Color color;

  _CalloutPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const double arrowHeight = 10;
    const double arrowWidth = 20;

    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final Path path = Path();

    // Arrow tip centered at top
    final double centerX = size.width / 2;

    path.moveTo(centerX, 0); // arrow tip
    path.lineTo(centerX - arrowWidth / 2, arrowHeight);
    path.lineTo(0, arrowHeight);
    path.lineTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, arrowHeight);
    path.lineTo(centerX + arrowWidth / 2, arrowHeight);
    path.close();

    // Draw shape
    canvas.drawShadow(path, Colors.black.withAlpha(90), 4, true);
    canvas.drawPath(path, paint);

    // Optional: border
    final borderPaint = Paint()
      ..color = Colors.black12
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _CalloutPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
