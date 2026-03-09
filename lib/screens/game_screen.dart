import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
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
import '../theme_notifier.dart';

enum SubmitResult { success, alreadyFound, invalid }

/// Notifier that holds the current puzzle state and user progress.
class PuzzleNotifier extends ChangeNotifier {
  Puzzle? _puzzle;
  List<String> _alphabet = [];
  Set<String> _dictionary = {};

  PuzzleDifficulty _difficulty = PuzzleDifficulty.easy;
  PuzzleDifficulty get difficulty => _difficulty;

  void setDifficulty(PuzzleDifficulty diff) {
    if (_difficulty == diff) return;
    _difficulty = diff;
    refreshPuzzle();
  }

  /// Number of entries in the currently loaded dictionary. Useful for
  /// debugging or displaying to the user.
  int get dictionarySize => _dictionary.length;
  final List<String> _found = [];
  final List<String> _triedWords = [];

  Puzzle? get puzzle => _puzzle;
  List<String> get foundWords {
    final list = _found.toList()..sort();
    return List.unmodifiable(list);
  }

  List<String> get triedWords {
    // Show most recent attempts at the top, or optionally sorted as well.
    return List.unmodifiable(_triedWords.reversed);
  }

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
        'assets/alphabets/wolof_alphabet.txt',
      );
      debugPrint('initialize: alphabet loaded (${_alphabet.length} letters)');
      final words = await WordLoader.loadFromAsset(
        'assets/wordlists/wolof_words.txt',
      );
      debugPrint('initialize: words asset returned ${words.length} entries');

      _dictionary = words;

      // generate the first puzzle (daily seed)
      final today = DateTime.now();
      final seed = int.parse(DateFormat('yyyyMMdd').format(today));

      // We want the starting screen to always have at least 15 valid words.
      int dailySeed = seed;
      while (true) {
        _puzzle = PuzzleGenerator.generateDaily(dailySeed, _alphabet, words);
        if (_puzzle!.totalWords >= 15) break;
        dailySeed++; // Deterministically hunt until we hit an 'Easy' valid combo for the day
      }

      debugPrint(
        'initialize: daily puzzle center=${_puzzle?.centerLetter} totalWords=${_puzzle?.totalWords}',
      );
      notifyListeners();
      debugPrint('initialize: finished successfully');
    } catch (e, st) {
      debugPrint('initialize failed: $e');
      debugPrint('$st');
      rethrow;
    }
  }

  SubmitResult submit(String input) {
    final w = input.trim().toLowerCase();
    if (_puzzle == null) return SubmitResult.invalid;
    if (w.isEmpty) return SubmitResult.invalid;
    if (_found.contains(w)) return SubmitResult.alreadyFound;
    if (WordValidator.isValid(w, _puzzle!, _dictionary)) {
      _found.add(w);
      notifyListeners();
      return SubmitResult.success;
    }
    if (!_triedWords.contains(w)) {
      _triedWords.add(w);
      notifyListeners();
    }
    return SubmitResult.invalid;
  }

  void shuffleOuter() {
    if (_puzzle == null) return;
    // simple shuffle of outer letters maintaining center
    final outer = _puzzle!.letters
        .where((l) => l != _puzzle!.centerLetter)
        .toList();
    outer.shuffle();
    final all = <String>[...outer, _puzzle!.centerLetter];
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
    var newPuzzle = PuzzleGenerator.generateRandom(
      _alphabet,
      _dictionary,
      difficulty: _difficulty,
    );
    // if by bad luck the center didn't change, try one more time
    if (oldCenter != null && newPuzzle.centerLetter == oldCenter) {
      newPuzzle = PuzzleGenerator.generateRandom(
        _alphabet,
        _dictionary,
        difficulty: _difficulty,
      );
    }

    _puzzle = newPuzzle;
    _found.clear();
    _triedWords.clear();
    notifyListeners();
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  GameScreenState createState() => GameScreenState();
}

class GameScreenState extends State<GameScreen> {
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
    var size = MediaQuery.sizeOf(context);

