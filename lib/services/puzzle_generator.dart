import 'dart:math';
import 'package:flutter/foundation.dart';

import '../models/puzzle.dart';

class PuzzleGenerator {
  /// Generate a daily puzzle based on [dateSeed].
  static Future<Puzzle> generateDaily(
    int dateSeed,
    List<String> alphabet,
    Set<String> wordList,
  ) {
    // Multiply date by a large prime so each date has its own
    // non-overlapping seed sequence. Two dates that are 1 apart
    // (e.g. 20260312 vs 20260313) produce seeds ~100 000 apart,
    // so their "retry" sequences never collide.
    var attempt = 0;
    while (true) {
      final seed = dateSeed * 100003 + attempt;
      final rng = Random(seed);
      final shuffledAlphabet = List<String>.from(alphabet)..shuffle(rng);

      final selected = <String>{};
      for (var l in shuffledAlphabet) {
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
        // 2. Must have at least 50 words
        if (valid.length >= 50 && _hasWologram(valid, letterList)) {
          return Puzzle(
            centerLetter: center,
            letters: letterList,
            validWords: valid,
          );
        }
      }
      attempt++;
    }
  }

  /// Keep generateRandom for internal tests or "any" mode if needed, 
  /// but updated to 50+ words rule.
  static Puzzle generateRandom(
    List<String> alphabet,
    Set<String> wordList,
  ) {
    final rng = Random();
    while (true) {
      final copy = List<String>.from(alphabet)..shuffle(rng);
      final selected = <String>{};
      for (var l in copy) {
        if (selected.length >= 7) break;
        selected.add(l);
      }
      final letterList = selected.toList();
      if (!_isValidLetterSet(letterList)) continue;

      final center = letterList[rng.nextInt(letterList.length)];
      final valid = _computeValidWords(letterList, center, wordList);
      
      if (valid.length >= 50 && _hasWologram(valid, letterList)) {
        return Puzzle(centerLetter: center, letters: letterList, validWords: valid);
      }
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
