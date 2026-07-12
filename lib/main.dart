import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flame/game.dart';
import 'football_game.dart';

void main() async {
  // Ensure Flutter is ready before locking the screen sideways
  WidgetsFlutterBinding.ensureInitialized();
  
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: GameLauncher(),
  ));
}

class GameLauncher extends StatelessWidget {
  const GameLauncher({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(
        // We set default values here to get you straight into the action
        game: LANFootballGame(
          gameMode: GameMode.ai, 
          difficulty: Difficulty.normal,
          totalMatchDurationMinutes: 45,
        ),
      ),
    );
  }
}
