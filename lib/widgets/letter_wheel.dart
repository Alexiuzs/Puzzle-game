import 'dart:math';

import 'package:flutter/material.dart';

import '../models/puzzle.dart';
import 'hexagon_button.dart';

/// A stylish hexagon honeycomb representation of the seven letters in the puzzle.
/// The center letter is visually distinguished. Tapping a letter notifies the callback.
class LetterWheel extends StatelessWidget {
  final Puzzle puzzle;
  final void Function(String letter) onLetterTap;
  final VoidCallback? onShuffle;

  const LetterWheel({
    super.key,
    required this.puzzle,
    required this.onLetterTap,
    this.onShuffle,
  });

  @override
  Widget build(BuildContext context) {
    final outer = puzzle.letters
        .where((l) => l != puzzle.centerLetter)
        .toList();

    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Adjust overall size to fit the container comfortably
          final size = min(constraints.maxWidth, constraints.maxHeight) * 0.9;
          final center = Offset(size / 2, size / 2);

          const gapMult = 1.05;
          // Calculate max hexagon width to fit exactly in container
          // Width spans ~2.5 full hexagon widths when staggered
          final maxHexWidth = size / (2.5 * gapMult);
          // Scale dynamically but don't grow beyond a massive desktop size
          final hexOriginWidth = min(maxHexWidth, 160.0);

          // Calculate the height of the flat-topped hexagon: W * sqrt(3)/2
          final hexOriginHeight = hexOriginWidth * 0.866;

          // For a flat-topped hexagon, the distance from the center to its neighbor
          // to perfectly stack them horizontally is X offset = W * 0.75
          // Vertically, it is Y offset = H
          // Let's position the 6 outer hexagons around the center.
          // The angles for tight adjacent flat-topped hexagons are at 30, 90, 150, 210, 270, 330 degrees
          // BUT actually, a much simpler approach for identical hex spacing is:
          // X off = w * 0.75 * cos(theta), Y off = w * 0.75 * sin(theta) wait...
          // The true distance from center-to-center for flat topped is:
          // Top-Right: (w * 0.75, -h/2)
          // Top-Left: (-w * 0.75, -h/2)
          // Right: (0, -h) -- wait, for flat topped:
          // Center is (0,0). Neighbors are:
          // 1: (0, -h) (Top)
          // 2: (w*0.75, -h/2) (Top Right)
          // 3: (w*0.75, h/2) (Bottom Right)
          // 4: (0, h) (Bottom)
          // 5: (-w*0.75, h/2) (Bottom Left)
          // 6: (-w*0.75, -h/2) (Top Left)

          // We will scale up just slightly to give them a tiny gap

          final offsets = [
            Offset(0, -hexOriginHeight * gapMult), // Top
            Offset(
              hexOriginWidth * 0.75 * gapMult,
              -hexOriginHeight / 2 * gapMult,
            ), // Top Right
            Offset(
              hexOriginWidth * 0.75 * gapMult,
              hexOriginHeight / 2 * gapMult,
            ), // Bottom Right
            Offset(0, hexOriginHeight * gapMult), // Bottom
            Offset(
              -hexOriginWidth * 0.75 * gapMult,
              hexOriginHeight / 2 * gapMult,
            ), // Bottom Left
            Offset(
              -hexOriginWidth * 0.75 * gapMult,
              -hexOriginHeight / 2 * gapMult,
            ), // Top Left
          ];

          final double shuffleButtonGap = size > 470 ? 16 : 0;

          return Center(
            child: Container(
              padding: EdgeInsets.symmetric(vertical: 10),
              width: size,
              // this gives it a bit of extra height when size gets small
              height: size > 470 ? size : size + 20,

              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Outer letters
                  for (var i = 0; i < outer.length; i++)
                    Positioned(
                      left: center.dx + offsets[i].dx - hexOriginWidth / 2,
                      top: center.dy + offsets[i].dy - hexOriginHeight / 2,
                      child: HexagonButton(
                        letter: outer[i],
                        width: hexOriginWidth,
                        onTap: () => onLetterTap(outer[i]),
                      ),
                    ),

                  // Center letter
                  Positioned(
                    left: center.dx - hexOriginWidth / 2,
                    top: center.dy - hexOriginHeight / 2,
                    child: HexagonButton(
                      letter: puzzle.centerLetter,
                      isCenter: true,
                      width: hexOriginWidth,
                      onTap: () => onLetterTap(puzzle.centerLetter),
                    ),
                  ),

                  // Shuffle button
                  if (onShuffle != null)
                    Positioned(
                      right: shuffleButtonGap,
                      bottom: shuffleButtonGap,
                      child: Tooltip(
                        message: 'Shuffle letters',
                        child: ElevatedButton(
                          onPressed: onShuffle,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          // This gives you a small button with just the icon when size of the screen is small
                          // and larger button with text when it is bigger
                          child: size > 375
                              ? Row(
                                  children: [
                                    const Icon(Icons.cached),
                                    const Text('Yëngal'),
                                  ],
                                )
                              : const Icon(Icons.cached),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
