import 'package:prebuild/index_creator.dart' as index_creator;
import 'package:prebuild/puzzle_finder.dart' as puzzle_finder;

void main(List<String> arguments) {
  if (arguments.isEmpty ||
      (!arguments.contains('wordlist') &&
          !arguments.contains('puzzles') &&
          !arguments.contains('all'))) {
    print(
      'No arguments provided\r\rUsage: dart run bin/prebuild.dart <wordlist|puzzles|all>',
    );
    return;
  }

  bool createWordlist = false;
  bool createPuzzles = false;

  // plan

  if (arguments.contains('all')) {
    createWordlist = true;
    createPuzzles = true;
  }

  if (arguments.contains('wordlist')) {
    createWordlist = true;
  }

  if (arguments.contains('puzzles')) {
    createPuzzles = true;
  }

  // action

  if (createWordlist) {
    index_creator.createWordlist();
  }

  if (createPuzzles) {
    puzzle_finder.preCookPuzzles();
  }
}
