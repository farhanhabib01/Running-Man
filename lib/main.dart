import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

class SoundManager {
  static final AudioPlayer bg = AudioPlayer();
  static final List<AudioPlayer> coinPool = List.generate(
    4,
    (_) => AudioPlayer(),
  );
  static final AudioPlayer jump = AudioPlayer();
  static final AudioPlayer gameOver = AudioPlayer();

  static bool _preloaded = false;
  static bool _preloading = false;

  static Future<void> preload() async {
    if (_preloaded || _preloading) return;
    _preloading = true;

    try {
      for (final p in coinPool) {
        await p.setPlayerMode(PlayerMode.lowLatency);
      }
      await jump.setPlayerMode(PlayerMode.lowLatency);
      await gameOver.setPlayerMode(PlayerMode.lowLatency);

      await bg.setReleaseMode(ReleaseMode.loop);
      await bg.setVolume(0.5);

      final List<Future<void>> loadTasks = [
        bg.setSourceAsset('sounds/background.mp3'),
        jump.setSourceAsset('sounds/jump.mp3'),
        gameOver.setSourceAsset('sounds/gameover.mp3'),
      ];

      for (final p in coinPool) {
        loadTasks.add(p.setSourceAsset('sounds/coin.mp3'));
      }

      await Future.wait(loadTasks);
      _preloaded = true;
    } catch (_) {
    } finally {
      _preloading = false;
    }
  }

  static Future<void> playBackgroundMusic() async {
    try {
      await bg.setReleaseMode(ReleaseMode.loop);
      await bg.play(AssetSource('sounds/background.mp3'));
    } catch (_) {}
  }

  static Future<void> stopBackgroundMusic() async {
    try {
      await bg.stop();
    } catch (_) {}
  }

  static void playCoin() {
    _playCoinFresh();
  }

  static Future<void> _playCoinFresh() async {
    final player = AudioPlayer();
    try {
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.setReleaseMode(ReleaseMode.release);
      player.onPlayerComplete.listen((_) {
        player.dispose();
      });
      await player.play(AssetSource('sounds/coin.mp3'));
    } catch (_) {
      await player.dispose();
    }
  }

  static Future<void> playJump() async {
    try {
      await jump.stop();
      await jump.play(AssetSource('sounds/jump.mp3'));
    } catch (_) {}
  }

