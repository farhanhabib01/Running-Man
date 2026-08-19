import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

// ==========================================
// SOUND MANAGER
// Preloads every sound once so playback is instant with no
// first-play decode delay. Uses seek(0) + resume() to replay
// instead of play(), which avoids reloading the asset each time.
//
// Coins use a small rotating pool of players instead of one
// shared player - this fixes the bug where only the FIRST coin
// pickup made a sound. Calling play(AssetSource(...)) repeatedly
// on the same AudioPlayer instance is unreliable in audioplayers;
// after the first call the player's internal state can get stuck
// and ignore further play requests. Rotating across several
// preloaded players avoids that entirely, and also lets rapid
// back-to-back coin pickups overlap properly.
// ==========================================
class SoundManager {
  static final AudioPlayer bg = AudioPlayer();
  static final List<AudioPlayer> coinPool = List.generate(
    4,
    (_) => AudioPlayer(),
  );
  static int _coinIndex = 0;
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
      // If any asset is missing, the game should still run silently.
    } finally {
      _preloading = false;
    }
  }

  static Future<void> playBackgroundMusic() async {
    try {
      await bg.seek(Duration.zero);
      await bg.resume();
    } catch (_) {}
  }

  static Future<void> stopBackgroundMusic() async {
    try {
      await bg.stop();
    } catch (_) {}
  }

  static Future<void> playCoin() async {
    try {
      final player = coinPool[_coinIndex];
      _coinIndex = (_coinIndex + 1) % coinPool.length;
      await player.seek(Duration.zero);
      await player.resume();
    } catch (_) {}
  }

  static Future<void> playJump() async {
    try {
      await jump.seek(Duration.zero);
      await jump.resume();
    } catch (_) {}
  }

  static Future<void> playGameOver() async {
    try {
      await gameOver.seek(Duration.zero);
      await gameOver.resume();
    } catch (_) {}
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Allow all sound effects to mix together instead of one interrupting
  // another - this is what stops the coin sound from cutting off the
  // background music.
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
    return MaterialApp(
      title: 'Runner Chase Final TEST Game version v1.0.0',
      debugShowCheckedModeBanner: false,
      home: const StartScreen(),
    );
  }
}

// ==========================================
// DECORATIVE FLOATING CLOUDS
// Purely visual parallax layer used on the start screen to make the
// background feel alive instead of a flat color. Runs on its own
// ticker so it never interferes with game logic.
// ==========================================
class _FloatingClouds extends StatefulWidget {
  const _FloatingClouds();

  @override
  State<_FloatingClouds> createState() => _FloatingCloudsState();
}

