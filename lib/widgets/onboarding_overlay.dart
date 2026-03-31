import 'package:flutter/material.dart';
import 'dart:ui';

class OnboardingStep {
  final GlobalKey targetKey;
  final String title;
  final String description;
  final TextAlign textAlign;

  OnboardingStep({
    required this.targetKey,
    required this.title,
    required this.description,
    this.textAlign = TextAlign.center,
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
    final Rect? targetRect = _getWidgetRect(currentStep.targetKey);

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Dark background with hole
          GestureDetector(
            onTap: _nextStep,
            child: CustomPaint(
              size: MediaQuery.of(context).size,
              painter: HolePainter(targetRect: targetRect),
            ),
          ),
          // Instruction content
          if (targetRect != null)
            _buildInstructionBox(context, currentStep, targetRect),
          // Skip button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 20,
            child: TextButton(
              onPressed: _skip,
              child: const Text(
                'Féexal (Skip)',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          // Progress indicators
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
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
      BuildContext context, OnboardingStep step, Rect targetRect) {
    final screenSize = MediaQuery.of(context).size;
    
    // Determine position (above or below the target)
    double? top;
    double? bottom;
    
    if (targetRect.center.dy > screenSize.height / 2) {
      // Target is in bottom half, show box above
      bottom = screenSize.height - targetRect.top + 12;
    } else {
      // Target is in top half, show box below
      top = targetRect.bottom + 12;
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
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _nextStep,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
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

  HolePainter({this.targetRect});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.8);
    
    if (targetRect == null) {
      canvas.drawRect(Offset.zero & size, paint);
      return;
    }

    // Path for the background with a hole
    final backgroundPath = Path()..addRect(Offset.zero & size);
    
    // Create a rounded rect for the hole to make it look nicer
    final RRect rRect = RRect.fromRectAndRadius(
      targetRect!.inflate(10), // Padding around the target
      const Radius.circular(15),
    );
    final holePath = Path()..addRRect(rRect);

    // XOR the paths to create the hole
    final combinedPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      holePath,
    );

    canvas.drawPath(combinedPath, paint);

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

    canvas.drawRRect(rRect, highlightGlowPaint);
    canvas.drawRRect(rRect, highlightBorderPaint);
  }

  @override
  bool shouldRepaint(covariant HolePainter oldDelegate) {
    return oldDelegate.targetRect != targetRect;
  }
}
