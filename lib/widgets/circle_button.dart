import 'package:flutter/material.dart';

class CircleButton extends StatefulWidget {
  final String letter;
  final bool isCenter;
  final VoidCallback onTap;
  final double width;
  /// Optional gradient to use for the circle background. If null the
  /// default light/dark gradients are used (or the center gradient when
  /// [isCenter] is true).
  final Gradient? gradient;

  const CircleButton({
    super.key,
    required this.letter,
    this.isCenter = false,
    required this.onTap,
    this.width = 80.0,
    this.gradient,
  });

  @override
  State<CircleButton> createState() => _CircleButtonState();
}

class _CircleButtonState extends State<CircleButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    // Colors
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // default gradients used when no override provided
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

    // choose gradient: override takes precedence
    final appliedGradient = widget.gradient ?? (widget.isCenter ? centerGradient : outerGradient);

    Widget content = AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      width: widget.width,
      height: widget.width,
      transform: Matrix4.translationValues(0, _isPressed ? 4.0 : 0.0, 0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: _isPressed ? [] : [
          BoxShadow(
            color: shadowColor,
            offset: const Offset(0, 6),
            blurRadius: 4,
          ),
        ],
        gradient: appliedGradient,
        border: Border.all(
          color: _isPressed ? shadowColor.withValues(alpha: 0.2) : highlightColor,
          width: 2.0,
        ),
      ),
      child: Center(
        child: Text(
          widget.letter.toUpperCase(),
          style: TextStyle(
            fontSize: widget.width * 0.4, // Slightly larger for circles
            height: 1.1,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
    );

    // if center, overlay a green star behind the letter
    if (widget.isCenter) {
      content = Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.star, color: Colors.green, size: widget.width),
          content,
        ],
      );
    }

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: content,
    );
  }
}
