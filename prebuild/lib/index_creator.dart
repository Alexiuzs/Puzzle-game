// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:csv/csv.dart';

void test() {
  print('this is the exampled');
}

// wolof proverbs
void createWordlist() async {
  // existing wordlists
  // from wolKYG Paratext project
  final wolKyDefPath = '../assets/wolKYG.csv';
  final wolKyFile = File(wolKyDefPath);
  if (!await wolKyFile.exists()) {
    print('File not found: $wolKyDefPath');
    return;
  }
  final List<List<dynamic>> rows = await wolKyFile
      .openRead()
      .transform(utf8.decoder)
      .transform(csv.decoder)
      .toList();

  // Alex AI created and other sources
  final otherDefPath = '../assets/definitions.csv';
  final otherFile = File(otherDefPath);
  if (!await otherFile.exists()) {
    print('File not found: $otherDefPath');
    return;
  }

  // post wolKYG from translation team
  final translatorDefPath = '../assets/translator.csv';
  final translatorFile = File(translatorDefPath);
  if (!await translatorFile.exists()) {
    print('File not found: $translatorDefPath');
    return;
  }

  // suffix list
  final suffixPath = '../assets/suffix_list.csv';
  final suffixFile = File(suffixPath);
  if (!await suffixFile.exists()) {
    print('File not found: $suffixPath');
    return;
  }

  // proverbs
  final wolofNjaayPath = '../assets/proverbs/wolof_njaay.txt';
  final wolofNjaayFile = File(wolofNjaayPath);
  if (!await wolofNjaayFile.exists()) {
    print('File not found: $wolofNjaayPath');
    return;
  }

  final solomonPath = '../assets/proverbs/solomon.csv';
  final solomonFile = File(solomonPath);
  if (!await solomonFile.exists()) {
    print('File not found: $solomonPath');
    return;
  }

  // to be generated
  final wordlistPath = '../assets/generated/wordlist.json';
  final hashPath = '../assets/generated/hash.json';

  final wolofNjaayString = await wolofNjaayFile.readAsString();

  final lines = wolofNjaayString.split(RegExp(r'\r?\n'));
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

  final outFile = File(wordlistPath);
  // Ensure the directory exists
  if (!await outFile.parent.exists()) {
    await outFile.parent.create(recursive: true);
  }

  // Prepare final JSON structure
  final outputData = {'index': index};

  // Convert to JSON with nice formatting (optional, but requested format seemed standard)
  final encoder = JsonEncoder.withIndent('  ');
  await outFile.writeAsString(encoder.convert(outputData));
  print('Successfully processed ${lines.length} lines.');
  print('Index saved to ${outFile.path}');

  // hash
  final bytes = const Utf8Encoder().convert(wolofNjaayString);
  final md5Hash = md5.convert(bytes).toString();

  final hashFile = File(hashPath);
  // Ensure the directory exists
  if (!await hashFile.parent.exists()) {
    await hashFile.parent.create(recursive: true);
  }

  // Prepare final JSON structure
  final hashData = {'hash': md5Hash};

  // Convert to JSON with nice formatting (optional, but requested format seemed standard)
  final hashEncoder = JsonEncoder.withIndent('  ');
  await hashFile.writeAsString(hashEncoder.convert(hashData));
  print('Hash saved to ${hashFile.path}');
}
