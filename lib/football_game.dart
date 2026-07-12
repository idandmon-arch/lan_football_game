import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flame/components.dart';
import 'package:flame/collisions.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'dart:math';

enum GameMode { ai, lan }
enum Difficulty { easy, normal, hard }
enum MatchState { regularPlay, penaltySetup, freeKickSetup, cornerSetup, goalReset, cardAnimation }

class LANFootballGame extends FlameGame with HasKeyboardHandlerComponents, HasCollisionDetection {
  final GameMode gameMode;
  final Difficulty difficulty;
  final int totalMatchDurationMinutes;

  LANFootballGame({
    required this.gameMode,
    required this.difficulty,
    required this.totalMatchDurationMinutes,
  });

  late Ball ball;
  late Player playerOne; 
  late Player playerTwo;
  
  MatchState matchState = MatchState.regularPlay;
  double matchTimerSeconds = 0;
  double halfDurationSeconds = 0;
  int homeScore = 0;
  int awayScore = 0;
  
  String refereeMessage = "";
  Color cardDisplayColor = Colors.transparent;
  int penaltyKickerDirection = 0; 
  int penaltyKeeperDirection = 0;

  @override
  Future<void> onLoad() async {
    super.onLoad();
    halfDurationSeconds = (totalMatchDurationMinutes * 60) / 2;

    // Pitch Background
    add(RectangleComponent(
      position: Vector2.zero(),
      size: size,
      paint: Paint()..color = const Color(0xFF1B5E20),
    ));

    // Center Line
    add(RectangleComponent(
      position: Vector2(0, size.y / 2 - 2),
      size: Vector2(size.x, 4),
      paint: Paint()..color = Colors.white54,
    ));

    resetFormations();
  }

