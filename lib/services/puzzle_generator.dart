import 'dart:math';

import '../models/puzzle.dart';

class PuzzleGenerator {
  /// Generate a daily puzzle based on [dateSeed]. The seed should typically
  /// be derived from the current date (e.g. `int.parse(DateFormat('yyyyMMdd').format(DateTime.now()))`).
  ///
  /// [alphabet] is the list of allowed characters. The generator picks seven
  /// distinct characters randomly from that list and then chooses one of them
  /// to be the center. It computes all valid words from [wordList] for that
  /// letter set.
  static Puzzle generateDaily(
    int dateSeed,
    List<String> alphabet,
    Set<String> wordList,
  ) {
    final rng = Random(dateSeed);

    // shuffle a copy to avoid mutating the original alphabet.
    final letters = List<String>.from(alphabet)..shuffle(rng);

    // pick first 7 unique letters; if alphabet has duplicates, ensure unique.
    final selected = <String>{};
    for (var l in letters) {
      if (selected.length >= 7) break;
      selected.add(l);
    }
    if (selected.length < 7) {
      throw Exception('Alphabet too small to select 7 unique letters');
    }

    final letterList = selected.toList();
    // choose a random index to be center
    final centerIndex = rng.nextInt(letterList.length);
    final center = letterList[centerIndex];

    final valid = _computeValidWords(letterList, center, wordList);

    return Puzzle(centerLetter: center, letters: letterList, validWords: valid);
  }

  /// Generates a completely random puzzle, ignoring the date, but guaranteeing
  /// that at least one valid word exists. This is used for the "refresh"
  /// feature where the user wants a fresh, playable puzzle.
  static Puzzle generateRandom(
    List<String> alphabet,
    Set<String> wordList,
  ) {
    final rng = Random();
    while (true) {
      // pick 7 distinct letters randomly
      final copy = List<String>.from(alphabet)..shuffle(rng);
      final selected = <String>{};
      for (var l in copy) {
        if (selected.length >= 7) break;
        selected.add(l);
      }
      if (selected.length < 7) {
        throw Exception('Alphabet too small to select 7 unique letters');
      }
      final letterList = selected.toList();
      final center = letterList[rng.nextInt(letterList.length)];
      final valid = _computeValidWords(letterList, center, wordList);
      if (valid.isNotEmpty) {
        return Puzzle(
            centerLetter: center, letters: letterList, validWords: valid);
      }
      // otherwise loop and try again
    }
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
