import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'football_game.dart';
import 'network_manager.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: FootballStadiumLobby(),
  ));
}

class FootballStadiumLobby extends StatefulWidget {
  const FootballStadiumLobby({super.key});

  @override
  State<FootballStadiumLobby> createState() => _FootballStadiumLobbyState();
}

class _FootballStadiumLobbyState extends State<FootballStadiumLobby> {
  GameMode _mode = GameMode.ai;
  Difficulty _difficulty = Difficulty.normal;
  int _minutes = 45;

  final _netManager = LANNetworkManager();
  final _ipController = TextEditingController();
  String _hostIP = "Detecting Wi-Fi Link...";
  bool _isPlaying = false;
  late LANFootballGame _game;

  @override
  void initState() {
    super.initState();
    _fetchIP();
  }

  void _fetchIP() async {
    String? ip = await _netManager.getWifiIP();
    setState(() => _hostIP = ip ?? "Wi-Fi Hotspot Interface Missing");
  }

  void _startMatch() {
    _game = LANFootballGame(
      gameMode: _mode,
      difficulty: _difficulty,
      totalMatchDurationMinutes: _minutes,
    );

    if (_mode == GameMode.lan) {
      _netManager.listenForPeerPackets((map) {
        _game.playerTwo.position.setValues(_game.size.x - map['px'], _game.size.y - map['py']);
        _game.ball.position.setValues(_game.size.x - map['bx'], _game.size.y - map['by']);
        if (map.containsKey('pKick')) _game.penaltyKickerDirection = map['pKick'];
        if (map.containsKey('pKeeper')) _game.penaltyKeeperDirection = map['pKeeper'];
      });

      Stream.periodic(const Duration(milliseconds: 25)).listen((_) {
        if (_isPlaying) {
          _netManager.transmitMatchDataPacket(_ipController.text.trim(), {
            'px': _game.playerOne.position.x,
            'py': _game.playerOne.position.y,
            'bx': _game.ball.position.x,
            'by': _game.ball.position.y,
          });
        }
      });
    }

    setState(() => _isPlaying = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_isPlaying) {
      return Scaffold(
        body: Stack(
          children: [
            GameWidget(game: _game),
            ValueListenableBuilder(
              valueListenable: ValueNotifier(_game.cardDisplayColor),
              builder: (context, Color color, _) {
                if (color == Colors.transparent) return const SizedBox.shrink();
                return Positioned.fill(
                  child: Container(
                    color: Colors.black54,
                    child: Center(
                      child: Card(
                        color: color,
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Text(_game.refereeMessage, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black)),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              bottom: 25,
              left: 15,
              right: 15,
              child: _game.matchState == MatchState.penaltySetup 
                ? _buildPenaltyShootoutControls()
                : _buildStandardMatchGameplayControls(),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0C2912),
      appBar: AppBar(title: const Text("PRO STADIUM MULTIPLAYER HUB"), backgroundColor: Colors.green.shade900),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(Icons.sports_soccer, size: 90, color: Colors.amber),
            const SizedBox(height: 20),
            DropdownButtonFormField<GameMode>(
              value: _mode,
              decoration: const InputDecoration(labelText: "Game Matching Profile Mode", filled: true),
              items: const [
                DropdownMenuItem(value: GameMode.ai, child: Text("VS ENGINE ARTIFICIAL BOT")),
                DropdownMenuItem(value: GameMode.lan, child: Text("CROSS-PLATFORM LOCAL LAN")),
              ],
              onChanged: (val) => setState(() => _mode = val!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _minutes,
              decoration: const InputDecoration(labelText: "Set Match Length Limit", filled: true),
              items: const [
                DropdownMenuItem(value: 45, child: Text("45 Minutes Standard Arc")),
                DropdownMenuItem(value: 90, child: Text("90 Minutes Extended Match")),
              ],
              onChanged: (val) => setState(() => _minutes = val!),
            ),
            if (_mode == GameMode.lan) ...[
              const SizedBox(height: 16),
              Text("Your Device Local Target IP: $_hostIP", style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 8),
              TextField(
                controller: _ipController,
                decoration: const InputDecoration(labelText: "Enter Friend's IP Address Connection Target", filled: true),
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, minimumSize: const Size(double.infinity, 52)),
              onPressed: _startMatch,
              child: const Text("KICK OFF MATCH 🚀", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStandardMatchGameplayControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onPanUpdate: (details) {
            _game.playerOne.position.add(Vector2(details.delta.dx, details.delta.dy) * 1.25);
          },
          child: const CircleAvatar(radius: 38, backgroundColor: Colors.white24, child: Icon(Icons.gamepad, color: Colors.white)),
        ),
        Row(
          children: [
            ElevatedButton(onPressed: () => _game.executePassAction(isLong: false), child: const Text("SHORT")),
            const SizedBox(width: 6),
            ElevatedButton(onPressed: () => _game.executePassAction(isLong: true), child: const Text("LONG")),
            const SizedBox(width: 6),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800),
              onPressed: _game.executeSlidingTackle, 
              child: const Text("TACKLE", style: TextStyle(color: Colors.white)),
            ),
          ],
        )
      ],
    );
  }

  Widget _buildPenaltyShootoutControls() {
    bool kicking = _game.playerOne.position.y > _game.size.y / 2;
    return Card(
      color: Colors.black87,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(kicking ? "CHOOSE WHERE TO SHOOT" : "FRIEND IS KICKING! DIRECT KEEPER DIVE", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {
                    if (kicking) _game.penaltyKickerDirection = -1; else _game.penaltyKeeperDirection = -1;
                    _game.resolvePenaltyShot();
                    setState(() {});
                  },
                  child: const Text("LEFT"),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (kicking) _game.penaltyKickerDirection = 0; else _game.penaltyKeeperDirection = 0;
                    _game.resolvePenaltyShot();
                    setState(() {});
                  },
                  child: const Text("CENTER"),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (kicking) _game.penaltyKickerDirection = 1; else _game.penaltyKeeperDirection = 1;
                    _game.resolvePenaltyShot();
                    setState(() {});
                  },
                  child: const Text("RIGHT"),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
