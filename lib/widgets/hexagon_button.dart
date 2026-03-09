import 'package:flutter/material.dart';

class HexagonButton extends StatefulWidget {
  final String letter;
  final bool isCenter;
  final VoidCallback onTap;
  final double width;

  const HexagonButton({
    super.key,
    required this.letter,
    this.isCenter = false,
    required this.onTap,
    this.width = 80.0,
  });

  @override
  State<HexagonButton> createState() => _HexagonButtonState();
}

class _HexagonButtonState extends State<HexagonButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    // Colors
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final centerGradient = isDark 
      ? const LinearGradient(colors: [Color(0xFFFFD54F), Color(0xFFFFB300)], begin: Alignment.topLeft, end: Alignment.bottomRight)
      : const LinearGradient(colors: [Color(0xFFFFE082), Color(0xFFFFCA28)], begin: Alignment.topLeft, end: Alignment.bottomRight);
      
    final outerGradient = isDark
      ? const LinearGradient(colors: [Color(0xFF424242), Color(0xFF303030)], begin: Alignment.topLeft, end: Alignment.bottomRight)
      : const LinearGradient(colors: [Color(0xFFF5F5F5), Color(0xFFE0E0E0)], begin: Alignment.topLeft, end: Alignment.bottomRight);

    final textColor = widget.isCenter 
        ? Colors.black87 
        : (isDark ? Colors.white : Colors.black87);

    final highlightColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white;
    final shadowColor = isDark ? Colors.black54 : Colors.grey.withValues(alpha: 0.5);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: widget.width,
        height: widget.width * 0.866, // Keep proper aspect ratio: height = width * (sqrt(3)/2)
        transform: Matrix4.translationValues(0, _isPressed ? 4.0 : 0.0, 0),
        child: CustomPaint(
          painter: HexagonPainter(
            gradient: widget.isCenter ? centerGradient : outerGradient,
            isPressed: _isPressed,
            shadowColor: shadowColor,
            highlightColor: highlightColor,
          ),
          child: Center(
            child: Text(
              widget.letter.toUpperCase(),
              style: TextStyle(
                fontSize: widget.width * 0.3, // dynamic scaling font size
                height: 1.1,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HexagonPainter extends CustomPainter {
  final Gradient gradient;
  final bool isPressed;
  final Color shadowColor;
  final Color highlightColor;

  HexagonPainter({
    required this.gradient,
    required this.isPressed,
    required this.shadowColor,
    required this.highlightColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final path = _getHexagonPath(size);

    // Draw Drop Shadow
    if (!isPressed) {
      canvas.drawPath(
        path.shift(const Offset(0, 6)),
        Paint()
          ..color = shadowColor
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    // Draw Main Hexagon Body
    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);

    // Inner Highlight / Bevel (Neumorphic effect)
    final strokePaint = Paint()
      ..color = isPressed ? shadowColor.withValues(alpha: 0.2) : highlightColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawPath(path, strokePaint);
  }

  Path _getHexagonPath(Size size) {
    final w = size.width;
    final h = size.height;
    
    // Flat-topped hexagon
    return Path()
      ..moveTo(w * 0.25, 0)
      ..lineTo(w * 0.75, 0)
      ..lineTo(w, h * 0.5)
      ..lineTo(w * 0.75, h)
      ..lineTo(w * 0.25, h)
      ..lineTo(0, h * 0.5)
      ..close();
  }

  @override
  bool shouldRepaint(covariant HexagonPainter oldDelegate) {
    return oldDelegate.gradient != gradient ||
           oldDelegate.isPressed != isPressed ||
           oldDelegate.shadowColor != shadowColor ||
           oldDelegate.highlightColor != highlightColor;
  }
}