    bool wideScreen = size.width > 700 ? true : false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wolofle'),
        actions: [
          Consumer<PuzzleNotifier>(
            builder: (context, notifier, _) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(
                      height: 32,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<PuzzleDifficulty>(
                          value: notifier.difficulty,
                          onChanged: (diff) {
                            if (diff != null) {
                              notifier.setDifficulty(diff);
                              setState(() {
                                _message = '';
                              });
                              _controller.clear();
                            }
                          },
                          items: const [
                            DropdownMenuItem(
                              value: PuzzleDifficulty.easy,
                              child: Text('Yomb Na'),
                            ),
                            DropdownMenuItem(
                              value: PuzzleDifficulty.medium,
                              child: Text('Bu Yëm'),
                            ),
                            DropdownMenuItem(
                              value: PuzzleDifficulty.hard,
                              child: Text('Jafe Na'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Text(
                      '${notifier.dictionarySize} baat yi',
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
              );
            },
          ),
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
          VerticalDivider(),
          Icon(
            Theme.of(context).brightness == Brightness.dark
                ? Icons.dark_mode
                : Icons.light_mode,
          ),
          Consumer<ThemeNotifier>(
            builder: (context, theme, _) {
              return Switch(
                value: theme.isDarkMode,
                onChanged: (v) => theme.toggleTheme(v),
                activeThumbColor: Colors.amber,
              );
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
          List<String> acceptedLetters = [];
          acceptedLetters.addAll(puzzle.letters);
          acceptedLetters.add(puzzle.centerLetter);

          Widget wheel = LetterWheel(
            puzzle: puzzle,
            onLetterTap: (l) {
              if (!acceptedLetters.contains(l)) return;

              _controller.text += l;
            },
            onShuffle: notifier.shuffleOuter,
          );
          List<Widget> input = [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: 'Bindal fii...',
                    ),
                    onSubmitted: (_) {
                      final result = notifier.submit(_controller.text);
                      setState(() {
                        if (result == SubmitResult.success) {
                          _message = 'Baax na!';
                        } else if (result == SubmitResult.alreadyFound) {
                          _message = 'Baax na (Ba pare)';
                        } else {
                          _message = 'Baaxul';
                        }
                      });
                      _controller.clear();
                    },
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    final result = notifier.submit(_controller.text);
                    setState(() {
                      if (result == SubmitResult.success) {
                        _message = 'Baax na!';
                      } else if (result == SubmitResult.alreadyFound) {
                        _message = 'Baax na (Ba pare)';
                      } else {
                        _message = 'Baaxul';
                      }
                    });
                    _controller.clear();
                  },
                  child: const Text('Yoone ko'),
                ),
              ],
            ),
            if (_message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  _message,
                  style: TextStyle(
                    color: _message.startsWith('Baax na')
                        ? Colors.green
                        : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Baax na ( ${notifier.foundWords.length} / ${notifier.totalPossible} )',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Expanded(child: WordList(words: notifier.foundWords)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Baaxul',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Expanded(child: WordList(words: notifier.triedWords)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (kDebugMode)
              Align(
                alignment: .centerEnd,
                child: IconButton.filledTonal(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) {
                        List<Widget> wordsWidgets = [];
                        Set<String>? wordsSet = notifier.puzzle?.validWords;
                        if (wordsSet != null && wordsSet.isNotEmpty) {
                          for (String word in wordsSet) {
                            wordsWidgets.add(Text(word));
                          }
                        }

                        return AlertDialog(
                          title: const Text('Jàpple ma!'),
                          content: SingleChildScrollView(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: wordsWidgets,
                            ),
                          ),
                          actions: [
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  icon: Icon(Icons.help),
                ),
              ),
          ];

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: wideScreen
                ? Row(
                    children: [
                      Expanded(child: wheel),
                      SizedBox(width: 16),
                      SizedBox(
                        width: min(size.width / 2, 400),
                        child: Column(children: input),
                      ),
                    ],
                  )
                : Column(
                    children: [wheel, const SizedBox(height: 16), ...input],
                  ),
          );
        },
      ),
    );
  }
}
