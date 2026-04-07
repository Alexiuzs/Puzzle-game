import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/game_screen.dart';
import 'screens/username_screen.dart';
import 'theme_notifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final username = prefs.getString('username');
  runApp(MyApp(hasUsername: username != null && username.isNotEmpty));
}

class MyApp extends StatelessWidget {
  final bool hasUsername;
  const MyApp({super.key, required this.hasUsername});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PuzzleNotifier()),
        ChangeNotifierProvider(create: (_) => ThemeNotifier()),
      ],
      child: Consumer<ThemeNotifier>(
        builder: (context, theme, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Word Puzzle',
            themeMode: theme.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            home: hasUsername ? const GameScreen() : const UsernameScreen(),
          );
        },
      ),
    );
  }
}
