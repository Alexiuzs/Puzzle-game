// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:csv/csv.dart';

// current working dir is prebuild running from flutter pub run prebuild:test

void test() async {
  print('this is the example');
  final wolKyDefPath = '../assets/data/wolKYG.csv';
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
  print(rows.first);
}

// Create a master wordlist from multiple sources
void createWordlist() async {
  print('beginning wordlist creation');
  // existing wordlists
  // from wolKYG Paratext project
  final wolKyDefPath = '../assets/data/wolKYG.csv';
  final wolKyFile = File(wolKyDefPath);
  if (!await wolKyFile.exists()) {
    print('File not found: $wolKyDefPath');
    return;
  }
  final List<List<dynamic>> wolKyDefs = await wolKyFile
      .openRead()
      .transform(utf8.decoder)
      .transform(csv.decoder)
      .toList();

  // Alex file - AI created and other sources
  final otherDefPath = '../assets/data/definitions.csv';
  final otherFile = File(otherDefPath);
  if (!await otherFile.exists()) {
    print('File not found: $otherDefPath');
    return;
  }
  final List<List<dynamic>> otherDefs = await otherFile
      .openRead()
      .transform(utf8.decoder)
      .transform(csv.decoder)
      .toList();

  // post wolKYG definitions from translation team
  final translatorDefPath = '../assets/data/translator.csv';
  final translatorFile = File(translatorDefPath);
  if (!await translatorFile.exists()) {
    print('File not found: $translatorDefPath');
    return;
  }
  final List<List<dynamic>> translatorDefs = await translatorFile
      .openRead()
      .transform(utf8.decoder)
      .transform(csv.decoder)
      .toList();

  // suffix list
  final suffixPath = '../assets/data/suffix_list.txt';
  final suffixFile = File(suffixPath);
  if (!await suffixFile.exists()) {
    print('File not found: $suffixPath');
    return;
  }
  final List<String> suffixes = await suffixFile.readAsLines();

  // proverbs
  final wolofNjaayPath = '../assets/data/wolof_njaay.txt';
  final wolofNjaayFile = File(wolofNjaayPath);
  if (!await wolofNjaayFile.exists()) {
    print('File not found: $wolofNjaayPath');
    return;
  }
  final List<String> wolofNjaayProverbs = await wolofNjaayFile.readAsLines();

  final solomonPath = '../assets/data/solomon.csv';
  final solomonFile = File(solomonPath);
  if (!await solomonFile.exists()) {
    print('File not found: $solomonPath');
    return;
  }
  final List<List<dynamic>> solomonProverbs = await solomonFile
      .openRead()
      .transform(utf8.decoder)
      .transform(csv.decoder)
      .toList();

  // to be generated
  final wordlistPath = '../assets/generated/wordlist.json';
  final hashPath = '../assets/generated/hash.json';

  print(
    'Data in memory, proceeding to assemble...\n...first creating wordlist...',
  );

  final Map<String, Map<String, dynamic>> wordData = {};

  // clean word whitespace etc and make lowercase
  String cleanWord(String value) =>
      value.replaceAll('\uFEFF', '').trim().toLowerCase();

  // Priority 1: wolKyDefs
  for (final row in wolKyDefs) {
    if (row.isEmpty || row[0] == null) continue;

    String w = cleanWord(row[0].toString());
    if (w.length < 3 || int.tryParse(w) != null) continue;
    wordData[w] = {
      'word': w,
      'wo': row.length > 1 ? row[1].toString().trim() : '',
      'fr': '',
    };
  }

  // Priority 2: translatorDefs (don't overwrite existing words)
  for (final row in translatorDefs) {
    if (row.isEmpty || row[0] == null) continue;
    String w = cleanWord(row[0].toString());
    if (w.length < 3 || int.tryParse(w) != null) continue;
    if (!wordData.containsKey(w)) {
      wordData[w] = {
        'word': w,
        'wo': row.length > 1 ? row[1].toString().trim() : '',
        'fr': '',
      };
    }
  }

  // Priority 3: otherDefs (don't overwrite existing words)
  for (final row in otherDefs) {
    if (row.isEmpty || row[0] == null) continue;
    String w = cleanWord(row[0].toString());
    if (w.length < 3 || int.tryParse(w) != null) continue;
    if (!wordData.containsKey(w)) {
      wordData[w] = {
        'word': w,
        'wo': row.length > 1 ? row[1].toString().trim() : '',
        'fr': '',
      };
    }
  }

  // Add words from Wolof proverbs
  for (final text in wolofNjaayProverbs) {
    final words = text.toLowerCase().split(
      RegExp(r'[^\p{L}\p{N}]+', unicode: true),
    );
    for (var w in words) {
      if (w.length < 3 || int.tryParse(w) != null) continue;
      if (!wordData.containsKey(w)) {
        wordData[w] = {'word': w, 'wo': '', 'fr': ''};
      }
    }
  }

  // Add words from Solomon proverbs
  for (final row in solomonProverbs) {
    if (row.length > 1) {
      // assuming text is at index 1
      final text = row[1].toString();
      final words = text.toLowerCase().split(
        RegExp(r'[^\p{L}\p{N}]+', unicode: true),
      );
      for (var w in words) {
        if (w.length < 3 || int.tryParse(w) != null) continue;
        if (!wordData.containsKey(w)) {
          wordData[w] = {'word': w, 'wo': '', 'fr': ''};
        }
      }
    }
  }

  // Handle Suffixes -> stems
  var sortedSuffixes = suffixes
      .map((s) => s.replaceAll('\uFEFF', '').trim())
      .where((s) => s.isNotEmpty)
      .toList();
  // Sort by length descending so we match the longest suffix first
  sortedSuffixes.sort((a, b) => b.length.compareTo(a.length));

  // go back through and try to guess stems
  for (var entry in wordData.values) {
    String w = entry['word'];
    String stem = w;
    for (var suffix in sortedSuffixes) {
      if (w.endsWith(suffix) && w != suffix) {
        stem = w.substring(0, w.length - suffix.length);
        break;
      }
    }
    entry['stem'] = stem;
  }

  print('Creating indices from proverbs...');

  Map<String, List<int>> wolofIndex = {};
  for (int i = 0; i < wolofNjaayProverbs.length; i++) {
    final lineNum = i + 1;
    final text = wolofNjaayProverbs[i];
    final words = text.toLowerCase().split(
      RegExp(r'[^\p{L}\p{N}]+', unicode: true),
    );
    for (var w in words) {
      wolofIndex.putIfAbsent(w, () => []);
      if (wolofIndex[w]!.isEmpty || wolofIndex[w]!.last != lineNum) {
        wolofIndex[w]!.add(lineNum);
      }
    }
  }

  Map<String, List<int>> solomonIndex = {};
  for (int i = 0; i < solomonProverbs.length; i++) {
    final lineNum = i + 1;
    if (solomonProverbs[i].length > 1) {
      final text = solomonProverbs[i][1].toString();
      final words = text.toLowerCase().split(
        RegExp(r'[^\p{L}\p{N}]+', unicode: true),
      );
      for (var w in words) {
        solomonIndex.putIfAbsent(w, () => []);
        if (solomonIndex[w]!.isEmpty || solomonIndex[w]!.last != lineNum) {
          solomonIndex[w]!.add(lineNum);
        }
      }
    }
  }

  for (var entry in wordData.values) {
    String w = entry['word'];
    entry['idxWolofNjaay'] = wolofIndex[w] ?? <int>[];
    entry['idxSolomon'] = solomonIndex[w] ?? <int>[];
  }

  print('Creating output file...');

  Map<String, Object> outputMapper(List<Map<String, dynamic>> data) {
    return {'_comment': 'Generated file — do not edit.', 'data': data};
  }

  final outFile = File(wordlistPath);
  if (!await outFile.parent.exists()) {
    await outFile.parent.create(recursive: true);
  }

  final outputList = wordData.values.toList();
  outputList.sort((a, b) => a['word'].compareTo(b['word']));

  final encoder = JsonEncoder.withIndent('  ');
  final outputMap = outputMapper(outputList);
  final jsonString = encoder.convert(outputMap);
  await outFile.writeAsString(jsonString);
  print('Successfully generated wordlist with ${outputList.length} words.');
  print('Wordlist saved to ${outFile.path}');

  // Hash
  print('Computing hash of source files...');
  final dataDir = Directory('../assets/data');
  final dataFiles = dataDir
      .listSync()
      .whereType<File>()
      .where((f) => !f.path.endsWith('.DS_Store'))
      .toList();

  // Sort alphabetically by filename
  dataFiles.sort(
    (a, b) => a.uri.pathSegments.last.compareTo(b.uri.pathSegments.last),
  );

  final List<int> allBytes = [];
  for (var f in dataFiles) {
    allBytes.addAll(await f.readAsBytes());
  }
  final md5Hash = md5.convert(allBytes).toString();

  final hashFile = File(hashPath);
  if (!await hashFile.parent.exists()) {
    await hashFile.parent.create(recursive: true);
  }

  final hashData = [
    {'hash': md5Hash, 'date': DateTime.now().toIso8601String()},
  ];
  final hashMap = outputMapper(hashData);

  await hashFile.writeAsString(encoder.convert(hashMap));
  print('Hash saved to ${hashFile.path}');
}


// String example = '''
// {
//   "word": 'aada',
//   "wo": "Li ñu bokk ci sunu xeet ak sunu melokan (Tradition/Custom).",
//   "fr": "",
//   "stem": "aada",
//   "idxWolofNjaay": [1, 2, 3],
//   "idxSolomon": [4, 5, 6]
// }
// ''';