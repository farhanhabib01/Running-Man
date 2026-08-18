import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const GameScreen(),
    );
  }
}

enum ItemType { coin, car, barricade, bush }

class FallingItem {
  int lane;
  double y;
  ItemType type;
  String? carImage;

  FallingItem({
    required this.lane,
    required this.y,
    required this.type,
    this.carImage,
  });
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  static const int laneCount = 3;

  int playerLane = 1;
  double playerY = 0.7;

  int policeLane = 1;
  double policeY = 0.9;
  int policeLaneDelayCounter = 0;

  List<FallingItem> items = [];

  double speed = 0.010;

  int score = 0;
  int highestScore = 0;

  bool isGameOver = false;
  bool isArrested = false;

  Timer? gameTimer;

  final Random random = Random();

  int tickCounter = 0;

  double roadOffset = 0;

  int nextSpawnTick = 35;

  double dragStartX = 0;

  @override
  void initState() {
    super.initState();
    startGame();
  }

  void startGame() {
    gameTimer?.cancel();

    items.clear();

    score = 0;
    speed = 0.010;

    playerLane = 1;

    policeLane = 1;
    policeY = 0.9;
    policeLaneDelayCounter = 0;

    isGameOver = false;
    isArrested = false;

    tickCounter = 0;
    roadOffset = 0;

    nextSpawnTick = 35;

    gameTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      updateGame();
    });
  }

  void updateGame() {
    if (isGameOver) return;

    setState(() {
      tickCounter++;

      roadOffset += speed * 800;

      if (roadOffset > 80) {
        roadOffset = 0;
      }

      // Police chase logic
      policeLaneDelayCounter++;

      if (policeLaneDelayCounter > 15) {
        policeLaneDelayCounter = 0;

        if (policeLane < playerLane) {
          policeLane++;
        } else if (policeLane > playerLane) {
          policeLane--;
        }
      }

      double targetPoliceY = playerY + 0.13;

      policeY += (targetPoliceY - policeY) * 0.1;

      if (policeLane == playerLane && policeY - playerY < 0.09 && !isArrested) {
        gameOver();
        return;
      }

      // ==========================================
      // SPEED PROGRESS
      // ==========================================

      double speedProgress = ((speed - 0.010) / (0.038 - 0.010)).clamp(
        0.0,
        1.0,
      );

      // ==========================================
      // SPAWN ITEMS
      // ==========================================

      if (tickCounter >= nextSpawnTick) {
        // Number of items increases gradually
        int itemCount;

        if (speedProgress < 0.25) {
          itemCount = 1;
        } else if (speedProgress < 0.55) {
          itemCount = 2;
        } else if (speedProgress < 0.80) {
          itemCount = 2;
        } else {
          itemCount = 3;
        }

        // Prevent all three lanes from being blocked
        // by dangerous hurdles at the same time.
        List<int> usedLanes = [];

        for (int i = 0; i < itemCount; i++) {
          int lane;

          do {
            lane = random.nextInt(laneCount);
          } while (usedLanes.contains(lane) && usedLanes.length < laneCount);

          usedLanes.add(lane);

          double chance = random.nextDouble();

          // Car probability gradually increases
          double carChance = (0.25 + (speed - 0.010) * 6).clamp(0.25, 0.45);

          // Coin probability also increases
          double coinChance = 0.40 + (speedProgress * 0.12);

          // Keep total probability safe
          if (coinChance > 0.52) {
            coinChance = 0.52;
          }

          ItemType type;

          if (chance < coinChance) {
            type = ItemType.coin;
          } else if (chance < coinChance + carChance) {
            type = ItemType.car;
          } else if (chance < coinChance + carChance + 0.15) {
            type = ItemType.barricade;
          } else {
            type = ItemType.bush;
          }

          String? carImg;

          if (type == ItemType.car) {
            carImg = random.nextBool()
                ? 'assets/game/car1.jpg'
                : 'assets/game/car2.png';
          }

          // Slight horizontal timing difference
          // between multiple items.
          double spawnY = -0.18 - (i * 0.08);

          items.add(
            FallingItem(lane: lane, y: spawnY, type: type, carImage: carImg),
          );
        }

        // ==========================================
        // HURDLE FREQUENCY INCREASES WITH SPEED
        // ==========================================

        int baseGap = (48 - (speedProgress * 24)).round();

        if (baseGap < 20) {
          baseGap = 20;
        }

        int randomVariance = random.nextInt(10);

        nextSpawnTick = tickCounter + baseGap + randomVariance;
      }

      // ==========================================
      // MOVE ITEMS
      // ==========================================

      for (var item in items) {
        item.y += speed;
      }

      // ==========================================
      // COLLISION
      // ==========================================

      for (var item in List<FallingItem>.from(items)) {
        if (item.lane == playerLane &&
            item.y > playerY - 0.06 &&
            item.y < playerY + 0.06) {
          if (item.type == ItemType.coin) {
            score += 10;
            items.remove(item);
          } else {
            arrestPlayer();
            return;
          }
        }
      }

      items.removeWhere((item) => item.y > 1.1);

      // ==========================================
      // GRADUAL SPEED INCREASE
      // ==========================================

      if (tickCounter % 120 == 0) {
        speed += 0.0015;

        if (speed > 0.038) {
          speed = 0.038;
        }
      }

      // ==========================================
      // SCORE
      // ==========================================

      if (tickCounter % 15 == 0) {
        score += 1;
      }

      // Highest score
      if (score > highestScore) {
        highestScore = score;
      }
    });
  }

  void arrestPlayer() {
    isArrested = true;

    policeLane = playerLane;
    policeY = playerY + 0.02;

    gameOver();
  }

  void gameOver() {
    isGameOver = true;

    if (score > highestScore) {
      highestScore = score;
    }

    gameTimer?.cancel();
  }

  // ==========================================
  // TOUCH / SWIPE CONTROLS
  // ==========================================

  void handleSwipe(double difference) {
    const double swipeThreshold = 25;

    if (difference.abs() < swipeThreshold) {
      return;
    }

    if (difference > 0) {
      moveRight();
    } else {
      moveLeft();
    }
  }

  void moveLeft() {
    if (!isGameOver && playerLane > 0) {
      setState(() {
        playerLane--;
      });
    }
  }

  void moveRight() {
    if (!isGameOver && playerLane < laneCount - 1) {
      setState(() {
        playerLane++;
      });
    }
  }

  void restartGame() {
    setState(() {
      startGame();
    });
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    super.dispose();
  }

  Widget buildItemWidget(FallingItem item) {
    switch (item.type) {
      case ItemType.coin:
        return Image.asset('assets/game/coin.png', width: 45, height: 45);

      case ItemType.car:
        return Image.asset(
          item.carImage ?? 'assets/game/car1.jpg',
          width: 80,
          height: 120,
          fit: BoxFit.contain,
        );

      case ItemType.barricade:
        return Container(
          width: 60,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.black, width: 2),
          ),
          child: const Center(
            child: Icon(Icons.block, color: Colors.white, size: 26),
          ),
        );

      case ItemType.bush:
        return Image.asset('assets/game/bushes.png', width: 55, height: 55);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final laneWidth = size.width / laneCount;

    final roadWidth = laneWidth * laneCount;

    return Scaffold(
      backgroundColor: Colors.green[700],

      body: GestureDetector(
        behavior: HitTestBehavior.opaque,

        onHorizontalDragStart: (details) {
          dragStartX = details.localPosition.dx;
        },

        onHorizontalDragEnd: (details) {
          final endX = details.localPosition.dx;

          final difference = endX - dragStartX;

          handleSwipe(difference);
        },

        child: Stack(
          children: [
            // Background
            Positioned.fill(child: Container(color: Colors.green[700])),

            // Road
            Positioned(
              left: 0,
              top: 0,
              width: roadWidth,
              height: size.height,
              child: Container(color: Colors.grey[850]),
            ),

            // Lane dividers
            ...List.generate(laneCount - 1, (index) {
              double dividerLeft = (index + 1) * laneWidth;

              return Positioned(
                left: dividerLeft - 2,
                top: 0,
                width: 4,
                height: size.height,
                child: CustomPaint(
                  painter: DashedLinePainter(offset: roadOffset),
                ),
              );
            }),

            // Falling items
            ...items.map((item) {
              return Positioned(
                left: item.lane * laneWidth + laneWidth / 2 - 40,
                top: item.y * size.height,
                child: buildItemWidget(item),
              );
            }),

            // Police
            Positioned(
              left: policeLane * laneWidth + laneWidth / 2 - 27,
              top: policeY * size.height,
              child: Image.asset(
                'assets/game/police.png',
                width: 55,
                height: 55,
              ),
            ),

            // Player
            Positioned(
              left: playerLane * laneWidth + laneWidth / 2 - 30,
              top: playerY * size.height,
              child: Image.asset(
                'assets/game/character.gif',
                width: 60,
                height: 60,
              ),
            ),

            // Score and Highest Score
            Positioned(
              top: 50,
              left: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Score: $score',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    'Best: $highestScore',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                    ),
                  ),
                ],
              ),
            ),

            // Game Over
            if (isGameOver)
              Container(
                color: Colors.black87,
                width: size.width,
                height: size.height,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isArrested ? 'GIRIFTAR HO GAYE! 🚔' : 'PAKRAY GAYE! 🚨',
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 10),

                      Text(
                        'Score: $score',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'Highest Score: $highestScore',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 10),

                      if (score >= highestScore)
                        const Text(
                          '🏆 NEW HIGH SCORE! 🏆',
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                      const SizedBox(height: 30),

                      ElevatedButton.icon(
                        onPressed: restartGame,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Dobara Try Karo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 30,
                            vertical: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class DashedLinePainter extends CustomPainter {
  final double offset;

  DashedLinePainter({required this.offset});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white70
      ..strokeWidth = 4;

    const dashHeight = 30.0;
    const dashSpace = 30.0;

    double startY = -80 + offset;

    while (startY < size.height) {
      canvas.drawLine(
        Offset(size.width / 2, startY),
        Offset(size.width / 2, startY + dashHeight),
        paint,
      );

      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant DashedLinePainter oldDelegate) {
    return oldDelegate.offset != offset;
  }
}
