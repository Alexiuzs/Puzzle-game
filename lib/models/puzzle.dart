class Puzzle {
  final String centerLetter;
  final List<String> letters; // includes center and outer letters
  final Set<String> validWords;

  Puzzle({
    required this.centerLetter,
    required this.letters,
    required this.validWords,
  });

  int get totalWords => validWords.length;
}
