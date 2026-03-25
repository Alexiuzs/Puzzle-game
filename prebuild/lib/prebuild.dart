import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';

// 

// wolof proverbs 
// TODO index for Solomon Proverbs
void indexCreation() async {
  // Use absolute paths to be safe, or relative to the project root.
  // The prebuild package execution context might vary depending on how it's called.
  // But running `dart run prebuild/bin/generate_index.dart` from the project root will have `.` as the root.
  final proverbsPath = '../assets/proverbs/proverbs.txt';
  final indexPath = '../assets/proverbs/index.json';

  final file = File(proverbsPath);
  if (!await file.exists()) {
    print('File not found: $proverbsPath');
    return;
  }

  // Normalize string for consistent hashing
  final proverbsString = await file.readAsString();
  final normalizedProverbs = proverbsString.replaceAll('\r\n', '\n').trim();
  final bytes = const Utf8Encoder().convert(normalizedProverbs);
  final md5Hash = md5.convert(bytes).toString();

  final lines = proverbsString.split(RegExp(r'\r?\n'));
  final Map<String, List<int>> index = {};

  for (int i = 0; i < lines.length; i++) {
    final lineNum = i + 1;
    final text = lines[i];

    // Split the text into words based on the user's provided regex
    final words = text.toLowerCase().split(
      RegExp(r'[^\p{L}\p{N}]+', unicode: true),
    );

    for (var word in words) {
      if (word.isEmpty) continue;

      index.putIfAbsent(word, () => []);

      // Keep only unique line numbers
      if (index[word]!.isEmpty || index[word]!.last != lineNum) {
        index[word]!.add(lineNum);
      }
    }
  }

  final outFile = File(indexPath);
  // Ensure the directory exists
  if (!await outFile.parent.exists()) {
    await outFile.parent.create(recursive: true);
  }

  // Prepare final JSON structure
  final outputData = {'hash': md5Hash, 'index': index};

  // Convert to JSON with nice formatting (optional, but requested format seemed standard)
  final encoder = JsonEncoder.withIndent('  ');
  await outFile.writeAsString(encoder.convert(outputData));
  print('Successfully processed ${lines.length} lines.');
  print('Hash: $md5Hash');
  print('Index saved to ${outFile.path}');
}






void preCookPuzzles() {
  print('preCookPuzzles');
}
