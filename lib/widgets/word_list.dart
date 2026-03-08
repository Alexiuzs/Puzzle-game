import 'package:flutter/material.dart';

/// A simple scrolling list of words the user has found.
class WordList extends StatelessWidget {
  final List<String> words;

  const WordList({Key? key, required this.words}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (words.isEmpty) {
      return const Center(child: Text('No words yet.'));
    }
    return ListView.builder(
      itemCount: words.length,
      itemBuilder: (_, index) => ListTile(
        title: Text(words[index]),
      ),
    );
  }
}
