import 'package:flutter/material.dart';

class ProgressThermometer extends StatelessWidget {
  final int currentWords;
  final int totalPossibleWords;
  final String? username;
  final VoidCallback? onUsernameChange;

  const ProgressThermometer({
    super.key,
    required this.currentWords,
    required this.totalPossibleWords,
    this.username,
    this.onUsernameChange,
  });

  @override
  Widget build(BuildContext context) {
    final int displayWords = currentWords > 100 ? 100 : currentWords;
    final double fillPercentage = displayWords / 100.0;
    
    final Map<int, String> labels = {
      100: 'Jambar',
      80: 'Ku sawar nga',
      60: 'Rafet na lool',
      40: 'Baax na',
      20: 'Yaa ngiy goor-goorlu',
      0: 'Ndoor',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      width: 250,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (username != null && username!.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    username!,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onUsernameChange,
                  icon: const Icon(Icons.edit, size: 18),
                  tooltip: 'soppi sa tur',
                  style: IconButton.styleFrom(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
          ],
          Text(
            'Baat yi (Total words): $totalPossibleWords',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(255, 71, 57, 13),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Am nga: $currentWords baat',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 300,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Vertical bar
                Container(
                  width: 24,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                      height: 300 * fillPercentage,
                      width: 24,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.orange,
                            Colors.amber,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Labels
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        clipBehavior: Clip.none,
                        children: labels.entries.map((entry) {
                          final fraction = entry.key / 100.0;
                          // Invert fraction because stack is top-to-bottom
                          final topOffset = constraints.maxHeight * (1.0 - fraction);
                          
                          // Determine if this level is reached
                          final isReached = currentWords >= entry.key;

                          return Positioned(
                            top: topOffset - 10, // Adjust to vertical center of text
                            left: 0,
                            right: 0,
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 2,
                                  color: isReached ? Colors.amber : Colors.grey.withValues(alpha: 0.5),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    entry.value,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isReached ? FontWeight.bold : FontWeight.normal,
                                      color: isReached 
                                          ? Theme.of(context).colorScheme.onSurface 
                                          : Colors.grey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
