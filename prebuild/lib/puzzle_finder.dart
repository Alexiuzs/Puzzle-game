import 'dart:io';
import 'dart:convert';

Future<void> preCookPuzzles() async {
  List<String> words = [];
  final wolKyDefPath = '../assets/generated/wordlist.json';
  final wolKyFile = File(wolKyDefPath);
  if (!await wolKyFile.exists()) {
    print('File not found: $wolKyDefPath');
    return;
  }
  final rawWordlistData = await wolKyFile.readAsString();
  final wordObjects = json.decode(rawWordlistData);
  final wordlist = wordObjects['data'];

  // Only consider words containing valid lower-case letters
  // (including accented characters from a-z, and extended african letters ñ, ŋ, œ, ẽ).
  // This filters out spaces, commas, hyphens, english apostrophes, Arabic letters, etc.
  final validLettersRe = RegExp(r'^[a-zà-ÿñŋœẽ]+$');

  for (var wordObject in wordlist) {
    String word = wordObject['word'].toString().toLowerCase();
    if (word.length >= 3 && validLettersRe.hasMatch(word)) {
      words.add(word);
    }
  }

  // 1. Discover the alphabet dynamically based strictly on valid words!
  Set<String> uniqueChars = {};
  for (String word in words) {
    for (int i = 0; i < word.length; i++) {
      uniqueChars.add(word[i]);
    }
  }

  List<String> alphabet = uniqueChars.toList()..sort();
  print(
    'Discovered clean alphabet (${alphabet.length} letters): ${alphabet.join()}',
  );

  if (alphabet.length > 60) {
    print(
      'Warning: You have more than 60 distinct characters... The bitmask could fail.',
    );
  }

  // 2. Map word to bitmask.
  Map<int, List<String>> wordsByMask = {};
  for (String word in words) {
    int mask = getMask(word, alphabet);
    if (mask == -1) continue;
    int uniqueLettersCount = countBits(mask);

    if (uniqueLettersCount <= 7) {
      wordsByMask.putIfAbsent(mask, () => []).add(word);
    }
  }
  print(
    'Found ${wordsByMask.length} unique letter combinations from the word list.',
  );

  Stopwatch sw = Stopwatch()..start();

  // 3. For every 7-letter combination that naturally occurs in the dictionary (a pangram)
  // we use it as a puzzle base. NYT Spelling Bee puzzles always require at least one pangram!
  List<int> validPangramMasks = wordsByMask.keys
      .where((m) => countBits(m) == 7)
      .toList();
  print(
    'Found ${validPangramMasks.length} possible 7-letter sets (pangrams) to use as puzzle bases.',
  );

  List<Map<String, dynamic>> validPuzzles = [];

  for (int pMask in validPangramMasks) {
    // For this 7-letter set, gather ALL puzzle words that fit entirely inside it
    List<int> subsetWordMasks = [];
    for (int wMask in wordsByMask.keys) {
      if ((wMask & pMask) == wMask) {
        // If wMask is a subset of pMask
        subsetWordMasks.add(wMask);
      }
    }

    // Test each of the 7 letters as the required center letter
    for (int i = 0; i < alphabet.length; i++) {
      if ((pMask & (1 << i)) != 0) {
        int centerMask = 1 << i;
        List<String> puzzleWords = [];

        for (int wMask in subsetWordMasks) {
          if ((wMask & centerMask) != 0) {
            puzzleWords.addAll(wordsByMask[wMask]!);
          }
        }

        if (puzzleWords.length >= 20) {
          String centerLetter = alphabet[i];
          String otherLetters = '';
          for (int j = 0; j < alphabet.length; j++) {
            if (j != i && (pMask & (1 << j)) != 0) {
              otherLetters += alphabet[j];
            }
          }

          validPuzzles.add({
            'centerLetter': centerLetter,
            'otherLetters': otherLetters,
            'wordCount': puzzleWords.length,
            'words': puzzleWords,
          });
        }
      }
    }
  }

  // Randomize order of puzzles to eliminate repetitive puzzles
  validPuzzles.shuffle();

  print(
    'Yielded ${validPuzzles.length} playable puzzles with 20+ words in ${sw.elapsedMilliseconds}ms!',
  );

  // for each 365 puzzles, write a new file
  int chunkSize = 365;
  int filesWritten = 0;
  for (int i = 0; i < validPuzzles.length; i += chunkSize) {
    int end = (i + chunkSize < validPuzzles.length) ? i + chunkSize : validPuzzles.length;
    List<Map<String, dynamic>> chunk = validPuzzles.sublist(i, end);
    filesWritten++;
    final outputFile = File('../assets/generated/puzzles_$filesWritten.json');
    await outputFile.writeAsString(json.encode({'data': chunk}));
    print('Saved chunk $filesWritten to ${outputFile.path}');
  }
}

// Helpers
int getMask(String word, List<String> alphabet) {
  int mask = 0;
  for (int i = 0; i < word.length; i++) {
    int index = alphabet.indexOf(word[i]);
    if (index == -1) return -1;
    mask |= (1 << index);
  }
  return mask;
}

int countBits(int mask) {
  int count = 0;
  while (mask > 0) {
    if ((mask & 1) != 0) count++;
    // Dart bitwise operations work to 64-bits safely in native,
    // and up to 32 bits natively in JS. Unsigned shift is safer.
    mask >>>= 1;
  }
  return count;
}
