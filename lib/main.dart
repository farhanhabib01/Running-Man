import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

void main() async {
  // Flutter bindings ko initialize karna zaroori hai taake Audio settings apply ho sakein
  WidgetsFlutterBinding.ensureInitialized();

  // YEH CODE ZAROORI HAI SOUNDS KO EK SATH PLAY KARNE KE LIYE (MIXING)
  await AudioPlayer.global.setAudioContext(const AudioContext(
    android: AudioContextAndroid(
      isSpeakerphoneOn: false,
      stayAwake: true,
      contentType: AndroidContentType.music,
      usageType: AndroidUsageType.game,
      audioFocus: AndroidAudioFocus.none, // Is se background music stop nahi hoga
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.ambient, // Ambient se dusre sounds mix hote hain
      options: [AVAudioSessionOptions.mixWithOthers],
    ),
  ));

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Runner Chase Final TEST Game version v1.0.0',
      debugShowCheckedModeBanner: false,
      home: const StartScreen(),
    );
  }
}

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen>
    with TickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  double loadingProgress = 0.0;
  bool isLoaded = false;

  Timer? loadingTimer;

  @override
  void initState() {
    super.initState();

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: 0, end: 16).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );

    const totalDuration = Duration(milliseconds: 2200);
    const tickTime = Duration(milliseconds: 30);
    final totalTicks = totalDuration.inMilliseconds / tickTime.inMilliseconds;
    int currentTick = 0;

    loadingTimer = Timer.periodic(tickTime, (timer) {
      currentTick++;

      setState(() {
        loadingProgress = (currentTick / totalTicks).clamp(0.0, 1.0);

        if (loadingProgress >= 1.0) {
          isLoaded = true;
          timer.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _bounceController.dispose();
    loadingTimer?.cancel();
    super.dispose();
  }

  void goToGame() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const GameScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.green[700],
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),

            const Text(
              'RUNNER CHASE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                shadows: [Shadow(color: Colors.black45, blurRadius: 6)],
              ),
            ),

            const Spacer(),

            AnimatedBuilder(
              animation: _bounceAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, -_bounceAnimation.value),
                  child: child,
                );
              },
              child: Image.asset(
                'assets/game/character.gif',
                width: 110,
                height: 110,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.directions_run,
                    color: Colors.white,
                    size: 100,
                  );
                },
              ),
            ),

            const Spacer(),

            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: size.width * 0.12,
                vertical: 30,
              ),
              child: isLoaded
                  ? ElevatedButton.icon(
                      onPressed: goToGame,
                      icon: const Icon(Icons.play_arrow, size: 28),
                      label: const Text(
                        'PLAY',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.amber,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: LinearProgressIndicator(
                            value: loadingProgress,
                            minHeight: 14,
                            backgroundColor: Colors.black26,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.amber,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Loading... ${(loadingProgress * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

enum ItemType { coin, car, barricade, bush }

class FallingItem {
  int lane;
  double y;
  ItemType type;
  String? carImage;
  bool dodged = false;

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

  double speed = 0.006;

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
  double dragStartY = 0;

  bool isJumping = false;
  int jumpTick = 0;
  static const int jumpDuration = 20;
  static const double jumpHeight = 90;

  bool policeIsJumping = false;
  int policeJumpTick = 0;
  int pendingPoliceJumpDelay = 0;

  final AudioPlayer bgPlayer = AudioPlayer();
  final AudioPlayer coinPlayer = AudioPlayer();
  final AudioPlayer jumpPlayer = AudioPlayer();
  final AudioPlayer gameOverPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    startGame();
  }

  void startGame() {
    gameTimer?.cancel();
    items.clear();
    score = 0;
    speed = 0.006;
    playerLane = 1;
    policeLane = 1;
    policeY = 0.9;
    policeLaneDelayCounter = 0;
    isGameOver = false;
    isArrested = false;
    tickCounter = 0;
    roadOffset = 0;
    nextSpawnTick = 35;
    isJumping = false;
    jumpTick = 0;
    policeIsJumping = false;
    policeJumpTick = 0;
    pendingPoliceJumpDelay = 0;

    gameTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      updateGame();
    });

    playBackgroundMusic();
  }

  Future<void> playBackgroundMusic() async {
    try {
      await bgPlayer.stop();
      await bgPlayer.setReleaseMode(ReleaseMode.loop);
      await bgPlayer.play(AssetSource('sounds/background.mp3'), volume: 0.5);
    } catch (_) {}
  }

  Future<void> stopBackgroundMusic() async {
    try {
      await bgPlayer.stop();
    } catch (_) {}
  }

  Future<void> playCoinSound() async {
    try {
      await coinPlayer.stop();
      await coinPlayer.play(AssetSource('sounds/coin.mp3'), volume: 1.0);
    } catch (_) {}
  }

  Future<void> playJumpSound() async {
    try {
      await jumpPlayer.stop();
      await jumpPlayer.play(AssetSource('sounds/jump.mp3'), volume: 1.0);
    } catch (_) {}
  }

  Future<void> playGameOverSound() async {
    try {
      await gameOverPlayer.stop();
      await gameOverPlayer.play(
        AssetSource('sounds/gameover.mp3'),
        volume: 1.0,
      );
    } catch (_) {}
  }

  void updateGame() {
    if (isGameOver) return;

    setState(() {
      tickCounter++;
      roadOffset += speed * 500;
      if (roadOffset > 80) roadOffset = 0;

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

      if (isJumping) {
        jumpTick++;
        if (jumpTick >= jumpDuration) {
          isJumping = false;
          jumpTick = 0;
        }
      }

      if (pendingPoliceJumpDelay > 0) {
        pendingPoliceJumpDelay--;
        if (pendingPoliceJumpDelay == 0 && !policeIsJumping) {
          policeIsJumping = true;
          policeJumpTick = 0;
        }
      }

      if (policeIsJumping) {
        policeJumpTick++;
        if (policeJumpTick >= jumpDuration) {
          policeIsJumping = false;
          policeJumpTick = 0;
        }
      }

      if (policeLane == playerLane &&
          policeY - playerY < 0.09 &&
          !isArrested &&
          !isJumping) {
        gameOver();
        return;
      }

      double speedProgress = ((speed - 0.006) / (0.024 - 0.006)).clamp(0.0, 1.0);

      if (tickCounter >= nextSpawnTick) {
        int itemCount;
        if (speedProgress < 0.15) itemCount = 1;
        else if (speedProgress < 0.35) itemCount = 2;
        else if (speedProgress < 0.60) itemCount = 3;
        else if (speedProgress < 0.85) itemCount = 4;
        else itemCount = 5;

        List<int> usedLanes = [];

        for (int i = 0; i < itemCount; i++) {
          int lane;
          do {
            lane = random.nextInt(laneCount);
          } while (usedLanes.contains(lane) && usedLanes.length < laneCount);

          usedLanes.add(lane);

          double chance = random.nextDouble();
          double carChance = (0.25 + (speed - 0.006) * 6).clamp(0.25, 0.45);
          double coinChance = 0.45 + (speedProgress * 0.25);
          if (coinChance > 0.70) coinChance = 0.70;

          ItemType type;
          if (chance < coinChance) type = ItemType.coin;
          else if (chance < coinChance + carChance) type = ItemType.car;
          else if (chance < coinChance + carChance + 0.15) type = ItemType.barricade;
          else type = ItemType.bush;

          String? carImg;
          if (type == ItemType.car) {
            carImg = random.nextBool() ? 'assets/game/car1.png' : 'assets/game/car2.png';
          }

          double spawnY = -0.18 - (i * 0.08);
          items.add(FallingItem(lane: lane, y: spawnY, type: type, carImage: carImg));
        }

        int baseGap = (48 - (speedProgress * 34)).round();
        if (baseGap < 12) baseGap = 12;
        int randomVariance = random.nextInt(10);
        nextSpawnTick = tickCounter + baseGap + randomVariance;
      }

      for (var item in items) {
        item.y += speed;
      }

      for (var item in List<FallingItem>.from(items)) {
        if (item.dodged) continue;

        if (item.lane == playerLane &&
            item.y > playerY - 0.06 &&
            item.y < playerY + 0.06) {
          if (item.type == ItemType.coin) {
            score += 10;
            items.remove(item);
            playCoinSound();
          } else if (isJumping) {
            item.dodged = true;
          } else {
            arrestPlayer();
            return;
          }
        }
      }

      items.removeWhere((item) => item.y > 1.1);

      if (tickCounter % 90 == 0) {
        speed += 0.0008;
        if (speed > 0.024) speed = 0.024;
      }

      if (tickCounter % 15 == 0) {
        score += 1;
      }

      if (score > highestScore) highestScore = score;
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
    if (score > highestScore) highestScore = score;
    gameTimer?.cancel();
    
    // Yahan maine `stopBackgroundMusic()` ko HATA diya hai 
    // taake game over ke baad bhi music chalta rahe.
    playGameOverSound();
  }

  void handleSwipe(double difference) {
    const double swipeThreshold = 25;
    if (difference.abs() < swipeThreshold) return;
    if (difference > 0) moveRight();
    else moveLeft();
  }

  void handleVerticalSwipe(double difference) {
    const double swipeThreshold = 25;
    if (difference < -swipeThreshold) triggerJump();
  }

  void triggerJump() {
    if (isGameOver || isJumping) return;
    setState(() {
      isJumping = true;
      jumpTick = 0;
      pendingPoliceJumpDelay = 6;
    });
    playJumpSound();
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
    bgPlayer.dispose();
    coinPlayer.dispose();
    jumpPlayer.dispose();
    gameOverPlayer.dispose();
    super.dispose();
  }

  Widget safeImage(
    String path, {
    required double width,
    required double height,
    BoxFit fit = BoxFit.contain,
  }) {
    return Image.asset(
      path,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: Colors.redAccent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.black, width: 2),
          ),
          child: const Center(
            child: Icon(Icons.broken_image, color: Colors.white, size: 20),
          ),
        );
      },
    );
  }

  Widget buildItemWidget(FallingItem item) {
    switch (item.type) {
      case ItemType.coin:
        return safeImage('assets/game/coin.png', width: 45, height: 45);
      case ItemType.car:
        return safeImage(
          item.carImage ?? 'assets/game/car1.png',
          width: 80,
          height: 120,
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
        return safeImage('assets/game/bushes.png', width: 55, height: 55);
    }
  }

  double _jumpArc(int tick) {
    double progress = tick / jumpDuration;
    return sin(pi * progress) * jumpHeight;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final laneWidth = size.width / laneCount;
    final roadWidth = laneWidth * laneCount;
    final double playerJumpOffset = isJumping ? _jumpArc(jumpTick) : 0;
    final double policeJumpOffset = policeIsJumping ? _jumpArc(policeJumpTick) : 0;

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
        onVerticalDragStart: (details) {
          dragStartY = details.localPosition.dy;
        },
        onVerticalDragEnd: (details) {
          final endY = details.localPosition.dy;
          final difference = endY - dragStartY;
          handleVerticalSwipe(difference);
        },
        child: Stack(
          children: [
            Positioned.fill(child: Container(color: Colors.green[700])),
            Positioned(
              left: 0,
              top: 0,
              width: roadWidth,
              height: size.height,
              child: Container(color: Colors.grey[850]),
            ),
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
            ...items.map((item) {
              return Positioned(
                left: item.lane * laneWidth + laneWidth / 2 - 40,
                top: item.y * size.height,
                child: buildItemWidget(item),
              );
            }),
            Positioned(
              left: policeLane * laneWidth + laneWidth / 2 - 27,
              top: policeY * size.height - policeJumpOffset,
              child: safeImage('assets/game/police.png', width: 55, height: 55),
            ),
            Positioned(
              left: playerLane * laneWidth + laneWidth / 2 - 30,
              top: playerY * size.height - playerJumpOffset,
              child: safeImage(
                'assets/game/character.gif',
                width: 60,
                height: 60,
              ),
            ),
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
                        isArrested
                            ? 'GIRIFTAR HO GAYE! \u{1F694}'
                            : 'PAKRAY GAYE! \u{1F6A8}',
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
                      if (score >= highestScore && score > 0)
                        const Text(
                          '\u{1F3C6} NEW HIGH SCORE! \u{1F3C6}',
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