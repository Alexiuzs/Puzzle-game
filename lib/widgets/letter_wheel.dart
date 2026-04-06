import 'dart:math';
import 'dart:async';

import 'package:flutter/material.dart';
import 'top_callout.dart';
import '../models/puzzle.dart';
import 'circle_button.dart';

/// A circular arrangement of the seven puzzle letters.
/// When [triggerShuffle] is called externally, the outer circles swirl
/// one full rotation and the letters change at the halfway point.
class LetterWheel extends StatefulWidget {
  final Puzzle puzzle;
  final void Function(String letter) onLetterTap;
  final GlobalKey? centerKey;

  const LetterWheel({
    super.key,
    required this.puzzle,
    required this.onLetterTap,
    this.centerKey,
  });

  @override
  LetterWheelState createState() => LetterWheelState();
}

class LetterWheelState extends State<LetterWheel>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _pulseController;
  late final Animation<double> _rotation;
  late final Animation<double> _pulseScale;
  bool _swappedMidway = false;
  bool _showWarning = false;
  VoidCallback? _pendingCallback;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _rotation = Tween<double>(
      begin: 0,
      end: 2 * pi,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _pulseScale =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2), weight: 50),
          TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 50),
        ]).animate(
          CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
        );

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
    _pulseController.dispose();
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

  /// Pulses the center letter 5 times and shows the warning message
  void triggerPulse() {
    _pulseController
        .repeat(reverse: false)
        .timeout(
          const Duration(seconds: 1), // 200ms * 5 = 1s
          onTimeout: () => _pulseController.stop(),
        );
    setState(() {
      _showWarning = true;
    });
    Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _showWarning = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final outer = widget.puzzle.letters
        .where((l) => l != widget.puzzle.centerLetter)
        .toList();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = min(constraints.maxWidth, constraints.maxHeight) * 0.9;
          final circleSize = min(size / 3.2, 110.0);
          final orbitRadius = circleSize * 1.15;
          final center = Offset(size / 2, size / 2);

          return AnimatedBuilder(
            animation: Listenable.merge([_rotation, _pulseScale]),
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

                    // Center circle — stays put, but can pulse
                    Positioned(
                      left: center.dx - circleSize / 2,
                      top: center.dy - circleSize / 2,
                      child: ScaleTransition(
                        scale: _pulseScale,
                        child: CircleButton(
                          key: widget.centerKey ?? const ValueKey('center'),
                          letter: widget.puzzle.centerLetter,
                          isCenter: true,
                          width: circleSize,
                          onTap: () =>
                              widget.onLetterTap(widget.puzzle.centerLetter),
                        ),
                      ),
                    ),
                    if (_showWarning)
                      () {
                        // Position top-left (around 240 degrees)
                        const angle = 240 * (pi / 180);
                        const radius =
                            1.35; // Further out than the outer circles
                        final dx =
                            center.dx + orbitRadius * radius * cos(angle);
                        final dy =
                            center.dy + orbitRadius * radius * sin(angle);

                        return Positioned(
                          left: (size - 200) / 2,
                          bottom: (size - 100) / 3,
                          child: TopCallout(
                            color: Theme.of(
                              context,
                            ).colorScheme.tertiaryContainer,
                            textColor: Theme.of(
                              context,
                            ).colorScheme.onTertiaryContainer,
                            child: Text(
                              textAlign: TextAlign.center,
                              "baat bu nekk war na am araf bii",
                            ),
                          ),
                          // child: SizedBox(
                          //   width: 200,
                          //   height: 100,
                          //   child: Card(
                          //     margin: .all(16),
                          //     child: Center(
                          //       child: Padding(
                          //         padding: const EdgeInsets.all(16.0),
                          //         child: Text(
                          //           textAlign: TextAlign.center,
                          //           "baat bu nekk war na am araf bii",
                          //         ),
                          //       ),
                          //     ),
                          //   ),
                          // ),
                          // Column(
                          //   mainAxisSize: MainAxisSize.min,
                          //   children: [
                          //     SizedBox(
                          //       width: 220,
                          //       child: Text(
                          //         "baat bu nekk war na am araf bii",
                          //         textAlign: TextAlign.center,
                          //         style: TextStyle(
                          //           color: Colors.red,
                          //           fontWeight: FontWeight.bold,
                          //           fontSize: 22, // Bigger
                          //           height: 1.1,
                          //           shadows: [
                          //             Shadow(
                          //               color: Colors.black.withValues(alpha: 0.5),
                          //               blurRadius: 4,
                          //               offset: const Offset(1, 1),
                          //             ),
                          //           ],
                          //         ),
                          //       ),
                          //     ),
                          //     const SizedBox(height: 10),
                          //     Transform.rotate(
                          //       angle: angle + pi / 2, // Rotate to point center
                          //       child: const Icon(
                          //         Icons.arrow_downward,
                          //         color: Colors.red,
                          //         size: 60, // Much bigger
                          //       ),
                          //     ),
                          //   ],
                          // ),
                        );
                      }(),
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
