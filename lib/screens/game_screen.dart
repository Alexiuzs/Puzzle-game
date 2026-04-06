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

import '../models/puzzle.dart';
import '../models/lexical_entry.dart';
import '../services/alphabet_loader.dart';
import '../services/puzzle_generator.dart';
import '../services/word_validator.dart';
import '../widgets/letter_wheel.dart';
import '../widgets/word_list.dart';
import '../widgets/shake_widget.dart';
import '../theme_notifier.dart';
import '../widgets/instructions_page.dart';
import '../widgets/onboarding_overlay.dart';
import '../widgets/progress_thermometer.dart';
import 'username_screen.dart';

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
  String? username;
  String? lastRank;

  // Stream for rank changes to trigger celebrations in the UI
  final _rankChangedController = StreamController<String>.broadcast();
  Stream<String> get onRankChanged => _rankChangedController.stream;

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

    final prefs = await SharedPreferences.getInstance();
    username = prefs.getString('username');

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

    lastRank = currentRank;
  }

  Future<void> saveUsername(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('username', name);
    username = name;
    notifyListeners();
  }

  String generateRandomUsername() {
    final random = Random();
    final List<String> adjectives = [
      'Ku',
      'Ndongo',
      'Jàmbaar',
      'Rafet',
      'Baax',
      'Bees',
      'Maa',
      'Kàngam',
      'Xelu',
      'Njaay',
      'Saar',
      'Aara',
      'Yéene',
      'Fiit',
      'Ngande',
    ];
    final List<String> nouns = [
      'Kàccoor',
      'Wure',
      'Araf',
      'Baat',
      'Ciyari',
      'Xam-xam',
      'Talibe',
      'Ndeyjoor',
      'Càmmoñ',
      'Nit',
      'Koor',
      'Xoox',
      'Ndajé',
      'Yoon',
      'Lekk',
    ];

    return '${adjectives[random.nextInt(adjectives.length)]}-${nouns[random.nextInt(nouns.length)]}${random.nextInt(100)}';
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

      // Check for rank change
      final newRank = currentRank;
      if (newRank != lastRank) {
        _rankChangedController.add(newRank);
        lastRank = newRank;
      }

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

  @override
  void dispose() {
    _rankChangedController.close();
    super.dispose();
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
    if (_puzzle == null) return "Wure Kaŋ-fóore...";

    final percentage = maxPossibleScore > 0
        ? (score / maxPossibleScore * 100).toStringAsFixed(0)
        : "0";

    final dateStr = DateFormat('yyyy-MM-dd').format(_currentDate);

    // Core stats
    String share = "Wure Kaŋ-fóore - $dateStr\n";
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

    final String stem = wordObject['stem']?.toString() ?? '';
    List<String> derivatives = [];

    if (stem.isNotEmpty) {
      derivatives = wordlist
          .where((e) {
            final eWord = e['word'].toString().toLowerCase();
            final eStem = e['stem']?.toString().toLowerCase();
            return eStem == stem.toLowerCase() && eWord != word.toLowerCase();
          })
          .map((e) {
            String w = e['word'].toString();
            if (w.length > 1) {
              return w[0].toUpperCase() + w.substring(1).toLowerCase();
            }
            return w.toUpperCase();
          })
          .toList();
      derivatives.sort();
    }

    return LexicalEntry.fromJson(wordObject, derivatives: derivatives);
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
  final GlobalKey _centerKey = GlobalKey();
  final GlobalKey _submitKey = GlobalKey();
  final GlobalKey _backspaceKey = GlobalKey();
  final GlobalKey _shuffleKey = GlobalKey();
  final GlobalKey _progressKey = GlobalKey();
  final GlobalKey _menuKey = GlobalKey();

  late ConfettiController _confettiController;
  bool _showOnboarding = false;
  StreamSubscription<String>? _rankSubscription;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 1),
    );
    _notifier = context.read<PuzzleNotifier>();

    // Listen for rank changes to show celebration
    _rankSubscription = _notifier.onRankChanged.listen((newRank) {
      _showCelebrationDialog(newRank);
    });

    // fire off initialization
    Timer.run(() async {
      await _notifier.initialize();
      _checkOnboarding();
    });
  }

  void _showCelebrationDialog(String newRank) {
    _confettiController.play();
    Haptics.vibrate(HapticsType.heavy);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.amber[100],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.stars, size: 80, color: Colors.amber),
            const SizedBox(height: 16),
            Text(
              'Ndokkale ${_notifier.username}!',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.brown,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Yéeg nga maqaama: $newRank!',
              style: const TextStyle(fontSize: 20, color: Colors.brown),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const Text(
              'waaw goor!',
              style: TextStyle(
                fontSize: 18,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Goor-goorlu moo tax a doon goor!',
              style: TextStyle(fontSize: 16, color: Colors.brown),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    final String shareText =
                        'Wure Kaŋ-fóore - Ndokkale ${_notifier.username}!\n'
                        'Yéeg naa ba yékk si daraza bi di $newRank!\n'
                        'waaw goor! Goor-goorlu moo tax a doon goor!\n\n'
                        'Wutal sa wure fii: https://wolofle.web.app';

                    await Clipboard.setData(ClipboardData(text: shareText));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Copied celebration to clipboard!'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.share),
                  label: const Text('Séedoo'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.brown,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Jërëjëf'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool('onboarding_shown_v1') ?? false;
    if (!shown) {
      if (!mounted) return;
      setState(() {
        _showOnboarding = true;
      });
    }
  }

  Future<void> _markOnboardingShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_shown_v1', true);
    if (!mounted) return;
    setState(() {
      _showOnboarding = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _confettiController.dispose();
    _rankSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.sizeOf(context);
    double progressBarDisplay = 0;

    bool wideScreen = size.width > 600 ? true : false;

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            leadingWidth: 180,
            leading: Consumer<PuzzleNotifier>(
              builder: (context, notifier, _) {
                return PopupMenuButton<String>(
                  key: _menuKey,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'Wure Kaŋ-fóore',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Icon(Icons.arrow_drop_down),
                      ],
                    ),
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
                    } else if (value == 'instructions') {
                      if (!context.mounted) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => InstructionsPage(
                            onReplayDemo: () {
                              if (!mounted) return;
                              setState(() {
                                _showOnboarding = true;
                              });
                            },
                          ),
                          fullscreenDialog: true,
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
                    const PopupMenuItem(
                      value: 'instructions',
                      child: ListTile(
                        leading: Icon(Icons.help_outline),
                        title: Text('Naka lañu ciyaar (How to play)'),
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
                  ],
                );
              },
            ),
            actions: [
              Consumer<PuzzleNotifier>(
                builder: (context, notifier, _) {
                  return Theme(
                    data: Theme.of(context).copyWith(
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                    ),
                    child: PopupMenuButton<String>(
                      key: _progressKey,
                      tooltip: 'Sa dem-kanam (Progress)',
                      offset: const Offset(0, 50),
                      icon: const Icon(Icons.bar_chart),
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          enabled: false,
                          padding: EdgeInsets.zero,
                          child: ProgressThermometer(
                            currentWords: notifier.foundWords.length,
                            totalPossibleWords: notifier.totalPossible,
                            username: notifier.username,
                            onUsernameChange: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const UsernameScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
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
                        centerKey: _centerKey,
                        puzzle: puzzle,
                        onLetterTap: (l) {
                          if (!acceptedLetters.contains(l)) return;
                          _controller.text += l;
                          setState(() {
                            _message = ''; // Clear message on input
                          });
                        },
                      );
                      List<Widget> input = [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Erase last letter button
                            IconButton.filled(
                              key: _backspaceKey,
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
                                backgroundColor: Colors.grey.withValues(
                                  alpha: 0.2,
                                ),
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .displayMedium
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
                              key: _submitKey,
                              onPressed: _handleSubmit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
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
                            IconButton(
                              key: _shuffleKey,
                              onPressed: () {
                                _wheelKey.currentState?.triggerShuffle(
                                  notifier.shuffleOuter,
                                );
                              },
                              icon: const Icon(Icons.cached, size: 24),
                              tooltip: 'Yëngal (Shuffle)',
                              style: IconButton.styleFrom(
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
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Expanded(
                                      child: WordList(
                                        words: notifier.foundWords,
                                      ),
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
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Expanded(
                                      child: WordList(
                                        words: notifier.triedWords,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ];

                      Widget mainStack = Stack(
                        alignment: Alignment.topCenter,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
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
                                      if (wordsSet != null &&
                                          wordsSet.isNotEmpty) {
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
                                            onPressed: () =>
                                                Navigator.pop(context),
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
                                        color: Colors.black.withValues(
                                          alpha: 0.1,
                                        ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text.rich(
                                              TextSpan(
                                                text: notifier
                                                    .activeLexicalEntry!
                                                    .word
                                                    .toUpperCase(),
                                                children: [
                                                  if (notifier
                                                      .activeLexicalEntry!
                                                      .derivatives
                                                      .isNotEmpty)
                                                    TextSpan(
                                                      text:
                                                          ' - ${notifier.activeLexicalEntry!.derivatives.join(', ')}',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.normal,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSecondaryContainer,
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(
                                              Icons.close,
                                              size: 20,
                                            ),
                                            onPressed: () => notifier
                                                .clearActiveLexicalEntry(),
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
                                              final List<String> rawRefList =
                                                  rawRef.split(':');

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

                                          Widget _buildBoldedText(
                                            String text,
                                            String targetWord,
                                            TextStyle baseStyle, {
                                            bool italic = false,
                                          }) {
                                            if (text.isEmpty)
                                              return const SizedBox.shrink();

                                            final String lowerText = text
                                                .toLowerCase();
                                            final String lowerTarget =
                                                targetWord.toLowerCase();

                                            final List<TextSpan> spans = [];
                                            int start = 0;
                                            int index = lowerText.indexOf(
                                              lowerTarget,
                                            );

                                            while (index != -1) {
                                              if (index > start) {
                                                spans.add(
                                                  TextSpan(
                                                    text: text.substring(
                                                      start,
                                                      index,
                                                    ),
                                                  ),
                                                );
                                              }
                                              spans.add(
                                                TextSpan(
                                                  text: text.substring(
                                                    index,
                                                    index + targetWord.length,
                                                  ),
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              );
                                              start = index + targetWord.length;
                                              index = lowerText.indexOf(
                                                lowerTarget,
                                                start,
                                              );
                                            }

                                            if (start < text.length) {
                                              spans.add(
                                                TextSpan(
                                                  text: text.substring(start),
                                                ),
                                              );
                                            }

                                            return RichText(
                                              text: TextSpan(
                                                style: baseStyle.copyWith(
                                                  fontStyle: italic
                                                      ? FontStyle.italic
                                                      : null,
                                                ),
                                                children: spans,
                                              ),
                                            );
                                          }

                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              _buildBoldedText(
                                                definition,
                                                notifier
                                                    .activeLexicalEntry!
                                                    .word,
                                                definitionStyle,
                                              ),
                                              if (definition != '' &&
                                                  wolofProverb != '')
                                                const SizedBox(height: 8),
                                              _buildBoldedText(
                                                wolofProverb,
                                                notifier
                                                    .activeLexicalEntry!
                                                    .word,
                                                proverbStyle,
                                                italic: true,
                                              ),
                                              if (wolofProverb != '')
                                                Text(
                                                  '\t\tWolof Njaay',
                                                  style: refStyle,
                                                ),
                                              if (wolofProverb != '' &&
                                                  solomonProverb != '')
                                                const SizedBox(height: 8),
                                              _buildBoldedText(
                                                solomonProverb,
                                                notifier
                                                    .activeLexicalEntry!
                                                    .word,
                                                proverbStyle,
                                                italic: true,
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

                      return mainStack;
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_showOnboarding)
          OnboardingOverlay(
            onFinish: _markOnboardingShown,
            steps: [
              OnboardingStep(
                targetKey: _menuKey,
                title: 'Dalal ak tjàmm ci Wure Kaŋ-fóore!',
                description:
                    ' Wuutal ay baat yu bare ci 7 araf yi ñu jox.\n\nTrouvez autant de mots que possible en utilisant les 7 lettres proposées.',
                shape: HighlightShape.rectangle,
                tweakOffset: const Offset(-30, 0),
              ),
              OnboardingStep(
                targetKey: _wheelKey,
                title: 'Wure araf yi',
                description:
                    'Jëfandikool araf yi nekk ci Wure bi ngir defar ay baat.\n\nUtilisez les lettres dans le cercle pour former des mots.',
                shape: HighlightShape.circle,
                tweakOffset: const Offset(0, 0),
                padding: 2,
              ),
              OnboardingStep(
                targetKey: _centerKey,
                title: 'Baat bi ngay bind',
                description:
                    '• Baat bu nekk war na am 3 araf dem ci kaw.\n• Baat bu nekk war na am araf bu nekk ci digg bi.\n• Mën nga jëfandikoowat araf yi ay yooni yoon.\n\nChaque mot doit contenir au moins 3 lettres et inclure la lettre centrale.',
                shape: HighlightShape.circle,
                tweakOffset: const Offset(0, 0),
              ),
              OnboardingStep(
                targetKey: _submitKey,
                title: 'Yónni ko',
                description:
                    'Bësal fii ngir yónni sa baat ngir natt ko.\n\nAppuyez ici pour valider votre mot.',
              ),
              OnboardingStep(
                targetKey: _backspaceKey,
                title: 'Faar ko',
                description:
                    'Bësal fii ngir faar araf bi gëna teggu.\n\nAppuyez ici pour effacer la dernière lettre.',
                shape: HighlightShape.circle,
              ),
              OnboardingStep(
                targetKey: _shuffleKey,
                title: 'Yëngal araf yi',
                description:
                    'Bësal fii ngir jaxase araf yi.\n\nAppuyez ici pour mélanger les lettres.',
                shape: HighlightShape.circle,
              ),
              OnboardingStep(
                targetKey: _progressKey,
                title: 'Sa dem-kanam',
                description:
                    'Fii ngay gisee naka ngay deme ak sa point yi.\n\nSuivez votre progression et score ici.',
                shape: HighlightShape.circle,
              ),
            ],
          ),
      ],
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
