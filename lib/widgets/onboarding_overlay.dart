import 'package:flutter/material.dart';
import 'dart:ui';

enum HighlightShape { rectangle, circle }

class OnboardingStep {
  final GlobalKey targetKey;
  final String title;
  final String description;
  final TextAlign textAlign;
  final HighlightShape shape;
  final Offset tweakOffset;
  final double padding;

  OnboardingStep({
    required this.targetKey,
    required this.title,
    required this.description,
    this.textAlign = TextAlign.center,
    this.shape = HighlightShape.rectangle,
    this.tweakOffset = Offset.zero,
    this.padding = 10,
  });
}

class OnboardingOverlay extends StatefulWidget {
  final List<OnboardingStep> steps;
  final VoidCallback onFinish;

  const OnboardingOverlay({
    super.key,
    required this.steps,
    required this.onFinish,
  });

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay> {
  int _currentStepIndex = 0;

  void _nextStep() {
    if (_currentStepIndex < widget.steps.length - 1) {
      setState(() {
        _currentStepIndex++;
      });
    } else {
      widget.onFinish();
    }
  }

  void _skip() {
    widget.onFinish();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.steps.isEmpty) return const SizedBox.shrink();

    final currentStep = widget.steps[_currentStepIndex];
    Rect? targetRect = _getWidgetRect(currentStep.targetKey);
    if (targetRect != null) {
      targetRect = targetRect.shift(currentStep.tweakOffset);
    }

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Dark background with hole
          GestureDetector(
            onTap: _nextStep,
            child: CustomPaint(
              size: MediaQuery.of(context).size,
              painter: HolePainter(
                targetRect: targetRect,
                shape: currentStep.shape,
                padding: currentStep.padding,
              ),
            ),
          ),
          // Instruction content
          if (targetRect != null)
            _buildInstructionBox(context, currentStep, targetRect),
          // Progress indicators and buttons
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Progress dots
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    widget.steps.length,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index == _currentStepIndex
                            ? Colors.white
                            : Colors.white.withOpacity(0.3),
                      ),
                    ),
                  ),
                ),
                // Navigation Buttons (Fixed Position)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: _nextStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: Text(
                        _currentStepIndex == widget.steps.length - 1
                            ? 'Dorr ko (Start)'
                            : 'Li ci tegg (Next)',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _skip,
                      icon: const Icon(
                        Icons.keyboard_double_arrow_right,
                        color: Colors.white,
                        size: 20,
                      ),
                      label: const Text(
                        'Féexal',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Rect? _getWidgetRect(GlobalKey key) {
    final RenderBox? renderBox =
        key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return null;
    final offset = renderBox.localToGlobal(Offset.zero);
    return offset & renderBox.size;
  }

  Widget _buildInstructionBox(
    BuildContext context,
    OnboardingStep step,
    Rect targetRect,
  ) {
    final screenSize = MediaQuery.of(context).size;

    // Determine position (above or below the target)
    double? top;
    double? bottom;

    if (targetRect.center.dy > screenSize.height / 2) {
      // Target is in bottom half, show box above
      bottom = screenSize.height - targetRect.top + 12;
    } else {
      // Target is in top half, show box below
      top = targetRect.bottom + 20;
    }

    return Positioned(
      top: top,
      bottom: bottom,
      left: 20,
      right: 20,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    step.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    step.description,
                    textAlign: step.textAlign,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HolePainter extends CustomPainter {
  final Rect? targetRect;
  final HighlightShape shape;
  final double padding;

  HolePainter({
    this.targetRect,
    this.shape = HighlightShape.rectangle,
    this.padding = 10,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.8);

    if (targetRect == null) {
      canvas.drawRect(Offset.zero & size, paint);
      return;
    }

    final path = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);

    if (shape == HighlightShape.circle) {
      final radius =
          (targetRect!.width > targetRect!.height
                  ? targetRect!.width
                  : targetRect!.height) /
              2 +
          padding;
      path.addOval(
        Rect.fromCircle(center: targetRect!.center, radius: radius),
      );
    } else {
      final RRect rRect = RRect.fromRectAndRadius(
        targetRect!.inflate(padding), // Padding around the target
        const Radius.circular(15),
      );
      path.addRRect(rRect);
    }

    canvas.drawPath(path, paint);

    // Draw a prominent glowing highlight around the hole
    final highlightGlowPaint = Paint()
      ..color = Colors.amber.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    final highlightBorderPaint = Paint()
      ..color = Colors.amber
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    if (shape == HighlightShape.circle) {
      final radius =
          (targetRect!.width > targetRect!.height
                  ? targetRect!.width
                  : targetRect!.height) /
              2 +
          padding;
      canvas.drawCircle(targetRect!.center, radius, highlightGlowPaint);
      canvas.drawCircle(targetRect!.center, radius, highlightBorderPaint);
    } else {
      final RRect rRect = RRect.fromRectAndRadius(
        targetRect!.inflate(padding), // Padding around the target
        const Radius.circular(15),
      );
      canvas.drawRRect(rRect, highlightGlowPaint);
      canvas.drawRRect(rRect, highlightBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant HolePainter oldDelegate) {
    return oldDelegate.targetRect != targetRect;
  }
}
