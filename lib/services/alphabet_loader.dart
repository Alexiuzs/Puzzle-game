import 'package:flutter/services.dart';

class AlphabetLoader {
  /// Loads a list of characters/letters from an asset file.
  ///
  /// Each line in the file should contain a single character or grapheme.
  /// Blank lines are ignored. The returned list preserves the order found in
  /// the file.
  static Future<List<String>> loadFromAsset(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    final lines = raw
        .split(RegExp(r"\r?\n"))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    return lines;
  }
}