class _FloatingCloudsState extends State<_FloatingClouds>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  final List<double> _startOffsets = [0.0, 0.35, 0.65, 0.85, 0.5];
  final List<double> _speeds = [0.55, 1.0, 0.8, 1.3, 0.65];
  final List<double> _sizes = [70, 46, 90, 38, 60];
  final List<double> _verticalPositions = [0.08, 0.18, 0.04, 0.24, 0.14];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return Stack(
              children: List.generate(_startOffsets.length, (i) {
                final t =
                    (_controller.value * _speeds[i] + _startOffsets[i]) % 1.0;
                final left = t * (width + _sizes[i]) - _sizes[i];

                return Positioned(
                  left: left,
                  top: constraints.maxHeight * _verticalPositions[i],
                  child: Opacity(
                    opacity: 0.16,
                    child: Container(
                      width: _sizes[i],
                      height: _sizes[i] * 0.55,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(_sizes[i]),
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        );
      },
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
  // Character idle bounce
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  // Entrance animation for title + character when the screen first opens
  late AnimationController _introController;
  late Animation<double> _titleFade;
  late Animation<double> _titleSlide;
  late Animation<double> _charFade;
  late Animation<double> _charScale;

  // Gentle pulsing on the PLAY button so it draws the eye once ready
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Slow ambient background gradient shift
  late AnimationController _bgController;

  double loadingProgress = 0.0;
  bool isLoaded = false;

  Timer? loadingTimer;

  @override
  void initState() {
    super.initState();

    // Preload all sounds now, in parallel with the loading bar below,
    // so there is zero delay the first time a sound is triggered.
    SoundManager.preload();

    // Character idle bounce animation - loops up and down forever.
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: 0, end: 16).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );

    // Entrance: title slides/fades in first, character fades in slightly
    // after it, giving the screen a staggered, polished opening.
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _titleFade = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _titleSlide = Tween<double>(begin: -30, end: 0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );
    _charFade = CurvedAnimation(
      parent: _introController,
      curve: const Interval(0.3, 0.9, curve: Curves.easeOut),
    );
    _charScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _introController,
        curve: const Interval(0.3, 0.9, curve: Curves.easeOutBack),
      ),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);

    // Fake loading bar - fills up over ~2.2 seconds, then reveals Play button.
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
    loadingTimer?.cancel();
    super.dispose();
  }

  void goToGame() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 550),
        pageBuilder: (context, animation, secondaryAnimation) =>
            const GameScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final fade = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          );
          final scale = Tween<double>(begin: 1.06, end: 1.0).animate(
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

  Widget _buildLoadingBar() {
    return Column(
      key: const ValueKey('loading'),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: loadingProgress,
            minHeight: 14,
            backgroundColor: Colors.black26,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
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
    );
  }

  Widget _buildPlayButton() {
    return AnimatedBuilder(
      key: const ValueKey('play'),
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(scale: _pulseAnimation.value, child: child);
      },
      child: ElevatedButton.icon(
        onPressed: goToGame,
        icon: const Icon(Icons.play_arrow, size: 28),
        label: const Text(
          'PLAY',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.amber,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          minimumSize: const Size(double.infinity, 55),
          elevation: 8,
          shadowColor: Colors.black54,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
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
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(Colors.green[800], Colors.green[600], t)!,
                  Color.lerp(Colors.teal[700], Colors.green[700], t)!,
                ],
              ),
            ),
            child: child,
          );
        },
        child: Stack(
          children: [
            const Positioned.fill(child: _FloatingClouds()),
            SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 40),

                  AnimatedBuilder(
                    animation: _introController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _titleFade.value,
                        child: Transform.translate(
                          offset: Offset(0, _titleSlide.value),
                          child: child,
                        ),
                      );
                    },
                    child: const Text(
                      'RUNNER CHASE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        shadows: [Shadow(color: Colors.black45, blurRadius: 6)],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Bouncing character with a staggered fade/scale entrance
                  AnimatedBuilder(
                    animation: Listenable.merge([
                      _bounceAnimation,
                      _introController,
                    ]),
                    builder: (context, child) {
                      return Opacity(
                        opacity: _charFade.value,
                        child: Transform.scale(
                          scale: _charScale.value,
                          child: Transform.translate(
                            offset: Offset(0, -_bounceAnimation.value),
                            child: child,
                          ),
                        ),
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

                  // Loading bar OR Play button, with a smooth cross-fade
                  // + scale transition between the two states.
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: size.width * 0.12,
                      vertical: 30,
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 450),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(
                          opacity: animation,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.85, end: 1.0).animate(
                              CurvedAnimation(
                                parent: animation,
                                curve: Curves.easeOutBack,
                              ),
                            ),
                            child: child,
                          ),
                        );
                      },
                      child: isLoaded ? _buildPlayButton() : _buildLoadingBar(),
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
  bool dodged = false; // true once the player has jumped over this hurdle

  FallingItem({
    required this.lane,
    required this.y,
    required this.type,
    this.carImage,
  });
}

// A short-lived floating "+10" style popup shown when a coin is collected.
class FloatingPopup {
  double x;
  double y;
  int life; // ticks remaining
  static const int maxLife = 30;
  final String text;

  FloatingPopup({
    required this.x,
    required this.y,
    required this.text,
    this.life = maxLife,
  });

