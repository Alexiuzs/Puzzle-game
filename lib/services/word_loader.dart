import 'package:flutter/services.dart';

class WordLoader {
  /// Loads a set of words from an asset file. Each line is treated as one word.
  ///
  /// The returned set is lowercase by default to simplify comparisons, but you
  /// can change that behaviour if your language is case-sensitive.
  static Future<Set<String>> loadFromAsset(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    final words = raw
        .split(RegExp(r"\r?\n"))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .map((l) => l.toLowerCase())
        .toSet();
    return words;
  }
}
