import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../models/puzzle.dart';
import '../services/alphabet_loader.dart';
import '../services/word_loader.dart';
import '../services/puzzle_generator.dart';
import '../services/word_validator.dart';
import '../widgets/letter_wheel.dart';
import '../widgets/word_list.dart';

/// Notifier that holds the current puzzle state and user progress.
class PuzzleNotifier extends ChangeNotifier {
  Puzzle? _puzzle;
  List<String> _alphabet = [];
  Set<String> _dictionary = {};

  /// Number of entries in the currently loaded dictionary. Useful for
  /// debugging or displaying to the user.
  int get dictionarySize => _dictionary.length;
  final List<String> _found = [];

  Puzzle? get puzzle => _puzzle;
  List<String> get foundWords => List.unmodifiable(_found);

  int get score {
    var s = 0;
    for (var w in _found) {
      s += (w.length > 6 ? 2 : 1);
    }
    return s;
  }

  int get totalPossible => _puzzle?.totalWords ?? 0;

  Future<void> initialize() async {
    debugPrint('initialize: beginning');
    try {
      // load assets; paths could be parameterized later
      // load the Wolof alphabet and word list we prepared earlier.
      // the alphabet file contains accented characters that won't be present
      // in the default english `alphabet.txt`.
      _alphabet = await AlphabetLoader.loadFromAsset(
          'assets/alphabets/wolof_alphabet.txt');
      debugPrint('initialize: alphabet loaded (${_alphabet.length} letters)');
      final words =
          await WordLoader.loadFromAsset('assets/wordlists/wolof_words.txt');
      debugPrint('initialize: words asset returned ${words.length} entries');

      _dictionary = words;

      // generate the first puzzle (daily seed)
      final today = DateTime.now();
      final seed = int.parse(DateFormat('yyyyMMdd').format(today));
      _puzzle = PuzzleGenerator.generateDaily(seed, _alphabet, words);
      debugPrint(
          'initialize: daily puzzle center=${_puzzle?.centerLetter} totalWords=${_puzzle?.totalWords}');
      // if the daily puzzle happens to have no valid words (common with
      // small/foreign word lists), fall back to a random playable puzzle
      if (_puzzle!.validWords.isEmpty) {
        _puzzle = PuzzleGenerator.generateRandom(_alphabet, _dictionary);
        debugPrint(
            'initialize: daily empty, used random center=${_puzzle?.centerLetter} totalWords=${_puzzle?.totalWords}');
      }
      notifyListeners();
      debugPrint('initialize: finished successfully');
    } catch (e, st) {
      debugPrint('initialize failed: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  bool submit(String input) {
    final w = input.trim().toLowerCase();
    if (_puzzle == null) return false;
    if (w.isEmpty) return false;
    if (_found.contains(w)) return false;
    if (WordValidator.isValid(w, _puzzle!, _dictionary)) {
      _found.add(w);
      notifyListeners();
      return true;
    }
    return false;
  }

  void shuffleOuter() {
    if (_puzzle == null) return;
    // simple shuffle of outer letters maintaining center
    final outer =
        _puzzle!.letters.where((l) => l != _puzzle!.centerLetter).toList();
    outer.shuffle();
    final all = <String>[]
      ..addAll(outer)
      ..add(_puzzle!.centerLetter);
    // since Puzzle is immutable we recreate
    _puzzle = Puzzle(
      centerLetter: _puzzle!.centerLetter,
      letters: all,
      validWords: _puzzle!.validWords,
    );
    notifyListeners();
  }

  /// Replace the current puzzle with a fresh one using a (pseudo)random seed.
  /// Also clears any words that the user has found.
  void refreshPuzzle() {
    if (_alphabet.isEmpty || _dictionary.isEmpty) return;

    final oldCenter = _puzzle?.centerLetter;
    // generate a random puzzle that has at least one valid word
    var newPuzzle = PuzzleGenerator.generateRandom(_alphabet, _dictionary);
    // if by bad luck the center didn't change, try one more time
    if (oldCenter != null && newPuzzle.centerLetter == oldCenter) {
      newPuzzle = PuzzleGenerator.generateRandom(_alphabet, _dictionary);
    }

    _puzzle = newPuzzle;
    _found.clear();
    notifyListeners();
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({Key? key}) : super(key: key);

  @override
  _GameScreenState createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late TextEditingController _controller;
  late PuzzleNotifier _notifier;
  String _message = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _notifier = context.read<PuzzleNotifier>();
    // fire off initialization
    Timer.run(() async {
      await _notifier.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Word Puzzle'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'New puzzle',
            onPressed: () {
              _notifier.refreshPuzzle();
              setState(() {
                _message = '';
                _controller.clear();
              });
            },
          ),
        ],
      ),
      body: Consumer<PuzzleNotifier>(
        builder: (context, notifier, _) {
          final puzzle = notifier.puzzle;
          if (puzzle == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                LetterWheel(
                  puzzle: puzzle,
                  onLetterTap: (l) {
                    _controller.text += l;
                  },
                  onShuffle: notifier.shuffleOuter,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration:
                            const InputDecoration(labelText: 'Enter word'),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        final success = notifier.submit(_controller.text);
                        setState(() {
                          _message = success ? 'Good!' : 'Invalid';
                        });
                        if (success) _controller.clear();
                      },
                      child: const Text('Submit'),
                    )
                  ],
                ),
                if (_message.isNotEmpty) Text(_message),
                const SizedBox(height: 8),
                Text('Score: ${notifier.score} / ${notifier.totalPossible}'),
                // show dictionary size for debugging
                Text('Words loaded: ${notifier.dictionarySize}'),
                const SizedBox(height: 8),
                Expanded(
                  child: WordList(words: notifier.foundWords),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
