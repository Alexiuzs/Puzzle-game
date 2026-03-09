import 'package:flutter/material.dart';

/// A simple scrolling list of words the user has found.
class WordList extends StatelessWidget {
  final List<String> words;

  const WordList({super.key, required this.words});

  @override
  Widget build(BuildContext context) {
    if (words.isEmpty) {
      return const Center(child: Text('Tus.'));
    }
    return ListView.builder(
      itemCount: words.length,
      itemBuilder: (_, index) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.0),
        child: Text(words[index]),
      ),
    );
  }
}
