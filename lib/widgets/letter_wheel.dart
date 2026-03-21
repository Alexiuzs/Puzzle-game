import 'dart:math';

import 'package:flutter/material.dart';

import '../models/puzzle.dart';
import 'circle_button.dart';

/// A circular arrangement of the seven puzzle letters.
/// When [triggerShuffle] is called externally, the outer circles swirl
/// one full rotation and the letters change at the halfway point.
class LetterWheel extends StatefulWidget {
  final Puzzle puzzle;
  final void Function(String letter) onLetterTap;

  const LetterWheel({
    super.key,
    required this.puzzle,
    required this.onLetterTap,
  });

  @override
  LetterWheelState createState() => LetterWheelState();
}

class LetterWheelState extends State<LetterWheel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _rotation;
  bool _swappedMidway = false;
  VoidCallback? _pendingCallback;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _rotation = Tween<double>(
      begin: 0,
      end: 2 * pi,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    // Swap letters at the midpoint of the animation
    _controller.addListener(() {
      if (!_swappedMidway && _controller.value >= 0.5) {
        _swappedMidway = true;
        _pendingCallback?.call();
        _pendingCallback = null;
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Call this to trigger the swirl animation; [onSwap] fires mid-spin so
  /// the new letters appear while the circles are still moving.
  Future<void> triggerShuffle(VoidCallback onSwap) async {
    if (_controller.isAnimating) return;
    _swappedMidway = false;
    _pendingCallback = onSwap;
    await _controller.forward(from: 0);
    _swappedMidway = false;
  }

  @override
  Widget build(BuildContext context) {
    final outer = widget.puzzle.letters
        .where((l) => l != widget.puzzle.centerLetter)
        .toList();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = min(constraints.maxWidth, constraints.maxHeight) * 0.9;
          final circleSize = min(size / 3.2, 110.0);
          final orbitRadius = circleSize * 1.15;
          final center = Offset(size / 2, size / 2);

          return AnimatedBuilder(
            animation: _rotation,
            builder: (context, _) {
              return SizedBox(
                width: size,
                height: size,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    // Outer circles — swirl around the center
                    for (var i = 0; i < outer.length; i++)
                      () {
                        final baseAngle = (i * 60 - 90) * (pi / 180);
                        final angle = baseAngle + _rotation.value;
                        final dx = center.dx + orbitRadius * cos(angle);
                        final dy = center.dy + orbitRadius * sin(angle);
                        // Standard background for outer circles: green
                        const color = Colors.green;
                        final gradient = LinearGradient(
                          colors: [color.withValues(alpha: 0.9), color],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        );
                        return Positioned(
                          left: dx - circleSize / 2,
                          top: dy - circleSize / 2,
                          child: CircleButton(
                            key: ValueKey('outer_$i'),
                            letter: outer[i],
                            width: circleSize,
                            gradient: gradient,
                            onTap: () => widget.onLetterTap(outer[i]),
                          ),
                        );
                      }(),

                    // Center circle — stays put
                    Positioned(
                      left: center.dx - circleSize / 2,
                      top: center.dy - circleSize / 2,
                      child: CircleButton(
                        key: const ValueKey('center'),
                        letter: widget.puzzle.centerLetter,
                        isCenter: true,
                        width: circleSize,
                        onTap: () =>
                            widget.onLetterTap(widget.puzzle.centerLetter),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
