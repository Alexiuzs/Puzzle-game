import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:confetti/confetti.dart';
import 'package:share_plus/share_plus.dart';

import '../models/puzzle.dart';
import '../models/lexical_entry.dart';
import '../services/alphabet_loader.dart';
import '../services/puzzle_generator.dart';
import '../services/word_validator.dart';
import '../widgets/letter_wheel.dart';
import '../widgets/word_list.dart';
import '../widgets/shake_widget.dart';
import '../theme_notifier.dart';

enum SubmitResult { success, alreadyFound, invalid, missingCenter }

/// Notifier that holds the current puzzle state and user progress.
class PuzzleNotifier extends ChangeNotifier {
  Puzzle? _puzzle;
  List<String> _alphabet = [];
  Set<String> _dictionary = {}; // Separate list of words from the same wordlist
  List<dynamic> wordlist = []; // List of word objects in json format
  // String? _activeWord;
  // String? _activeDefinition;

  // String? get activeWord => _activeWord;
  // String? get activeDefinition => _activeDefinition;
  LexicalEntry? activeLexicalEntry;

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

  double get progressPercentage {
    if (totalPossible == 0) return 0.0;
    return _found.length / totalPossible;
  }

  List<String> getHints() {
    if (_puzzle == null) return [];

    // Get all valid words that haven't been found yet
    final remaining = _puzzle!.validWords
        .where((w) => !_found.contains(w))
        .toList();

    // Extract first letters of remaining words and remove duplicates
    final hints = remaining
        .map((w) => w.substring(0, 1).toUpperCase())
        .toSet()
        .toList();
    hints.sort();

    return hints;
  }