  // Pops in quickly with a small overshoot, then holds steady while
  // it fades and floats upward. Purely cosmetic, derived from `life`
  // so it needs no extra AnimationController.
  double get scale {
    final t = 1 - (life / maxLife); // 0 -> 1 over its lifetime
    if (t < 0.2) {
      final p = t / 0.2;
      return 0.4 + 0.8 * Curves.easeOutBack.transform(p);
    }
    return 1.0;
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  static const int laneCount = 3;

  int playerLane = 1;
  double playerY = 0.7;

  int policeLane = 1;
  double policeY = 0.9;
  int policeLaneDelayCounter = 0;

  List<FallingItem> items = [];
  List<FloatingPopup> popups = [];

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

  // ==========================================
  // JUMP MECHANIC
  // ==========================================
  bool isJumping = false;
  int jumpTick = 0;
  static const int jumpDuration = 20; // total ticks for one jump
  static const double jumpHeight = 90; // pixels

  bool policeIsJumping = false;
  int policeJumpTick = 0;
  int pendingPoliceJumpDelay = 0; // ticks until police starts jumping too

  // ==========================================
  // POLISH ANIMATIONS
  // These run on their own tickers so they animate smoothly even in
  // the instant the main game timer stops (e.g. right at game over).
  // ==========================================
  late AnimationController
  _shakeController; // screen shake + red flash on arrest
  late AnimationController
  _scoreBumpController; // score pop when coins are collected
  late Animation<double> _scoreBumpAnimation;
  late AnimationController
  _gameOverController; // entrance for the game-over card

  @override
  void initState() {
    super.initState();

    _shakeController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 500),
        )..addListener(() {
          if (mounted) setState(() {});
        });

