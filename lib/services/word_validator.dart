import '../models/puzzle.dart';

class WordValidator {
  /// Returns true if [word] is valid for the current [puzzle] and exists in
  /// [dictionary]. The word is assumed to be already normalized (e.g. lowercased).
  static bool isValid(
    String word,
    Puzzle puzzle,
    Set<String> dictionary,
  ) {
    if (!dictionary.contains(word)) return false;

    if (!word.contains(puzzle.centerLetter)) return false;

    final allowed = puzzle.letters.toSet();
    for (var char in word.runes.map((r) => String.fromCharCode(r))) {
      if (!allowed.contains(char)) return false;
    }

    return true;
  }
}
