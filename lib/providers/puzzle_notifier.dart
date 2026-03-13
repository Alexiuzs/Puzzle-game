import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/puzzle.dart';
import '../services/alphabet_loader.dart';
import '../services/word_loader.dart';
import '../services/puzzle_generator.dart';
import '../services/word_validator.dart';
import '../services/proverbs_service.dart';
import '../screens/game_screen.dart';

/// Notifier that holds the current puzzle state and user progress.
class PuzzleNotifier extends ChangeNotifier {
  Puzzle? _puzzle;
  List<String> _alphabet = [];
  Set<String> _dictionary = {};
  Map<String, String> _definitions = {};
  final ProverbsService _proverbsService = ProverbsService();

  bool get hasHashMismatch => _proverbsService.hasHashMismatch;

  PuzzleDifficulty _difficulty = PuzzleDifficulty.easy;
  PuzzleDifficulty get difficulty => _difficulty;

  DateTime _currentDate = DateTime.now();
  DateTime get currentDate => _currentDate;

  void setDifficulty(PuzzleDifficulty diff) {
    if (_difficulty == diff) return;
    _saveState(); // Save current progress before switching
    _difficulty = diff;
    _loadPuzzleForDate(_currentDate, isInitial: false);
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
      debugPrint('initialize: loading alphabet');
      _alphabet = await AlphabetLoader.loadFromAsset(
        'assets/alphabets/wolof_alphabet.txt',
      );
      debugPrint('initialize: loading words');
      final words = await WordLoader.loadFromAsset(
        'assets/wordlists/wolof_words.txt',
      );
      _dictionary = words;

      try {
        debugPrint('initialize: loading definitions');
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
      debugPrint('initialize: loading puzzle for date');
      await _loadPuzzleForDate(_currentDate);

      // Lazily load the proverbs index
      debugPrint('initialize: loading proverbs but dont wait');
      _proverbsService.initialize();

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

    _puzzle = await PuzzleGenerator.generateDaily(
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
    final diffName = _difficulty.name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('found_${seed}_$diffName', _found);
    await prefs.setStringList('tried_${seed}_$diffName', _triedWords);
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
    String share = "Wolofle ($levelStr) - $dateStr\n";
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
    var newPuzzle = PuzzleGenerator.generateRandom(
      _alphabet,
      _dictionary,
      difficulty: _difficulty,
    );
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

  String getProverb(String word) {
    // Try to get proverb first
    return _proverbsService.getRandomProverb(word);
  }

  String getDefinition(String word) {
    // Fall back to definition if exist or return "Gisul lu ni mel."
    return _definitions[word.toLowerCase()] ?? "Gisul lu ni mel.";
  }
}