  static Future<void> playGameOver() async {
    try {
      await gameOver.stop();
      await gameOver.play(AssetSource('sounds/gameover.mp3'));
    } catch (_) {}
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AudioPlayer.global.setAudioContext(
    AudioContext(
      android: AudioContextAndroid(
        isSpeakerphoneOn: false,
        stayAwake: false,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.game,
        audioFocus: AndroidAudioFocus.none,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        options: {AVAudioSessionOptions.mixWithOthers},
      ),
    ),
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Runner Chase Cyber Edition',
      debugShowCheckedModeBanner: false,
      home: StartScreen(),
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
  late AnimationController _introController;
  late Animation<double> _titleFade;
  late Animation<double> _titleSlide;
  late Animation<double> _logoFade;
  late Animation<double> _logoScale;
  late Animation<double> _logoRotate;
  late Animation<double> _bottomFade;
  late Animation<double> _bottomSlide;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _bgController;
  late AnimationController _glowController;
  late AnimationController _ringRotateController;
  late AnimationController _shimmerController;
  late AnimationController _sirenController;

  double loadingProgress = 0.0;
  bool isLoaded = false;
  Timer? loadingTimer;

  @override
  void initState() {
    super.initState();
    SoundManager.preload().then((_) {
      if (mounted) {
        SoundManager.playBackgroundMusic();
      }
    });

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _bounceAnimation = Tween<double>(begin: 0, end: 16).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );

    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();

    _titleFade = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
    );
    _titleSlide = Tween<double>(begin: -30, end: 0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutBack),
      ),
    );
    _logoFade = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.2, 0.75, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.2, 0.85, curve: Curves.elasticOut),
      ),
    );
    _logoRotate = Tween<double>(begin: -0.5, end: 0.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.2, 0.75, curve: Curves.easeOutCubic),
      ),
    );
    _bottomFade = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
    );
    _bottomSlide = Tween<double>(begin: 26, end: 0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.55, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
    _ringRotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _sirenController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

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
    _introController.dispose();
    _pulseController.dispose();
    _bgController.dispose();
    _glowController.dispose();
    _ringRotateController.dispose();
    _shimmerController.dispose();
    _sirenController.dispose();
    loadingTimer?.cancel();
    super.dispose();
  }

  void goToGame() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 650),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const GameScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final fade = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          );
          final scale = Tween<double>(begin: 1.1, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          );
          return FadeTransition(
            opacity: fade,
            child: ScaleTransition(scale: scale, child: child),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, child) {
          final t = _bgController.value;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.lerp(Colors.indigo[900], Colors.purple[900], t)!,
                  Color.lerp(Colors.blue[900], Colors.teal[900], t)!,
                  Colors.black,
                ],
                stops: const [0.0, 0.6, 1.0],
              ),
            ),
            child: child,
          );
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: CyberGridPainter(phase: _sirenController.value),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 50),
                  AnimatedBuilder(
                    animation: Listenable.merge([
                      _introController,
                      _shimmerController,
                    ]),
                    builder: (context, child) {
                      final shimmerT = _shimmerController.value;
                      return Opacity(
                        opacity: _titleFade.value,
                        child: Transform.translate(
                          offset: Offset(0, _titleSlide.value),
                          child: ShaderMask(
                            blendMode: BlendMode.srcIn,
                            shaderCallback: (bounds) {
                              return LinearGradient(
                                colors: const [
                                  Colors.cyanAccent,
                                  Colors.pinkAccent,
                                  Colors.cyanAccent,
                                ],
                                stops: const [0.2, 0.5, 0.8],
                                begin: Alignment(-1 + 2 * shimmerT, 0),
                                end: Alignment(1 + 2 * shimmerT, 0),
                              ).createShader(bounds);
                            },
                            child: child,
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      'CYBER RUNNER 2077',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                        shadows: [
                          Shadow(color: Colors.cyanAccent, blurRadius: 15),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ULTIMATE GRAPHICAL BLOCKBUSTER',
                    style: TextStyle(
                      color: Colors.pinkAccent.shade100,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 4,
                    ),
                  ),
                  const Spacer(),
                  AnimatedBuilder(
                    animation: Listenable.merge([
                      _bounceAnimation,
                      _introController,
                    ]),
                    builder: (context, child) {
                      return Opacity(
                        opacity: _logoFade.value,
                        child: Transform.translate(
                          offset: Offset(0, -_bounceAnimation.value),
                          child: Transform.scale(
                            scale: _logoScale.value,
                            child: Container(
                              width: 170,
                              height: 170,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.cyan.withValues(alpha: 0.6),
                                    Colors.transparent,
                                  ],
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.cyanAccent,
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/icon/icon.png',
                                    width: 130,
                                    height: 130,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.flash_on_rounded,
                                      size: 70,
                                      color: Colors.cyanAccent,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const Spacer(),
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: size.width * 0.12,
                      vertical: 30,
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 450),
                      child: isLoaded
                          ? AnimatedBuilder(
                              animation: _pulseAnimation,
                              builder: (context, child) => Transform.scale(
                                scale: _pulseAnimation.value,
                                child: child,
                              ),
                              child: ElevatedButton.icon(
                                onPressed: goToGame,
                                icon: const Icon(Icons.bolt_rounded, size: 28),
                                label: const Text(
                                  'START CYBER RUN',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.cyanAccent,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 18,
                                  ),
                                  minimumSize: const Size(double.infinity, 56),
                                  elevation: 15,
                                  shadowColor: Colors.cyanAccent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                ),
                              ),
                            )
                          : Column(
                              children: [
                                LinearProgressIndicator(
                                  value: loadingProgress,
                                  color: Colors.cyanAccent,
                                  backgroundColor: Colors.white24,
                                  minHeight: 12,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Loading High-End Shaders... ${(loadingProgress * 100).toInt()}%',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
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

// Cyber Grid Custom Painter for Massive Graphical Upgrade
class CyberGridPainter extends CustomPainter {
  final double phase;
  CyberGridPainter({required this.phase});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.15)
      ..strokeWidth = 1.5;

    final horizonY = size.height * 0.45;
    final centerX = size.width / 2;

    // Perspective Vertical Grid Lines
    for (double i = -size.width; i <= size.width * 2; i += 60) {
      canvas.drawLine(
        Offset(centerX + (i - centerX) * 0.1, horizonY),
        Offset(i, size.height),
        paint,
      );
    }

    // Perspective Horizontal Grid Lines with motion phase
    double spacing = 30;
    double offset = (phase * spacing) % spacing;
    for (double y = horizonY; y < size.height; y += spacing) {
      double currentY = y + offset;
      if (currentY > horizonY) {
        double alphaFactor = ((currentY - horizonY) / (size.height - horizonY))
            .clamp(0.0, 1.0);
        paint.color = Colors.pinkAccent.withValues(alpha: 0.25 * alphaFactor);
        canvas.drawLine(
          Offset(0, currentY),
          Offset(size.width, currentY),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CyberGridPainter oldDelegate) =>
      oldDelegate.phase != phase;
}

enum ItemType { coin, keyItem, shield, magnet, car, barricade, bush }

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

class FloatingPopup {
  double x, y;
  int life;
  static const int maxLife = 35;
  final String text;
  final Color color;
  FloatingPopup({
    required this.x,
    required this.y,
    required this.text,
    this.color = Colors.cyanAccent,
    this.life = maxLife,
  });
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  static const int laneCount = 3;
  bool isIntroPhase = true;
  int playerLane = 1;
  double playerY = 0.7;
  double playerLaneAnim = 1.0;

  int policeLane = 1;
  double policeY = 1.2;
  double policeLaneAnim = 1.0;
  int policeLaneDelayCounter = 0;

  double sceneryOffset = 0;
  List<FallingItem> items = [];
  List<FloatingPopup> popups = [];
  List<Offset> neonTrail = [];

  double speed = 0.007;
  int score = 0,
      highestScore = 0,
      coins = 0,
      highestCoins = 0,
      keys = 0,
      level = 1;
  bool hasShield = false, hasMagnet = false;
  int magnetTimer = 0, comboMultiplier = 1;

  bool isGameOver = false, isPaused = false, showRevivePrompt = false;
  int reviveTimerSeconds = 4;
  Timer? reviveTimer, gameTimer;
  final Random random = Random();
  int tickCounter = 0, nextSpawnTick = 30;
  double dragStartX = 0, dragStartY = 0;

  bool isJumping = false;
  int jumpTick = 0;
  static const int jumpDuration = 18;
  static const double jumpHeight = 100;

  @override
  void initState() {
    super.initState();
    setupGame();
  }

  void setupGame() {
    gameTimer?.cancel();
    reviveTimer?.cancel();
    items.clear();
    popups.clear();
    neonTrail.clear();
    score = 0;
    coins = 0;
    keys = 0;
    level = 1;
    speed = 0.007;
    playerLane = 1;
    playerLaneAnim = 1.0;
    isIntroPhase = true;
    isGameOver = false;
    isPaused = false;
    showRevivePrompt = false;
    hasShield = false;
    hasMagnet = false;
    magnetTimer = 0;
    comboMultiplier = 1;
    tickCounter = 0;
    nextSpawnTick = 30;

    gameTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!isIntroPhase) updateGame();
      setState(() {});
    });
  }

  void updateGame() {
    if (isGameOver || isPaused || showRevivePrompt) return;
    tickCounter++;
    sceneryOffset += speed * 300;
    if (sceneryOffset > 240) sceneryOffset = 0;

    playerLaneAnim += (playerLane - playerLaneAnim) * 0.3;
    policeLaneAnim += (policeLane - policeLaneAnim) * 0.25;

    policeLaneDelayCounter++;
    if (policeLaneDelayCounter > 12) {
      policeLaneDelayCounter = 0;
      if (policeLane < playerLane)
        policeLane++;
      else if (policeLane > playerLane)
        policeLane--;
    }

    policeY += ((playerY + 0.12) - policeY) * 0.12;

    if (hasMagnet) {
      magnetTimer--;
      if (magnetTimer <= 0)
        hasMagnet = false;
      else {
        for (var item in items) {
          if (item.type == ItemType.coin && (item.y - playerY).abs() < 0.5)
            item.lane = playerLane;
        }
      }
    }

    if (isJumping) {
      jumpTick++;
      if (jumpTick >= jumpDuration) {
        isJumping = false;
        jumpTick = 0;
      }
    }

    if (policeLane == playerLane && policeY - playerY < 0.08 && !isJumping) {
      if (hasShield) {
        hasShield = false;
        policeY = 1.2;
      } else {
        triggerReviveOrGameOver();
        return;
      }
    }

    if (tickCounter >= nextSpawnTick) {
      int lane = random.nextInt(laneCount);
      double chance = random.nextDouble();
      ItemType type = chance < 0.08
          ? ItemType.shield
          : (chance < 0.15
                ? ItemType.magnet
                : (chance < 0.55 ? ItemType.coin : ItemType.car));
      String? carImg = type == ItemType.car
          ? (random.nextBool()
                ? 'assets/game/car1.png'
                : 'assets/game/car2.png')
          : null;
      items.add(FallingItem(lane: lane, y: -0.2, type: type, carImage: carImg));
      nextSpawnTick = tickCounter + 25 + random.nextInt(15);
    }

    for (var item in items) {
      item.y += speed;
    }

    for (var item in List<FallingItem>.from(items)) {
      if (item.lane == playerLane &&
          item.y > playerY - 0.06 &&
          item.y < playerY + 0.06) {
        if (item.type == ItemType.coin) {
          coins++;
          score += (10 * comboMultiplier);
          popups.add(
            FloatingPopup(
              x: item.lane * 1.0,
              y: item.y,
              text: '+${10 * comboMultiplier}',
            ),
          );
          items.remove(item);
          SoundManager.playCoin();
        } else if (item.type == ItemType.shield) {
          hasShield = true;
          items.remove(item);
          popups.add(
            FloatingPopup(
              x: item.lane * 1.0,
              y: item.y,
              text: 'CYBER SHIELD ACTIVE! 🛡️',
              color: Colors.cyanAccent,
            ),
          );
        } else if (item.type == ItemType.magnet) {
          hasMagnet = true;
          magnetTimer = 250;
          items.remove(item);
          popups.add(
            FloatingPopup(
              x: item.lane * 1.0,
              y: item.y,
              text: 'COIN MAGNET 🧲',
              color: Colors.amberAccent,
            ),
          );
        } else if (!isJumping) {
          if (hasShield) {
            hasShield = false;
            items.remove(item);
          } else {
            triggerReviveOrGameOver();
            return;
          }
        }
      }
    }
    items.removeWhere((i) => i.y > 1.2);

    for (var p in popups) {
      p.y -= 0.007;
      p.life--;
    }
    popups.removeWhere((p) => p.life <= 0);

    score += comboMultiplier;
    if (coins >= level * 10) level++;
    if (score > highestScore) highestScore = score;
  }

  void triggerReviveOrGameOver() {
    gameTimer?.cancel();
    SoundManager.stopBackgroundMusic();
    SoundManager.playGameOver();
    setState(() {
      isGameOver = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final roadWidth = size.width * 0.85;
    final laneWidth = roadWidth / laneCount;
    final roadLeft = (size.width - roadWidth) / 2;
    double jumpOffset = isJumping
        ? sin((jumpTick / jumpDuration) * pi) * jumpHeight
        : 0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () {
          if (isIntroPhase)
            setState(() {
              isIntroPhase = false;
              SoundManager.playBackgroundMusic();
            });
        },
        onHorizontalDragEnd: (d) {
          if (!isIntroPhase &&
              (d.primaryVelocity ?? 0) > 0 &&
              playerLane < laneCount - 1)
            playerLane++;
          else if (!isIntroPhase &&
              (d.primaryVelocity ?? 0) < 0 &&
              playerLane > 0)
            playerLane--;
        },
        onVerticalDragEnd: (d) {
          if (!isIntroPhase && (d.primaryVelocity ?? 0) < 0) {
            isJumping = true;
            jumpTick = 0;
            SoundManager.playJump();
          }
        },
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPainter(
                painter: CyberGridPainter(phase: tickCounter * 0.05),
              ),
            ),
            // Neon Road Lanes
            Positioned(
              left: roadLeft,
              top: 0,
              width: roadWidth,
              height: size.height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.grey[900]!,
                      Colors.black,
                      Colors.grey[900]!,
                    ],
                  ),
                  border: Border.symmetric(
                    vertical: BorderSide(color: Colors.cyanAccent, width: 3),
                  ),
                ),
              ),
            ),
            // Items
            ...items.map(
              (i) => Positioned(
                left: roadLeft + i.lane * laneWidth + laneWidth / 2 - 30,
                top: i.y * size.height,
                child: i.type == ItemType.coin
                    ? Icon(
                        Icons.monetization_on_rounded,
                        color: Colors.amber,
                        size: 36,
                      )
                    : (i.type == ItemType.shield
                          ? Icon(
                              Icons.shield_rounded,
                              color: Colors.cyanAccent,
                              size: 40,
                            )
                          : Icon(
                              Icons.fitness_center_rounded,
                              color: Colors.pinkAccent,
                              size: 40,
                            )),
              ),
            ),
            // Popups
            ...popups.map(
              (p) => Positioned(
                left: roadLeft + p.x * laneWidth,
                top: p.y * size.height,
                child: Text(
                  p.text,
                  style: TextStyle(
                    color: p.color,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    shadows: const [Shadow(color: Colors.black, blurRadius: 6)],
                  ),
                ),
              ),
            ),
            // Police
            Positioned(
              left: roadLeft + policeLaneAnim * laneWidth + laneWidth / 2 - 25,
              top: policeY * size.height,
              child: const Icon(
                Icons.local_police_rounded,
                color: Colors.redAccent,
                size: 50,
              ),
            ),
            // Player Character with Shield Aura
            Positioned(
              left: roadLeft + playerLaneAnim * laneWidth + laneWidth / 2 - 35,
              top: playerY * size.height - jumpOffset,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (hasShield)
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.cyanAccent, width: 3),
                        boxShadow: const [
                          BoxShadow(color: Colors.cyanAccent, blurRadius: 15),
                        ],
                      ),
                    ),
                  safeImage('assets/game/character.gif', width: 75, height: 75),
                ],
              ),
            ),
            // HUD
            if (!isIntroPhase)
              Positioned(
                top: 45,
                left: 16,
                right: 16,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'SCORE: $score',
                      style: const TextStyle(
                        color: Colors.cyanAccent,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'COINS: $coins 🪙',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'LVL: $level ⚡',
                      style: const TextStyle(
                        color: Colors.pinkAccent,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            if (isIntroPhase)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.7),
                  child: const Center(
                    child: Text(
                      'TAP TO START CYBER RUN',
                      style: TextStyle(
                        color: Colors.cyanAccent,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              ),
            if (isGameOver)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.85),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'CRITICAL SYSTEM FAILURE',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: setupGame,
                          child: const Text('REBOOT CYBER RUN'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget safeImage(
    String path, {
    required double width,
    required double height,
  }) {
    return Image.asset(
      path,
      width: width,
      height: height,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) =>
          const Icon(Icons.person, size: 50, color: Colors.white),
    );
  }
}

class DashedLinePainter extends CustomPainter {
  final double offset;
  DashedLinePainter({required this.offset});
  @override
  void paint(Canvas canvas, Size size) {}
  @override
  bool shouldRepaint(covariant DashedLinePainter oldDelegate) => false;
}
