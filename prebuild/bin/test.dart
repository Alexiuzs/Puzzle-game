import 'package:prebuild/index_creator.dart' as index_creator;

void main(List<String> arguments) {
  print(arguments);
  if (arguments.isEmpty) {
    print(
      'No arguments provided\r\rUsage: dart run bin/prebuild.dart <wordlist|puzzles|all>',
    );
    // return;
  }

  index_creator.test();
}
