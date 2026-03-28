class Word {
  final String word;
  final String? wolofDef;
  final String? frenchDef;
  final String? stem;
  final List<int> idxWolofNjaay;
  final List<int> idxSolomon;

  Word({
    required this.word,
    this.wolofDef,
    this.frenchDef,
    this.stem,
    this.idxWolofNjaay = const [],
    this.idxSolomon = const [],
  });
}
