import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:confetti/confetti.dart';

import '../models/puzzle.dart';
import '../services/alphabet_loader.dart';
import '../services/word_loader.dart';
import '../services/puzzle_generator.dart';
import '../services/word_validator.dart';
import '../widgets/letter_wheel.dart';
import '../widgets/word_list.dart';
import '../widgets/shake_widget.dart';
import '../theme_notifier.dart';

enum SubmitResult { success, alreadyFound, invalid }

/// Notifier that holds the current puzzle state and user progress.
class PuzzleNotifier extends ChangeNotifier {
  Puzzle? _puzzle;
  List<String> _alphabet = [];
  Set<String> _dictionary = {};
  Map<String, String> _definitions = {};

  DateTime _currentDate = DateTime.now();
  DateTime get currentDate => _currentDate;

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
      if (w.length <= 4) {
        s += 1;
      } else {
        s += w.length;
      }

      // Check for Wologram (uses all 7 letters)
      if (_puzzle != null) {
        final Set<String> wordLetters = w.runes
            .map((r) => String.fromCharCode(r))
            .toSet();
        final Set<String> puzzleLetters = _puzzle!.letters.toSet();
        if (puzzleLetters.difference(wordLetters).isEmpty) {
          s += 10; // Wologram Bonus (+10)
        }
      }
    }
    return s;
  }

  int get maxPossibleScore {
    if (_puzzle == null) return 0;
    var maxScore = 0;
    for (var w in _puzzle!.validWords) {
      if (w.length <= 4) {
        maxScore += 1;
      } else {
        maxScore += w.length;
      }

      final Set<String> wordLetters = w.runes
          .map((r) => String.fromCharCode(r))
          .toSet();
      final Set<String> puzzleLetters = _puzzle!.letters.toSet();
      if (puzzleLetters.difference(wordLetters).isEmpty) {
        maxScore += 10;
      }
    }
    return maxScore;
  }

  String get currentRank {
    if (maxPossibleScore == 0) return 'Ndongo'; // Beginner
    final double percentage = score / maxPossibleScore;

    if (percentage == 1.0) return 'Kàngam'; // Genius / Master
    if (percentage >= 0.7) return 'Jàmbaar'; // Outstanding
    if (percentage >= 0.5) return 'Rafet na'; // Amazing
    if (percentage >= 0.4) return 'Baax na lool'; // Great
    if (percentage >= 0.25) return 'Baax na'; // Solid
    if (percentage >= 0.15) return 'Maa ngi ci kawam'; // Nice
    if (percentage >= 0.08) return 'Ku baax'; // Good
    if (percentage >= 0.02) return 'Ku bees'; // Moving up
    return 'Ndongo'; // Beginner
  }

  bool isWologram(String word) {
    if (_puzzle == null) return false;
    final Set<String> wordLetters = word.runes
        .map((r) => String.fromCharCode(r))
        .toSet();
    final Set<String> puzzleLetters = _puzzle!.letters.toSet();
    return puzzleLetters.difference(wordLetters).isEmpty;
  }

  int get totalPossible => _puzzle?.totalWords ?? 0;

  Future<void> initialize() async {
    debugPrint('initialize: beginning');
    try {
      _alphabet = await AlphabetLoader.loadFromAsset(
        'assets/alphabets/wolof_alphabet.txt',
      );
      final words = await WordLoader.loadFromAsset(
        'assets/wordlists/wolof_words.txt',
      );
      _dictionary = words;

      try {
        final defsJson = await rootBundle.loadString(
          'assets/wordlists/wolof_definitions.json',
        );
        final Map<String, dynamic> decoded = json.decode(defsJson);
        _definitions = decoded.map(
          (key, value) => MapEntry(key, value.toString()),
        );
      } catch (e) {
        debugPrint('initialize: could not load definitions: $e');
      }

      await _loadPuzzleForDate(_currentDate);

      debugPrint('initialize: finished successfully');
    } catch (e) {
      debugPrint('initialize failed: $e');
      rethrow;
    }
  }

  Future<void> _loadPuzzleForDate(
    DateTime date, {
    bool isInitial = true,
  }) async {
    final seed = int.parse(DateFormat('yyyyMMdd').format(date));

    // On first load of the day, we can pick a "suggested" difficulty
    // or just default to Easy as requested by the user.
    if (isInitial) {
      _difficulty = PuzzleDifficulty.easy;
    }

    _puzzle = PuzzleGenerator.generateDaily(
      seed,
      _alphabet,
      _dictionary,
      difficulty: _difficulty,
    );
    await _loadSavedState(seed);
    notifyListeners();
  }

  Future<void> setPuzzleDate(DateTime date) async {
    _currentDate = date;
    await _loadPuzzleForDate(date);
  }

  SubmitResult submit(String input) {
    final w = input.trim().toLowerCase();
    if (_puzzle == null) return SubmitResult.invalid;
    if (w.isEmpty) return SubmitResult.invalid;
    if (_found.contains(w)) return SubmitResult.alreadyFound;
    if (WordValidator.isValid(w, _puzzle!, _dictionary)) {
      _found.add(w);
      _saveState();
      notifyListeners();
      return SubmitResult.success;
    }
    if (!_triedWords.contains(w)) {
      _triedWords.add(w);
      _saveState();
      notifyListeners();
    }
    return SubmitResult.invalid;
  }

  Future<void> _loadSavedState(int seed) async {
    final prefs = await SharedPreferences.getInstance();
    // Unique key per date AND difficulty ensures words are remembered separately
    final diffName = _difficulty.name;
    final savedFound = prefs.getStringList('found_${seed}_$diffName') ?? [];
    final savedTried = prefs.getStringList('tried_${seed}_$diffName') ?? [];

    _found.clear();
    _found.addAll(savedFound);
    _triedWords.clear();
    _triedWords.addAll(savedTried);
  }

  Future<void> _saveState() async {
    if (_puzzle == null) return;
    final seed = int.parse(DateFormat('yyyyMMdd').format(_currentDate));
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('found_$seed', _found);
    await prefs.setStringList('tried_$seed', _triedWords);
  }

  String generateShareText() {
    if (_puzzle == null) return "Wolofle...";

    final levelStr = _difficulty == PuzzleDifficulty.easy
        ? "Yomb Na"
        : _difficulty == PuzzleDifficulty.medium
        ? "Bu Yem"
        : "Jafe Na";

    final percentage = maxPossibleScore > 0
        ? (score / maxPossibleScore * 100).toStringAsFixed(0)
        : "0";

    final dateStr = DateFormat('yyyy-MM-dd').format(_currentDate);

    // Core stats
    String share = "Wolofle - $dateStr\n";
    share += "Score: $score ($percentage%)\n";
    share += "Rank: $currentRank\n";
    share += "Words Found: ${_found.length} / $totalPossible\n\n";

    // Center letter isolated
    share += "🎯 Center: ${_puzzle!.centerLetter.toUpperCase()}\n\n";

    return share;
  }

  void shuffleOuter() {
    if (_puzzle == null) return;
    final outer = _puzzle!.letters
        .where((l) => l != _puzzle!.centerLetter)
        .toList();
    outer.shuffle();
    final all = <String>[...outer, _puzzle!.centerLetter];
    _puzzle = Puzzle(
      centerLetter: _puzzle!.centerLetter,
      letters: all,
      validWords: _puzzle!.validWords,
    );
    notifyListeners();
  }

  void refreshPuzzle() {
    if (_alphabet.isEmpty || _dictionary.isEmpty) return;

    final oldCenter = _puzzle?.centerLetter;
    var newPuzzle = PuzzleGenerator.generateRandom(_alphabet, _dictionary);
    if (oldCenter != null && newPuzzle.centerLetter == oldCenter) {
      newPuzzle = PuzzleGenerator.generateRandom(_alphabet, _dictionary);
    }

    _puzzle = newPuzzle;
    _found.clear();
    _triedWords.clear();
    notifyListeners();
  }

  String getDefinition(String word) {
    return _definitions[word.toLowerCase()] ??
        "Teggil leeral fii (No definition found)...";
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
  String _wologramBanner = '';
  final GlobalKey<ShakeWidgetState> _shakeKey = GlobalKey<ShakeWidgetState>();
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 1),
    );
    _notifier = context.read<PuzzleNotifier>();
    // fire off initialization
    Timer.run(() async {
      await _notifier.initialize();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.sizeOf(context);

    bool wideScreen = size.width > 600 ? true : false;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Consumer<PuzzleNotifier>(
          builder: (context, notifier, _) {
            return PopupMenuButton<String>(
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [Text('Wolofle'), Icon(Icons.arrow_drop_down)],
              ),
              onSelected: (value) async {
                if (value == 'share') {
                  final text = notifier.generateShareText();
                  await Clipboard.setData(ClipboardData(text: text));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copied results to clipboard!'),
                    ),
                  );
                } else if (value == 'theme') {
                  context.read<ThemeNotifier>().toggleTheme(
                    !context.read<ThemeNotifier>().isDarkMode,
                  );
                } else if (value.startsWith('diff_')) {
                  final diffStr = value.split('_')[1];
                  final diff = PuzzleDifficulty.values.firstWhere(
                    (e) => e.toString().split('.').last == diffStr,
                  );
                  notifier.setDifficulty(diff);
                  setState(() => _message = '');
                  _controller.clear();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'share',
                  child: ListTile(
                    leading: Icon(Icons.share),
                    title: Text('Séedoo ko (Share)'),
                  ),
                ),
                PopupMenuItem(
                  value: 'theme',
                  child: ListTile(
                    leading: Icon(
                      Theme.of(context).brightness == Brightness.dark
                          ? Icons.light_mode
                          : Icons.dark_mode,
                    ),
                    title: Text(
                      Theme.of(context).brightness == Brightness.dark
                          ? 'Melo bu woyof (Light Mode)'
                          : 'Melo bu lëndëm (Dark Mode)',
                    ),
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  enabled: false,
                  child: Text(
                    'Difficulties',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                PopupMenuItem(
                  enabled: false,
                  child: Text(
                    'Baat yi (Total words): ${notifier.totalPossible}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                CheckedPopupMenuItem(
                  value: 'diff_easy',
                  checked: notifier.difficulty == PuzzleDifficulty.easy,
                  child: const Text('Yomb na (Easy)'),
                ),
                CheckedPopupMenuItem(
                  value: 'diff_medium',
                  checked: notifier.difficulty == PuzzleDifficulty.medium,
                  child: const Text('Yëm na (Medium)'),
                ),
                CheckedPopupMenuItem(
                  value: 'diff_hard',
                  checked: notifier.difficulty == PuzzleDifficulty.hard,
                  child: const Text('Jafe na (Hard)'),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Choose date',
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _notifier.currentDate,
                firstDate: DateTime(2024),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                await _notifier.setPuzzleDate(picked);
                setState(() {
                  _message = '';
                  _controller.clear();
                });
              }
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
              setState(() {});
            },
            onShuffle: notifier.shuffleOuter,
          );
          List<Widget> input = [
            Row(
              children: [
                Expanded(
                  child: ShakeWidget(
                    key: _shakeKey,
                    // version where the text is only changeable from the wheel
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _controller.text,
                        textAlign: .center,

                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                    ),

                    // original version
                    // TextField(
                    //   controller: _controller,
                    //   decoration: const InputDecoration(
                    //     labelText: 'Bindal fii...',
                    //   ),
                    //   onSubmitted: (_) {
                    //     _handleSubmit();
                    //   },
                    // ),
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _handleSubmit,
                  child: const Text('Yónni ko'),
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
                        const Text(
                          'Baax na',
                          style: TextStyle(fontWeight: FontWeight.bold),
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
          ];

          return Stack(
            alignment: Alignment.topCenter,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: wideScreen
                    ? Row(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: wheel,
                            ),
                          ),
                          const SizedBox(width: 16),
                          SizedBox(
                            width: min(size.width / 2, 250),
                            child: Column(children: input),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          wheel,
                          const SizedBox(height: 16),
                          Expanded(child: Column(children: input)),
                        ],
                      ),
              ),
              if (_wologramBanner.isNotEmpty)
                Positioned(
                  top: 50,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 10,
                          color: Colors.black.withAlpha(122),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'WOLOGRAM!',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          _wologramBanner.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.black,
                          ),
                        ),
                        const Text(
                          '+10 POINTS BONUS!',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ConfettiWidget(
                confettiController: _confettiController,
                blastDirection: -pi / 2, // upwards
                emissionFrequency: 0.05,
                numberOfParticles: 20,
                maxBlastForce: 20,
                minBlastForce: 10,
                gravity: 0.3,
                colors: const [
                  Colors.green,
                  Colors.blue,
                  Colors.pink,
                  Colors.orange,
                  Colors.purple,
                  Colors.amber,
                ],
              ),
              // Reveal all possible words - shown when running in debug mode only
              if (kDebugMode)
                Positioned(
                  bottom: 16,
                  right: 16,
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
            ],
          );
        },
      ),
    );
  }

  Future<void> _handleSubmit() async {
    final result = _notifier.submit(_controller.text);

    // Trigger haptics and animations based on the result
    if (result == SubmitResult.success) {
      final isWolo = _notifier.isWologram(
        _controller.text.trim().toLowerCase(),
      );
      _confettiController.play();

      if (isWolo) {
        // Wologram Celebration
        await Haptics.vibrate(HapticsType.heavy);
        setState(() {
          _wologramBanner = _controller.text.trim();
        });
        Timer(const Duration(seconds: 4), () {
          if (mounted) setState(() => _wologramBanner = '');
        });
      } else {
        final wordLength = _controller.text.trim().length;
        if (wordLength >= 7) {
          await Haptics.vibrate(HapticsType.heavy);
        } else {
          await Haptics.vibrate(HapticsType.success);
        }
      }
    } else if (result == SubmitResult.invalid) {
      await Haptics.vibrate(HapticsType.error);
      _shakeKey.currentState?.shake();
    } else if (result == SubmitResult.alreadyFound) {
      await Haptics.vibrate(HapticsType.warning);
      _shakeKey.currentState?.shake();
    }

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
  }
}
