import 'dart:math';

import 'package:flutter/material.dart';

import '../models/puzzle.dart';

/// A simple representation of the seven letters in the puzzle. The center letter
/// is visually distinguished. tapping an outer letter notifies the callback.
class LetterWheel extends StatelessWidget {
  final Puzzle puzzle;
  final void Function(String letter) onLetterTap;
  final VoidCallback? onShuffle;

  const LetterWheel({
    Key? key,
    required this.puzzle,
    required this.onLetterTap,
    this.onShuffle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final outer =
        puzzle.letters.where((l) => l != puzzle.centerLetter).toList();

    return LayoutBuilder(builder: (context, constraints) {
      // determine a square area to work inside
      final size = (constraints.maxWidth < constraints.maxHeight
              ? constraints.maxWidth
              : constraints.maxHeight) *
          0.8;
      final radius = size * 0.35;
      final center = Offset(size / 2, size / 2);
      const buttonSize = 48.0;

      return SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // outer letters positioned on a circle (hexagonally)
            for (var i = 0; i < outer.length; i++)
              Positioned(
                left: center.dx +
                    radius * cos(2 * pi * i / outer.length - pi / 2) -
                    buttonSize / 2,
                top: center.dy +
                    radius * sin(2 * pi * i / outer.length - pi / 2) -
                    buttonSize / 2,
                child: SizedBox(
                  width: buttonSize,
                  height: buttonSize,
                  child: ElevatedButton(
                    onPressed: () => onLetterTap(outer[i]),
                    child: Text(outer[i].toUpperCase()),
                  ),
                ),
              ),
            // center letter
            Positioned(
              left: center.dx - 36,
              top: center.dy - 36,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(24),
                  backgroundColor: Colors.amber,
                ),
                onPressed: () => onLetterTap(puzzle.centerLetter),
                child: Text(
                  puzzle.centerLetter.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            if (onShuffle != null)
              Positioned(
                right: 0,
                top: 0,
                child: IconButton(
                  icon: const Icon(Icons.shuffle),
                  onPressed: onShuffle,
                  tooltip: 'Shuffle letters',
                ),
              ),
          ],
        ),
      );
    });
  }
}
