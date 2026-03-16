import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/game_screen.dart';

/// A simple scrolling list of words the user has found, with definition tooltips.
class WordList extends StatelessWidget {
  final List<String> words;

  const WordList({super.key, required this.words});

  @override
  Widget build(BuildContext context) {
    if (words.isEmpty) {
      return const Center(child: Text('Tus.'));
    }
    final notifier = context.read<PuzzleNotifier>();

    return ListView.builder(
      itemCount: words.length,
      itemBuilder: (_, index) {
        final word = words[index];
        final definition = notifier.getDefinition(word);
        
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: GestureDetector(
            onTap: () => notifier.setActiveDefinition(word, definition),
            child: Text(
              word,
              style: const TextStyle(
                decoration: TextDecoration.underline,
                decorationStyle: TextDecorationStyle.dotted,
              ),
            ),
          ),
        );
      },
    );
  }
}
