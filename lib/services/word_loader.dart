import 'package:flutter/services.dart';
import 'dart:convert';

class WordLoader {
  /// Loads a set of words from an asset file. Each line is treated as one word.
  ///
  /// The returned set is lowercase by default to simplify comparisons, but you
  /// can change that behaviour if your language is case-sensitive.
  static Future<Set<String>> loadFromAsset(String assetPath) async {
    final raw = await rootBundle.loadString(assetPath);
    final objects = json.decode(raw);
    final wordlist = objects['data'];
    final words = wordlist.map((e) => e['word']).toSet();
    return words;
  }
}