    _scoreBumpController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 260),
        )..addListener(() {
          if (mounted) setState(() {});
        });

    _scoreBumpAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.35,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.35,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeIn)),
        weight: 60,
      ),
    ]).animate(_scoreBumpController);

    _gameOverController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 550),
        )..addListener(() {
          if (mounted) setState(() {});
        });

    startGame();
  }

  void startGame() {
    gameTimer?.cancel();

    items.clear();
    popups.clear();

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

    _shakeController.reset();
    _scoreBumpController.reset();
    _gameOverController.reset();

    gameTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      updateGame();
    });

    SoundManager.playBackgroundMusic();
  }

  void updateGame() {
    if (isGameOver) return;

    setState(() {
      tickCounter++;

      roadOffset += speed * 500;

      if (roadOffset > 80) {
        roadOffset = 0;
      }

      // Police chase logic (lane following)
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

      // ==========================================
      // JUMP PROGRESSION - Player
      // ==========================================
      if (isJumping) {
        jumpTick++;
        if (jumpTick >= jumpDuration) {
          isJumping = false;
          jumpTick = 0;
        }
      }

      // ==========================================
      // JUMP PROGRESSION - Police (follows player's jump
      // after a short delay, mimicking the chase)
      // ==========================================
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

      // Arrest check (only if neither player nor police mid-air dodge protects them)
      if (policeLane == playerLane &&
          policeY - playerY < 0.09 &&
          !isArrested &&
          !isJumping) {
        gameOver();
        return;
      }

      double speedProgress = ((speed - 0.006) / (0.024 - 0.006)).clamp(
        0.0,
        1.0,
      );

      if (tickCounter >= nextSpawnTick) {
        int itemCount;

        if (speedProgress < 0.15) {
          itemCount = 1;
        } else if (speedProgress < 0.35) {
          itemCount = 2;
        } else if (speedProgress < 0.60) {
          itemCount = 3;
        } else if (speedProgress < 0.85) {
          itemCount = 4;
        } else {
          itemCount = 5;
        }

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

          if (coinChance > 0.70) {
            coinChance = 0.70;
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
                ? 'assets/game/car1.png'
                : 'assets/game/car2.png';
          }

          double spawnY = -0.18 - (i * 0.08);

          items.add(
            FallingItem(lane: lane, y: spawnY, type: type, carImage: carImg),
          );
        }

        int baseGap = (48 - (speedProgress * 34)).round();

        if (baseGap < 12) {
          baseGap = 12;
        }

        int randomVariance = random.nextInt(10);

        nextSpawnTick = tickCounter + baseGap + randomVariance;
      }

      for (var item in items) {
        item.y += speed;
      }

      // ==========================================
      // COLLISION - jumping lets you pass over
      // barricades, bushes, and cars while mid-air.
      // Coins are still collected even while jumping.
      // ==========================================
      for (var item in List<FallingItem>.from(items)) {
        if (item.dodged) {
          // Already jumped over this one earlier - permanently safe,
          // even after the jump animation has ended.
          continue;
        }

        if (item.lane == playerLane &&
            item.y > playerY - 0.06 &&
            item.y < playerY + 0.06) {
          if (item.type == ItemType.coin) {
            score += 10;
            popups.add(
              FloatingPopup(x: item.lane * 1.0, y: item.y, text: '+10'),
            );
            items.remove(item);
            SoundManager.playCoin();
            _scoreBumpController.forward(from: 0);
          } else if (isJumping) {
            // Successfully jumped over the hurdle - mark it as dodged
            // so it can never cause an arrest again, even after landing.
            item.dodged = true;
          } else {
            arrestPlayer();
            return;
          }
        }
      }

      items.removeWhere((item) => item.y > 1.1);

      for (var popup in popups) {
        popup.y -= 0.006;
        popup.life--;
      }
      popups.removeWhere((popup) => popup.life <= 0);

      if (tickCounter % 90 == 0) {
        speed += 0.0008;

        if (speed > 0.024) {
          speed = 0.024;
        }
      }

      if (tickCounter % 15 == 0) {
        score += 1;
      }

      if (score > highestScore) {
        highestScore = score;
      }
    });
  }

  void arrestPlayer() {
    isArrested = true;

    policeLane = playerLane;
    policeY = playerY + 0.02;

    _shakeController.forward(from: 0);

    gameOver();
  }

  void gameOver() {
    isGameOver = true;

    if (score > highestScore) {
      highestScore = score;
    }

    gameTimer?.cancel();

    // Background music keeps playing under the game-over screen -
    // only the gameover sting plays on top of it, it doesn't replace it.
    SoundManager.playGameOver();

    _gameOverController.forward(from: 0);
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

  void handleVerticalSwipe(double difference) {
    const double swipeThreshold = 25;

    // Negative difference means the finger moved UP the screen.
    if (difference < -swipeThreshold) {
      triggerJump();
    }
  }

  void triggerJump() {
    if (isGameOver || isJumping) return;

    setState(() {
      isJumping = true;
      jumpTick = 0;

      // Police will mimic the jump a short moment later,
      // like it's reacting to the player.
      pendingPoliceJumpDelay = 6;
    });

    SoundManager.playJump();
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
    _shakeController.dispose();
    _scoreBumpController.dispose();
    _gameOverController.dispose();
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

  // Calculates how many pixels to lift a jumping character,
  // using a smooth sine arc: 0 -> up -> 0 across jumpDuration ticks.
  double _jumpArc(int tick) {
    double progress = tick / jumpDuration;
    return sin(pi * progress) * jumpHeight;
  }

  // Squash-and-stretch factors for the player while jumping: a quick
  // squash on takeoff/landing and a gentle stretch mid-air, anchored
  // at the character's feet so it reads as a real jump, not a float.
  Offset _squashStretch(int tick, bool jumping) {
    if (!jumping) return const Offset(1.0, 1.0);

    final progress = tick / jumpDuration;
    double scaleY = 1.0;

    if (progress < 0.15) {
      final t = progress / 0.15;
      scaleY = 1.0 - 0.18 * sin(t * pi);
    } else if (progress > 0.85) {
      final t = (progress - 0.85) / 0.15;
      scaleY = 1.0 - 0.18 * sin(t * pi);
    } else {
      scaleY = 1.06;
    }

    final scaleX = 2.0 - scaleY;
    return Offset(scaleX, scaleY);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final laneWidth = size.width / laneCount;

    final roadWidth = laneWidth * laneCount;

    final double playerJumpOffset = isJumping ? _jumpArc(jumpTick) : 0;
    final double policeJumpOffset = policeIsJumping
        ? _jumpArc(policeJumpTick)
        : 0;

    final Offset playerSquash = _squashStretch(jumpTick, isJumping);

    // Decaying oscillation for the screen shake, driven purely by
    // _shakeController.value so it works whether or not the main
    // game timer is still running.
    final double shakeT = _shakeController.value;
    final double shakeDx = sin(shakeT * pi * 10) * (1 - shakeT) * 14;
    final double flashOpacity = shakeT > 0 ? (1 - shakeT) * 0.28 : 0.0;

    return Scaffold(
      backgroundColor: const Color(0xFF2E7D32),

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

        child: Transform.translate(
          offset: Offset(shakeDx, 0),
          child: Stack(
            children: [
              // Grass background with a subtle vertical gradient for depth
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.green[800]!, Colors.green[600]!],
                    ),
                  ),
                ),
              ),

              // Road surface with a soft gradient + side curbs for depth
              Positioned(
                left: 0,
                top: 0,
                width: roadWidth,
                height: size.height,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.grey[900]!,
                        Colors.grey[800]!,
                        Colors.grey[850]!,
                        Colors.grey[900]!,
                      ],
                      stops: const [0.0, 0.05, 0.95, 1.0],
                    ),
                  ),
                ),
              ),

              // Left/right road curbs (striped)
              Positioned(
                left: 0,
                top: 0,
                width: 6,
                height: size.height,
                child: Container(color: Colors.amber[700]),
              ),
              Positioned(
                left: roadWidth - 6,
                top: 0,
                width: 6,
                height: size.height,
                child: Container(color: Colors.amber[700]),
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

              // Floating "+10" popups when coins are collected - pop in
              // with a small overshoot, then float up and fade.
              ...popups.map((popup) {
                final opacity = (popup.life / FloatingPopup.maxLife).clamp(
                  0.0,
                  1.0,
                );
                return Positioned(
                  left: popup.x * laneWidth + laneWidth / 2 - 20,
                  top: popup.y * size.height,
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.scale(
                      scale: popup.scale,
                      child: Text(
                        popup.text,
                        style: const TextStyle(
                          color: Colors.amberAccent,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(color: Colors.black87, blurRadius: 4),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }),

              // Police - lifts up when policeIsJumping is active
              Positioned(
                left: policeLane * laneWidth + laneWidth / 2 - 27,
                top: policeY * size.height - policeJumpOffset,
                child: safeImage(
                  'assets/game/police.png',
                  width: 55,
                  height: 55,
                ),
              ),

              // Player - lifts up when isJumping is active, with a
              // squash-and-stretch anchored at the feet.
              Positioned(
                left: playerLane * laneWidth + laneWidth / 2 - 30,
                top: playerY * size.height - playerJumpOffset,
                child: Transform(
                  alignment: Alignment.bottomCenter,
                  transform: Matrix4.diagonal3Values(
                    playerSquash.dx,
                    playerSquash.dy,
                    1.0,
                  ),
                  child: safeImage(
                    'assets/game/character.gif',
                    width: 60,
                    height: 60,
                  ),
                ),
              ),

              // Red flash + shake feedback right at the moment of arrest
              if (flashOpacity > 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      color: Colors.red.withValues(alpha: flashOpacity),
                    ),
                  ),
                ),

              Positioned(
                top: 44,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt, color: Colors.white, size: 18),
                          const SizedBox(width: 4),
                          Transform.scale(
                            scale: _scoreBumpAnimation.value,
                            child: Text(
                              '$score',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.emoji_events,
                            color: Colors.amber,
                            size: 15,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$highestScore',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              if (isGameOver)
                Opacity(
                  opacity: Curves.easeIn.transform(_gameOverController.value),
                  child: Container(
                    color: Colors.black87,
                    width: size.width,
                    height: size.height,
                    child: Center(
                      child: Transform.scale(
                        scale: Curves.elasticOut.transform(
                          _gameOverController.value,
                        ),
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
                            if (score >= highestScore)
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
                                elevation: 6,
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
                  ),
                ),
            ],
          ),
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
