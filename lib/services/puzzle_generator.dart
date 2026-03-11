import 'dart:math';

import '../models/puzzle.dart';

class PuzzleGenerator {
  /// Generate a daily puzzle based on [dateSeed].
  static Puzzle generateDaily(
    int dateSeed,
    List<String> alphabet,
    Set<String> wordList, {
    required PuzzleDifficulty difficulty,
  }) {
    // We want 3 unique puzzles per day. 
    // We use a combined seed based on date and difficulty to ensure consistency.
    var seed = dateSeed + (difficulty.index * 1000);
    
    while (true) {
      final rng = Random(seed);
      final letters = List<String>.from(alphabet)..shuffle(rng);

      final selected = <String>{};
      for (var l in letters) {
        if (selected.length >= 7) break;
        selected.add(l);
      }
      
      if (selected.length < 7) {
        throw Exception('Alphabet too small to select 7 unique letters');
      }

      final letterList = selected.toList();
      if (_isValidLetterSet(letterList)) {
        final centerIndex = rng.nextInt(letterList.length);
        final center = letterList[centerIndex];
        final valid = _computeValidWords(letterList, center, wordList);
        
        // Requirements:
        // 1. Must have at least one Wologram
        // 2. Must match difficulty word count thresholds
        if (_hasWologram(valid, letterList)) {
          bool isMatch = false;
          final count = valid.length;
          
          switch (difficulty) {
            case PuzzleDifficulty.easy:
              isMatch = count >= 70; // User requested at least 70 for Easy
              break;
            case PuzzleDifficulty.medium:
              isMatch = count >= 50 && count <= 74;
              break;
            case PuzzleDifficulty.hard:
              isMatch = count >= 30 && count <= 49;
              break;
            case PuzzleDifficulty.any:
              isMatch = count >= 1;
              break;
          }

          if (isMatch) {
            return Puzzle(centerLetter: center, letters: letterList, validWords: valid);
          }
        }
      }
      // Increment seed and try again for a higher/lower density match
      seed++;
    }
  }

  static bool _hasWologram(Set<String> validWords, List<String> letters) {
    final letterSet = letters.toSet();
    for (var word in validWords) {
      final wordLetters = word.runes.map((r) => String.fromCharCode(r)).toSet();
      if (letterSet.difference(wordLetters).isEmpty) return true;
    }
    return false;
  }

  /// Generates a completely random puzzle with 2-vowel rule and updated difficulty.
  static Puzzle generateRandom(
    List<String> alphabet,
    Set<String> wordList, {
    PuzzleDifficulty difficulty = PuzzleDifficulty.any,
  }) {
    final rng = Random();
    int attempts = 0;
    while (true) {
      attempts++;
      final copy = List<String>.from(alphabet)..shuffle(rng);
      final selected = <String>{};
      for (var l in copy) {
        if (selected.length >= 7) break;
        selected.add(l);
      }
      if (selected.length < 7) {
        throw Exception('Alphabet too small');
      }
      
      final letterList = selected.toList();
      if (!_isValidLetterSet(letterList)) continue;

      final center = letterList[rng.nextInt(letterList.length)];
      final valid = _computeValidWords(letterList, center, wordList);
      
      bool isMatch = false;
      final count = valid.length;
      
      switch (difficulty) {
        case PuzzleDifficulty.any:
          isMatch = count >= 1;
          break;
        case PuzzleDifficulty.easy:
          // User requested "up the number of words even more"
          isMatch = count >= 75;
          break;
        case PuzzleDifficulty.medium:
          isMatch = count >= 50 && count <= 74;
          break;
        case PuzzleDifficulty.hard:
          isMatch = count >= 30 && count <= 49;
          break;
      }

      // Fallback: if we haven't found a match in 1000 attempts, relax thresholds slightly
      // but only for random puzzles to prevent infinite loops if the dictionary is small.
      if (!isMatch && attempts > 1000) {
          if (difficulty == PuzzleDifficulty.easy && count >= 55) isMatch = true;
          if (difficulty == PuzzleDifficulty.medium && count >= 35) isMatch = true;
          if (difficulty == PuzzleDifficulty.hard && count >= 15) isMatch = true;
      }

      if (isMatch) {
        return Puzzle(
            centerLetter: center, letters: letterList, validWords: valid);
      }
    }
  }

  static bool _isValidLetterSet(List<String> letters) {
    const vowels = {'a', 'à', 'e', 'é', 'ë', 'i', 'o', 'ó', 'u'};
    return letters.where((l) => vowels.contains(l.toLowerCase())).length >= 2;
  }

  static Set<String> _computeValidWords(
    List<String> letters,
    String center,
    Set<String> wordList,
  ) {
    final letterSet = letters.toSet();
    final result = <String>{};

    for (var word in wordList) {
      if (!word.contains(center)) continue;
      var ok = true;
      for (var char in word.runes.map((r) => String.fromCharCode(r))) {
        if (!letterSet.contains(char)) {
          ok = false;
          break;
        }
      }
      if (ok) result.add(word);
    }

    return result;
  }
}
