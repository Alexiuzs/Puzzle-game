import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:confetti/confetti.dart';

import '../models/puzzle.dart';
import '../widgets/letter_wheel.dart';
import '../widgets/word_list.dart';
import '../widgets/shake_widget.dart';
import '../theme_notifier.dart';
import '../providers/puzzle_notifier.dart';

enum SubmitResult { success, alreadyFound, invalid }

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  GameScreenState createState() => GameScreenState();
}

class GameScreenState extends State<GameScreen> {
  late TextEditingController _controller;
  late PuzzleNotifier _notifier;
  String _message = '';
  String _wologramBanner = '';
  final GlobalKey<ShakeWidgetState> _shakeKey = GlobalKey<ShakeWidgetState>();
  late ConfettiController _confettiController;

  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 1),
    );
    _notifier = context.read<PuzzleNotifier>();
    // fire off initialization and store the future
    _initFuture = _notifier.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.sizeOf(context);

    bool wideScreen = size.width > 600 ? true : false;

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: Consumer<PuzzleNotifier>(
          builder: (context, notifier, _) {
            return PopupMenuButton<String>(
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [Text('Wolofle'), Icon(Icons.arrow_drop_down)],
              ),
              onSelected: (value) async {
                if (value == 'share') {
                  final text = notifier.generateShareText();
                  await Clipboard.setData(ClipboardData(text: text));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Copied results to clipboard!'),
                    ),
                  );
                } else if (value == 'theme') {
                  context.read<ThemeNotifier>().toggleTheme(
                    !context.read<ThemeNotifier>().isDarkMode,
                  );
                } else if (value.startsWith('diff_')) {
                  final diffStr = value.split('_')[1];
                  final diff = PuzzleDifficulty.values.firstWhere(
                    (e) => e.toString().split('.').last == diffStr,
                  );
                  notifier.setDifficulty(diff);
                  setState(() => _message = '');
                  _controller.clear();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'share',
                  child: ListTile(
                    leading: Icon(Icons.share),
                    title: Text('Séedoo ko (Share)'),
                  ),
                ),
                PopupMenuItem(
                  value: 'theme',
                  child: ListTile(
                    leading: Icon(
                      Theme.of(context).brightness == Brightness.dark
                          ? Icons.light_mode
                          : Icons.dark_mode,
                    ),
                    title: Text(
                      Theme.of(context).brightness == Brightness.dark
                          ? 'Melo bu woyof (Light Mode)'
                          : 'Melo bu lëndëm (Dark Mode)',
                    ),
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  enabled: false,
                  child: Text(
                    'Difficulties',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                PopupMenuItem(
                  enabled: false,
                  child: Text(
                    'Baat yi (Total words): ${notifier.totalPossible}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.amber,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                CheckedPopupMenuItem(
                  value: 'diff_easy',
                  checked: notifier.difficulty == PuzzleDifficulty.easy,
                  child: const Text('Yomb na (Easy)'),
                ),
                CheckedPopupMenuItem(
                  value: 'diff_medium',
                  checked: notifier.difficulty == PuzzleDifficulty.medium,
                  child: const Text('Yëm na (Medium)'),
                ),
                CheckedPopupMenuItem(
                  value: 'diff_hard',
                  checked: notifier.difficulty == PuzzleDifficulty.hard,
                  child: const Text('Jafe na (Hard)'),
                ),
              ],
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Choose date',
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _notifier.currentDate,
                firstDate: DateTime(2024),
                lastDate: DateTime.now(),
              );
              if (picked != null) {
                await _notifier.setPuzzleDate(picked);
                setState(() {
                  _message = '';
                  _controller.clear();
                });
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          return Consumer<PuzzleNotifier>(
            builder: (context, notifier, _) {
              final puzzle = notifier.puzzle;
              if (puzzle == null) {
                // return const Center(child: CircularProgressIndicator());
                return Center(child: Text('No puzzle found for this date'));
              }
              List<String> acceptedLetters = [];
              acceptedLetters.addAll(puzzle.letters);
              acceptedLetters.add(puzzle.centerLetter);

              Widget wheel = LetterWheel(
                puzzle: puzzle,
                onLetterTap: (l) {
                  if (!acceptedLetters.contains(l)) return;

                  _controller.text += l;
                  setState(() {});
                },
                onShuffle: notifier.shuffleOuter,
              );
              List<Widget> input = [
                Row(
                  children: [
                    Expanded(
                      child: ShakeWidget(
                        key: _shakeKey,
                        // version where the text is only changeable from the wheel
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _controller.text,
                            textAlign: .center,

                            style: Theme.of(context).textTheme.displayMedium,
                          ),
                        ),

                        // original version
                        // TextField(
                        //   controller: _controller,
                        //   decoration: const InputDecoration(
                        //     labelText: 'Bindal fii...',
                        //   ),
                        //   onSubmitted: (_) {
                        //     _handleSubmit();
                        //   },
                        // ),
                      ),
                    ),
                    SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _handleSubmit,
                      child: const Text('Yónni ko'),
                    ),
                  ],
                ),
                if (_message.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _message,
                      style: TextStyle(
                        color: _message.startsWith('Baax na')
                            ? Colors.green
                            : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Baax na ( ${notifier.foundWords.length} / ${notifier.totalPossible} )',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Expanded(
                              child: WordList(words: notifier.foundWords),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Baaxul',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Expanded(
                              child: WordList(words: notifier.triedWords),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ];

              return Stack(
                alignment: Alignment.topCenter,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: wideScreen
                        ? Row(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 16.0),
                                  child: wheel,
                                ),
                              ),
                              const SizedBox(width: 16),
                              SizedBox(
                                width: min(size.width / 2, 250),
                                child: Column(children: input),
                              ),
                            ],
                          )
                        : Column(
                            children: [
                              wheel,
                              const SizedBox(height: 16),
                              Expanded(child: Column(children: input)),
                            ],
                          ),
                  ),
                  if (_wologramBanner.isNotEmpty)
                    Positioned(
                      top: 50,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 10,
                              color: Colors.black.withAlpha(122),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'WOLOGRAM!',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              _wologramBanner.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.black,
                              ),
                            ),
                            const Text(
                              '+10 POINTS BONUS!',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ConfettiWidget(
                    confettiController: _confettiController,
                    blastDirection: -pi / 2, // upwards
                    emissionFrequency: 0.05,
                    numberOfParticles: 20,
                    maxBlastForce: 20,
                    minBlastForce: 10,
                    gravity: 0.3,
                    colors: const [
                      Colors.green,
                      Colors.blue,
                      Colors.pink,
                      Colors.orange,
                      Colors.purple,
                      Colors.amber,
                    ],
                  ),
                  // Reveal all possible words - shown when running in debug mode only
                  if (kDebugMode)
                    Positioned(
                      bottom: 16,
                      right: 16,
                      child: IconButton.filledTonal(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) {
                              List<Widget> wordsWidgets = [];
                              Set<String>? wordsSet =
                                  notifier.puzzle?.validWords;
                              if (wordsSet != null && wordsSet.isNotEmpty) {
                                for (String word in wordsSet) {
                                  wordsWidgets.add(Text(word));
                                }
                              }

                              return AlertDialog(
                                title: const Text('Jàpple ma!'),
                                content: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: wordsWidgets,
                                  ),
                                ),
                                actions: [
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Close'),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                        icon: Icon(Icons.help),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _handleSubmit() async {
    final result = _notifier.submit(_controller.text);

    // Trigger haptics and animations based on the result
    if (result == SubmitResult.success) {
      final isWolo = _notifier.isWologram(
        _controller.text.trim().toLowerCase(),
      );
      _confettiController.play();

      if (isWolo) {
        // Wologram Celebration
        await Haptics.vibrate(HapticsType.heavy);
        setState(() {
          _wologramBanner = _controller.text.trim();
        });
        Timer(const Duration(seconds: 4), () {
          if (mounted) setState(() => _wologramBanner = '');
        });
      } else {
        final wordLength = _controller.text.trim().length;
        if (wordLength >= 7) {
          await Haptics.vibrate(HapticsType.heavy);
        } else {
          await Haptics.vibrate(HapticsType.success);
        }
      }
    } else if (result == SubmitResult.invalid) {
      await Haptics.vibrate(HapticsType.error);
      _shakeKey.currentState?.shake();
    } else if (result == SubmitResult.alreadyFound) {
      await Haptics.vibrate(HapticsType.warning);
      _shakeKey.currentState?.shake();
    }

    setState(() {
      if (result == SubmitResult.success) {
        _message = 'Baax na!';
      } else if (result == SubmitResult.alreadyFound) {
        _message = 'Baax na (Ba pare)';
      } else {
        _message = 'Baaxul';
      }
    });
    _controller.clear();
  }
}
