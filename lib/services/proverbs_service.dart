import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:crypto/crypto.dart';

// Top-level function so it can be passed to compute()
Map<String, dynamic> _parseIndexJson(String jsonString) {
  return json.decode(jsonString);
}

// Top-level function so it can be passed to compute()
List<String> _parseProverbs(String text) {
  return const LineSplitter().convert(text);
}

class ProverbsService {
  List<String> _proverbs = [];
  Map<String, List<int>> _index = {};
  bool _initialized = false;
  bool _hashMismatch = false;
  final _random = Random();

  bool get isInitialized => _initialized;
  bool get hasHashMismatch => _hashMismatch;

  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Load proverbs text file
      final proverbsString = await rootBundle.loadString(
        'assets/proverbs/proverbs.txt',
      );
      // Run string splitting in a background isolate
      _proverbs = await compute(_parseProverbs, proverbsString);

      // Load index json file
      final indexString = await rootBundle.loadString(
        'assets/proverbs/index.json',
      );

      final Map<String, dynamic> decodedData = _parseIndexJson(indexString);

      final String storedHash = decodedData['hash'] as String;
      final Map<String, dynamic> rawIndex =
          decodedData['index'] as Map<String, dynamic>;

      // Convert dynamic map to Map<String, List<int>>
      _index = rawIndex.map(
        (key, value) => MapEntry(key, List<int>.from(value)),
      );

      // Verify the MD5 hash
      final bytes = const Utf8Encoder().convert(proverbsString);
      final computedHash = md5.convert(bytes).toString();

      if (computedHash != storedHash) {
        _hashMismatch = true;
      }

      _initialized = true;
    } catch (e) {
      // If files aren't found or there is a parsing error, fail silently
      // and let getRandomProverb handle returning the default message.
      debugPrint('Error loading proverbs: $e');
    }
  }

  String getRandomProverb(String word) {
    if (!_initialized || _proverbs.isEmpty || _index.isEmpty) {
      return "Gisul lu ni mel.";
    }

    final lowerWord = word.toLowerCase();
    final lineIndexes = _index[lowerWord];

    if (lineIndexes == null || lineIndexes.isEmpty) {
      return "Gisul lu ni mel.";
    }

    final randomLineIndex = lineIndexes[_random.nextInt(lineIndexes.length)];

    // Ensure index is within bounds (index.json is 1-indexed for some reason based on analysis)
    // Actually wait, let's treat the index carefully.
    // Line numbers in text editors are 1-indexed. Let's subtract 1 to get 0-indexed list access.
    final listIndex = randomLineIndex - 1;

    if (listIndex >= 0 && listIndex < _proverbs.length) {
      return _proverbs[listIndex];
    }

    return "Gisul lu ni mel.";
  }
}