  Future<void> initialize() async {
    debugPrint('initialize: beginning');

    // if we're in debug mode, check the hashes to make sure our data is up to date
    if (kDebugMode) {
      // get saved hash
      final rawHashData = await rootBundle.loadString(
        'assets/generated/hash.json',
      );
      final hashObjects = json.decode(rawHashData);
      final savedHash = hashObjects['data'][0]['hash'].toString();

      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final dataFiles = manifest
          .listAssets()
          .where(
            (path) =>
                path.startsWith('assets/data/') && !path.endsWith('.DS_Store'),
          )
          .toList();

      // Sort alphabetically by filename
      dataFiles.sort((a, b) => a.split('/').last.compareTo(b.split('/').last));

      final List<int> allBytes = [];
      for (var path in dataFiles) {
        final byteData = await rootBundle.load(path);
        allBytes.addAll(byteData.buffer.asUint8List());
      }
      final md5Hash = md5.convert(allBytes).toString();
      if (md5Hash != savedHash) {
        debugPrint('Hash mismatch! Data has changed.');
        debugPrint('Rerun the prebuild script to update the data.');
        assert(() {
          throw Exception("____________Data is NOT up to date____________");
        }());
      }
    }

    try {
      // load the wordlist data
      final rawWordlistData = await rootBundle.loadString(
        'assets/generated/wordlist.json',
      );
      final wordObjects = json.decode(rawWordlistData);
      wordlist = wordObjects['data'];

      // get the list of words
      _dictionary = wordlist.map((e) => e['word'].toString()).toList().toSet();

      // Alphabet
      _alphabet = await AlphabetLoader.loadFromAsset(
        'assets/alphabets/wolof_alphabet.txt',
      );

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

    // On first load of the day, we default to the single daily puzzle.
    if (isInitial) {
      // No difficulty to set
    }

    _puzzle = PuzzleGenerator.generateDaily(seed, _alphabet, _dictionary);
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

    // Check if center letter is missing
    if (!w.contains(_puzzle!.centerLetter.toLowerCase())) {
      return SubmitResult.missingCenter;
    }

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
    // Unique key per date ensures words are remembered
    final savedFound = prefs.getStringList('found_$seed') ?? [];
    final savedTried = prefs.getStringList('tried_$seed') ?? [];

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

  Future<LexicalEntry> getLexicalEntry(String word) async {
    final wordObject = wordlist.firstWhere(
      (e) => e['word'].toString().toLowerCase() == word.toLowerCase(),
    );
    return LexicalEntry.fromJson(wordObject);
  }

  Future<void> setActiveLexicalEntry(String word) async {
    if (activeLexicalEntry?.word == word) {
      clearActiveLexicalEntry();
    } else {
      activeLexicalEntry = await getLexicalEntry(word);
      notifyListeners();
    }
  }

  void clearActiveLexicalEntry() {
    activeLexicalEntry = null;
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
  String _wologramBanner = '';
  final GlobalKey<ShakeWidgetState> _shakeKey = GlobalKey<ShakeWidgetState>();
  final GlobalKey<LetterWheelState> _wheelKey = GlobalKey<LetterWheelState>();
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
    double progressBarDisplay = 0;

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
                PopupMenuItem(
                  enabled: false,
                  child: Text(
                    'Baat yi (Total words): ${notifier.totalPossible}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color.fromARGB(255, 71, 57, 13),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          Consumer<PuzzleNotifier>(
            builder: (context, notifier, _) {
              final canHint = notifier.progressPercentage >= 0.25;
              return IconButton(
                icon: const Icon(Icons.lightbulb_outline),
                tooltip: canHint
                    ? 'Hints'
                    : 'Find 25% of words to unlock hints',
                onPressed: canHint
                    ? () {
                        final hints = notifier.getHints();
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Indi yi (Hint Letters)'),
                            content: Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: hints
                                  .map((h) => Chip(label: Text(h)))
                                  .toList(),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Baax na'),
                              ),
                            ],
                          ),
                        );
                      }
                    : null,
              );
            },
          ),
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
      body: GestureDetector(
        onTap: () => _notifier.clearActiveLexicalEntry(),
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Consumer<PuzzleNotifier>(
              builder: (context, notifier, _) {
                // TODO if found goes over a multiple of 20, flash a congratulations screen
                final found = notifier.foundWords.length.toDouble();
                if (found >= 1 && found <= 20) {
                  progressBarDisplay = found;
                }
                progressBarDisplay = ((found - 1) % 20) + 1;

                return LinearProgressIndicator(
                  value: progressBarDisplay / 20,
                  backgroundColor: Colors.grey[200],

                  // bucketOfTwenty(5);    // 0
                  // bucketOfTwenty(20);   // 0
                  // bucketOfTwenty(21);   // 1
                  // bucketOfTwenty(40);   // 1
                  // bucketOfTwenty(55);   // 2
                  valueColor: AlwaysStoppedAnimation<Color>(
                    colorList[(found - 1) ~/ 20],
                  ),
                  minHeight: 8,
                );
              },
            ),
            Expanded(
              child: Consumer<PuzzleNotifier>(
                builder: (context, notifier, _) {
                  final puzzle = notifier.puzzle;
                  if (puzzle == null) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  List<String> acceptedLetters = [];
                  acceptedLetters.addAll(puzzle.letters);
                  acceptedLetters.add(puzzle.centerLetter);

                  Widget wheel = LetterWheel(
                    key: _wheelKey,
                    puzzle: puzzle,
                    onLetterTap: (l) {
                      if (!acceptedLetters.contains(l)) return;
                      _controller.text += l;
                      setState(() {});
                    },
                  );
                  List<Widget> input = [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Erase last letter button
                        IconButton.filled(
                          onPressed: () {
                            if (_controller.text.isNotEmpty) {
                              // Remove last character (handles multi-byte Wolof characters)
                              final chars = _controller.text.characters;
                              setState(() {
                                _controller.text = chars
                                    .take(chars.length - 1)
                                    .toString();
                              });
                            }
                          },
                          icon: const Icon(Icons.backspace_outlined),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.grey.withValues(alpha: 0.2),
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onSurface,
                          ),
                          tooltip: 'Erase last letter',
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ShakeWidget(
                            key: _shakeKey,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _controller.text.isEmpty
                                    ? '...'
                                    : _controller.text,
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.displayMedium
                                    ?.copyWith(
                                      color: _controller.text.isEmpty
                                          ? Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                                .withValues(alpha: 0.3)
                                          : null,
                                    ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Submit button
                        ElevatedButton(
                          onPressed: _handleSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors
                                .green, // const Color.fromARGB(255, 26, 162, 49),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(12),
                              ),
                            ),
                          ),
                          child: const Text(
                            'Yónni ko',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    // Shuffle button above submit row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            _wheelKey.currentState?.triggerShuffle(
                              notifier.shuffleOuter,
                            );
                          },
                          icon: const Icon(Icons.cached, size: 16),
                          label: const Text('Yëngal (Shuffle)'),
                          style: TextButton.styleFrom(
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
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
                                Expanded(
                                  child: WordList(words: notifier.foundWords),
                                ),
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
                                Expanded(
                                  child: WordList(words: notifier.triedWords),
                                ),
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
                                      padding: const EdgeInsets.only(
                                        bottom: 16.0,
                                      ),
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
                        emissionFrequency: 0.03,
                        numberOfParticles: 25,
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
                                  Set<String>? wordsSet =
                                      notifier.puzzle?.validWords;
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                            icon: const Icon(Icons.help),
                          ),
                        ),

                      // Definition Overlay
                      if (notifier.activeLexicalEntry != null)
                        Positioned(
                          bottom: 80,
                          left: 20,
                          right: 20,
                          child: GestureDetector(
                            onTap: () => notifier
                                .clearActiveLexicalEntry(), // Dismiss when tapping outside the popup
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .secondaryContainer
                                    .withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    blurRadius: 10,
                                    color: Colors.black.withValues(alpha: 0.1),
                                    spreadRadius: 2,
                                  ),
                                ],
                                border: Border.all(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondary,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          notifier.activeLexicalEntry!.word
                                              .toUpperCase(),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSecondaryContainer,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.close, size: 20),
                                        onPressed: () =>
                                            notifier.clearActiveLexicalEntry(),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                  const Divider(),
                                  Builder(
                                    builder: (context) {
                                      TextStyle definitionStyle = TextStyle(
                                        fontSize: 14,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSecondaryContainer,
                                      );
                                      TextStyle proverbStyle = TextStyle(
                                        fontSize: 14,
                                        fontStyle: FontStyle.italic,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSecondaryContainer,
                                      );
                                      TextStyle refStyle = TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSecondaryContainer
                                            .withValues(alpha: 0.9),
                                      );

                                      final String definition =
                                          notifier
                                              .activeLexicalEntry!
                                              .wolofDef ??
                                          '';
                                      final String wolofProverb =
                                          notifier
                                              .activeLexicalEntry!
                                              .wolofNjaay ??
                                          '';
                                      final String solomonProverb =
                                          notifier
                                              .activeLexicalEntry!
                                              .solomonProverb ??
                                          '';
                                      String parsRef(String ref) {
                                        String rawRef = ref;
                                        if (rawRef.contains(':')) {
                                          final List<String> rawRefList = rawRef
                                              .split(':');

                                          return 'saar ${rawRefList[0]} aaya ${rawRefList[1]}';
                                        }
                                        return rawRef;
                                      }

                                      String ref = parsRef(
                                        notifier
                                                .activeLexicalEntry!
                                                .solomonRef ??
                                            '',
                                      );

                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (definition != '')
                                            Text(
                                              definition,
                                              style: definitionStyle,
                                            ),
                                          if (definition != '' &&
                                              wolofProverb != '')
                                            const SizedBox(height: 8),
                                          if (wolofProverb != '')
                                            Text(
                                              wolofProverb,
                                              style: proverbStyle,
                                            ),
                                          if (wolofProverb != '')
                                            Text(
                                              '\t\tWolof Njaay',
                                              style: refStyle,
                                            ),
                                          if (wolofProverb != '' &&
                                              solomonProverb != '')
                                            const SizedBox(height: 8),
                                          if (solomonProverb != '')
                                            Text(
                                              solomonProverb,
                                              style: proverbStyle,
                                            ),
                                          if (ref != '')
                                            Text(
                                              '\t\tKàddu yu Xelu $ref',
                                              style: refStyle,
                                            ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
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
    } else if (result == SubmitResult.missingCenter) {
      await Haptics.vibrate(HapticsType.error);
      _wheelKey.currentState?.triggerPulse();
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
      } else if (result == SubmitResult.missingCenter) {
        _message = 'Araf bi ci biir!';
      } else {
        _message = 'Baaxul';
      }
    });
    _controller.clear();
  }
}

const List<Color> colorList = [
  Colors.amber,
  Colors.green,
  Colors.blue,
  Colors.orange,
  Colors.purple,
  Colors.lime,
  Colors.teal,
  Colors.pink,
  Colors.indigo,
  Colors.amber,
  Colors.grey,
  Colors.deepOrange,
  Colors.deepPurple,
  Colors.lightBlue,
  Colors.lightGreen,
  Colors.blueGrey,
  Colors.black,
];
