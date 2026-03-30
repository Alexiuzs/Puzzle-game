import 'dart:math';
import 'package:csv/csv.dart';
import 'package:flutter/services.dart';

// this is not the whole entry, but with a chosen proverb if available
class LexicalEntry {
  final String word;
  final String? wolofDef;
  final String? frenchDef;
  final String? stem;
  final String? wolofNjaay;
  final String? solomonProverb;
  final String? solomonRef;

  LexicalEntry({
    required this.word,
    this.wolofDef,
    this.frenchDef,
    this.stem,
    this.wolofNjaay,
    this.solomonProverb,
    this.solomonRef,
  });

  static Future<LexicalEntry> fromJson(Map<String, dynamic> json) async {
    String? wolofNjaay;
    String? solomonProverb;
    String? solomonRef;

    if (json['idxWolofNjaay'] != null) {
      final List<dynamic> list = json['idxWolofNjaay'] as List<dynamic>;
      if (list.isNotEmpty) {
        final random = Random();
        final wolofNjaayID = int.parse(
          list[random.nextInt(list.length)].toString(),
        );
        wolofNjaay = await getWolofNjaay(wolofNjaayID);
      }
    }
    if (json['idxSolomon'] != null) {
      final List<dynamic> list = json['idxSolomon'] as List<dynamic>;
      if (list.isNotEmpty) {
        final random = Random();
        final solomonID = int.parse(
          list[random.nextInt(list.length)].toString(),
        );
        final data = await getSolomonProverb(solomonID);

        solomonRef = data.key;
        solomonProverb = data.value;
      }
    }

    return LexicalEntry(
      word: json['word'] as String,
      wolofDef: json['wo'] as String?,
      frenchDef: json['fr'] as String?,
      stem: json['stem'] as String?,
      wolofNjaay: wolofNjaay,
      solomonProverb: solomonProverb,
      solomonRef: solomonRef,
    );
  }

  // no toJson because our data comes from elsewhere - this is just a convenience class
}

List<List<dynamic>>? _cachedSolomonProverbs;
List<String>? _cachedWolofNjaay;

Future<MapEntry<String, String>> getSolomonProverb(int id) async {
  if (_cachedSolomonProverbs == null) {
    final solomonData = await rootBundle.loadString('assets/data/solomon.csv');
    // Using default eol configuration for CsvToListConverter which dynamically handles \n and \r\n
    _cachedSolomonProverbs = csv.decode(solomonData);
  }

  if (_cachedSolomonProverbs != null &&
      id >= 0 &&
      id < _cachedSolomonProverbs!.length) {
    final row = _cachedSolomonProverbs![id];
    if (row.length >= 2) {
      return MapEntry(row[0].toString(), row[1].toString());
    }
  }
  return const MapEntry('', '');
}

Future<String> getWolofNjaay(int id) async {
  if (_cachedWolofNjaay == null) {
    final data = await rootBundle.loadString('assets/data/wolof_njaay.txt');
    _cachedWolofNjaay = data.split('\n');
  }

  if (_cachedWolofNjaay != null && id >= 0 && id < _cachedWolofNjaay!.length) {
    return _cachedWolofNjaay![id];
  }
  return '';
}