  void resetFormations() {
    matchState = MatchState.regularPlay;
    if (componentsAtPoint(Vector2.zero()).isEmpty) {
      ball = Ball(position: Vector2(size.x / 2, size.y / 2));
      playerOne = Player(position: Vector2(size.x / 2, size.y * 0.75), color: Colors.blue, isLocal: true);
      playerTwo = Player(position: Vector2(size.x / 2, size.y * 0.25), color: Colors.red, isLocal: false);

      add(ball);
      add(playerOne);
      add(playerTwo);
    } else {
      ball.position.setValues(size.x / 2, size.y / 2);
      ball.velocity.setZero();
      playerOne.position.setValues(size.x / 2, size.y * 0.75);
      playerTwo.position.setValues(size.x / 2, size.y * 0.25);
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    
    // SAFETY LOCK: Prevents the engine from running AI logic before the ball is spawned
    if (!isLoaded) return; 

    if (matchState == MatchState.regularPlay) {
      // 6x speed multiplier for mobile pacing
      matchTimerSeconds += dt * 6;
      if (gameMode == GameMode.ai) {
        runAdvancedAIMovement(dt);
      }
      enforceSolidCircleCollisions();
      checkGoalScoringLines();
    }
  }

  void enforceSolidCircleCollisions() {
    double minDistance = playerOne.radius + playerTwo.radius;
    double currentDistance = playerOne.position.distanceTo(playerTwo.position);

    if (currentDistance < minDistance) {
      Vector2 collisionNormal = (playerOne.position - playerTwo.position).normalized();
      double overlap = minDistance - currentDistance;
      playerOne.position.add(collisionNormal * (overlap / 2));
      playerTwo.position.sub(collisionNormal * (overlap / 2));
    }
  }

  void runAdvancedAIMovement(double dt) {
    double speed = difficulty == Difficulty.easy ? 80 : difficulty == Difficulty.normal ? 140 : 220;
    Vector2 target = ball.position;

    if (difficulty == Difficulty.hard && playerTwo.position.distanceTo(playerOne.position) < 80) {
      if (Random().nextDouble() < 0.01) {
        triggerRefereeFoulCheck(isPlayerOneFoul: false);
        return;
      }
    }

    if ((target.x - playerTwo.position.x).abs() > 4) {
      playerTwo.position.x += (target.x > playerTwo.position.x ? 1 : -1) * speed * dt;
    }
    if ((target.y - playerTwo.position.y).abs() > 4 && playerTwo.position.y < size.y * 0.48) {
      playerTwo.position.y += (target.y > playerTwo.position.y ? 1 : -1) * speed * dt;
    }
  }

  void executePassAction({required bool isLong}) {
    Vector2 direction = (ball.position - playerOne.position).normalized();
    if (playerOne.position.distanceTo(ball.position) < 45) {
      double force = isLong ? 550.0 : 280.0;
      ball.velocity.setFrom(direction * force);
      try { FlameAudio.play('kick.mp3'); } catch (_) {}
    }
  }

  void executeSlidingTackle() {
    if (playerOne.position.distanceTo(playerTwo.position) < 60) {
      if (Random().nextDouble() > 0.6) {
        Vector2 force = (ball.position - playerOne.position).normalized()..scale(400);
        ball.velocity.setFrom(force);
      } else {
        triggerRefereeFoulCheck(isPlayerOneFoul: true);
      }
    }
  }

  void triggerRefereeFoulCheck({required bool isPlayerOneFoul}) {
    matchState = MatchState.cardAnimation;
    double roll = Random().nextDouble();
    
    if (roll < 0.4) {
      refereeMessage = "FOUL! Yellow Card Issued!";
      cardDisplayColor = Colors.yellow;
    } else if (roll < 0.7) {
      refereeMessage = "RED CARD! Direct Dismissal!";
      cardDisplayColor = Colors.red;
    } else {
      refereeMessage = "Foul Called! Play Paused.";
      cardDisplayColor = Colors.white;
    }

    Future.delayed(const Duration(seconds: 2), () {
      cardDisplayColor = Colors.transparent;
      double setupType = Random().nextDouble();
      
      if (setupType < 0.35) {
        matchState = MatchState.penaltySetup;
        ball.position.setValues(size.x / 2, isPlayerOneFoul ? size.y * 0.15 : size.y * 0.85);
      } else if (setupType < 0.7) {
        matchState = MatchState.freeKickSetup;
        ball.position.setValues(size.x / 2, size.y / 2);
      } else {
        matchState = MatchState.cornerSetup;
        ball.position.setValues(15, 15);
      }
    });
  }

  void resolvePenaltyShot() {
    matchState = MatchState.regularPlay;
    if (penaltyKickerDirection == penaltyKeeperDirection) {
      ball.velocity.setValues(0, size.y / 2);
    } else {
      if (penaltyKickerDirection < 0) ball.position.setValues(size.x * 0.3, 5);
      if (penaltyKickerDirection == 0) ball.position.setValues(size.x / 2, 5);
      if (penaltyKickerDirection > 0) ball.position.setValues(size.x * 0.7, 5);
    }
  }

  void checkGoalScoringLines() {
    if (ball.position.y <= 12) {
      homeScore++;
      try { FlameAudio.play('goal.mp3'); } catch (_) {}
      resetFormations();
    } else if (ball.position.y >= size.y - 12) {
      awayScore++;
      try { FlameAudio.play('goal.mp3'); } catch (_) {}
      resetFormations();
    }
  }
}

class Ball extends CircleComponent with HasGameRef<LANFootballGame>, CollisionCallbacks {
  Vector2 velocity = Vector2.zero();
  double friction = 0.982;

  Ball({required Vector2 position}) : super(radius: 11, position: position, anchor: Anchor.center) {
    paint = Paint()..color = Colors.white;
  }

  @override
  void update(double dt) {
    super.update(dt);
    position.add(velocity * dt);
    velocity.scale(friction);

    // Bounce off side walls
    if (position.x <= radius || position.x >= gameRef.size.x - radius) {
      velocity.x = -velocity.x * 0.75;
      position.x = position.x.clamp(radius, gameRef.size.x - radius);
    }
  }
}

class Player extends CircleComponent with CollisionCallbacks {
  final Color color;
  final bool isLocal;

  Player({required Vector2 position, required this.color, required this.isLocal})
      : super(radius: 19, position: position, anchor: Anchor.center) {
    paint = Paint()..color = color;
  }

  @override
  void onCollision(Set<Vector2> points, PositionComponent other) {
    super.onCollision(points, other);
    // Push the ball when touching it
    if (other is Ball) {
      Vector2 force = (other.position - position).normalized()..scale(260);
      other.velocity.setFrom(force);
    }
  }
}
