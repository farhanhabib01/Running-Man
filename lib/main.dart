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
                    (_controller.value * _speeds[i] + _startOffsets[i]) %
                        1.0;
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

// ==========================================
// RADAR RING PAINTER
// A dashed circular ring that spins slowly behind the start-screen
// logo, giving it a "badge / radar" feel that matches the police
// chase theme.
// ==========================================
class _RadarRingPainter extends CustomPainter {
  final Color color;
  _RadarRingPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const dashCount = 20;

    for (int i = 0; i < dashCount; i++) {
      if (i.isEven) {
        final startAngle = (2 * pi / dashCount) * i;
        const sweep = (2 * pi / dashCount) * 0.6;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweep,
          false,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _RadarRingPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen>
    with TickerProviderStateMixin {
  // Logo idle bounce
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  // Entrance animation for title + logo when the screen first opens
  late AnimationController _introController;
  late Animation<double> _titleFade;
  late Animation<double> _titleSlide;
  late Animation<double> _logoFade;
  late Animation<double> _logoScale;
  late Animation<double> _logoRotate;
  late Animation<double> _bottomFade;
  late Animation<double> _bottomSlide;

  // Gentle pulsing on the PLAY button so it draws the eye once ready
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Slow ambient background gradient shift
  late AnimationController _bgController;

  // Radar-style ripple rings pulsing outward behind the logo
  late AnimationController _glowController;

  // Slow continuous rotation for the dashed radar ring
  late AnimationController _ringRotateController;

  // Shine sweep used on the title text and the loading bar
  late AnimationController _shimmerController;

  double loadingProgress = 0.0;
  bool isLoaded = false;

  Timer? loadingTimer;

  @override
  void initState() {
    super.initState();

    // Preload all sounds now, in parallel with the loading bar below,
    // so there is zero delay the first time a sound is triggered.
    SoundManager.preload();

    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: 0, end: 14).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
    );

    // Staggered opening sequence: title first, then the logo spins and
    // pops in, then the bottom controls slide up into place.
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

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _ringRotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

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
    _glowController.dispose();
    _ringRotateController.dispose();
    _shimmerController.dispose();
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

  // One expanding, fading ripple ring - two of these offset in phase
  // create a continuous "radar ping" effect behind the logo.
  Widget _buildGlowRing(double phase) {
    final t = (_glowController.value + phase) % 1.0;
    final scale = 0.55 + t * 0.9;
    final opacity = (1 - t) * 0.32;

    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: 132,
          height: 132,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.amberAccent, width: 2),
          ),
        ),
      ),
    );
  }

  // The app icon/logo itself, glossy-badge styled, with a graceful
  // fallback if the asset is missing.
  Widget _buildLogoImage() {
    return ClipOval(
      child: Container(
        width: 118,
        height: 118,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withValues(alpha: 0.55),
              blurRadius: 22,
              spreadRadius: 2,
            ),
            const BoxShadow(
              color: Colors.black45,
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Image.asset(
          'assets/icon/icon.png',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.amber, Colors.deepOrange],
                ),
              ),
              child: const Icon(
                Icons.local_police_rounded,
                color: Colors.white,
                size: 62,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoadingBar() {
    return Column(
      key: const ValueKey('loading'),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 14,
            child: Stack(
              children: [
                LinearProgressIndicator(
                  value: loadingProgress,
                  minHeight: 14,
                  backgroundColor: Colors.black26,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Colors.amber,
                  ),
                ),
                // Shine sweep gliding across the bar for a polished,
                // "still working" feel while it fills up.
                AnimatedBuilder(
                  animation: _shimmerController,
                  builder: (context, child) {
                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final w = constraints.maxWidth;
                        final dx = -w + (_shimmerController.value * 2 * w);
                        return ClipRect(
                          child: Transform.translate(
                            offset: Offset(dx, 0),
                            child: Container(
                              width: w * 0.28,
                              height: 14,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0),
                                    Colors.white.withValues(alpha: 0.5),
                                    Colors.white.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
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

                  // Title with an entrance slide/fade AND a looping
                  // metallic shine sweep for a more "professional"
                  // game-logo feel.
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
                                  Colors.white,
                                  Colors.amberAccent,
                                  Colors.white,
                                ],
                                stops: const [0.35, 0.5, 0.65],
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
                      'RUNNER CHASE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                        shadows: [
                          Shadow(color: Colors.black45, blurRadius: 6),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(),

                  // Logo badge: idle bounce + radar ping rings + a
                  // slowly spinning dashed ring + a spin-and-pop
                  // entrance the first time the screen appears.
                  AnimatedBuilder(
                    animation: Listenable.merge([
                      _bounceAnimation,
                      _introController,
                      _glowController,
                      _ringRotateController,
                    ]),
                    builder: (context, child) {
                      return Opacity(
                        opacity: _logoFade.value,
                        child: Transform.translate(
                          offset: Offset(0, -_bounceAnimation.value),
                          child: Transform.rotate(
                            angle: _logoRotate.value,
                            child: Transform.scale(
                              scale: _logoScale.value,
                              child: SizedBox(
                                width: 170,
                                height: 170,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    _buildGlowRing(0.0),
                                    _buildGlowRing(0.5),
                                    Transform.rotate(
                                      angle:
                                          _ringRotateController.value *
                                          2 *
                                          pi,
                                      child: CustomPaint(
                                        size: const Size(150, 150),
                                        painter: _RadarRingPainter(
                                          color: Colors.white.withValues(
                                            alpha: 0.35,
                                          ),
                                        ),
                                      ),
                                    ),
                                    _buildLogoImage(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const Spacer(),

                  // Loading bar OR Play button, with a smooth cross-fade
                  // + scale transition between the two states, plus a
                  // slide-up entrance the first time it appears.
                  AnimatedBuilder(
                    animation: _introController,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _bottomFade.value,
                        child: Transform.translate(
                          offset: Offset(0, _bottomSlide.value),
                          child: child,
                        ),
                      );
                    },
                    child: Padding(
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
                              scale: Tween<double>(
                                begin: 0.85,
                                end: 1.0,
                              ).animate(
                                CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOutBack,
                                ),
                              ),
                              child: child,
                            ),
                          );
                        },
                        child: isLoaded
                            ? _buildPlayButton()
                            : _buildLoadingBar(),
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

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin {
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

  // Coin counter + level progression.
  int coins = 0;
  int highestCoins = 0;
  int level = 1;
  int highestLevel = 1;
  bool isNewHighScore = false;

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
  late AnimationController _shakeController; // screen shake + red flash on arrest
  late AnimationController _scoreBumpController; // score pop when coins are collected
  late Animation<double> _scoreBumpAnimation;
  late AnimationController _gameOverController; // entrance for the game-over card
  late AnimationController _gameOverPulseController; // subtle card glow/pulse

  @override
  void initState() {
    super.initState();

    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..addListener(() {
        if (mounted) setState(() {});
      });

    _scoreBumpController = AnimationController(
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

    _gameOverController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..addListener(() {
        if (mounted) setState(() {});
      });

    _gameOverPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    startGame();
  }

  void startGame() {
    gameTimer?.cancel();

    items.clear();
    popups.clear();

    score = 0;
    coins = 0;
    level = 1;
    isNewHighScore = false;
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
            coins += 1;
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

      // Every 10 collected coins = next level.
      final newLevel = (coins ~/ 10) + 1;
      if (newLevel != level) {
        level = newLevel;
      }

      if (score > highestScore) {
        highestScore = score;
      }
      if (coins > highestCoins) {
        highestCoins = coins;
      }
      if (level > highestLevel) {
        highestLevel = level;
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

    // Capture the record BEFORE updating it, so the banner is shown
    // only when this run actually beats the previous best.
    isNewHighScore = score > highestScore;

    if (score > highestScore) {
      highestScore = score;
    }
    if (coins > highestCoins) {
      highestCoins = coins;
    }
    if (level > highestLevel) {
      highestLevel = level;
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
    _gameOverPulseController.dispose();
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

  Widget _hudCard({required Widget child, double? width}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: child,
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

  Widget _resultStat(
    IconData icon,
    String label,
    String value,
    Color valueColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: valueColor, size: 20),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
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

              // =========================
              // PROFESSIONAL HUD
              // =========================
              Positioned(
                top: 42,
                left: 14,
                right: 14,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Score / best
                    Expanded(
                      child: _hudCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.bolt_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 5),
                                const Text(
                                  'SCORE',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Transform.scale(
                              scale: _scoreBumpAnimation.value,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                '$score',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 23,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'BEST  $highestScore',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Level
                    _hudCard(
                      width: 72,
                      child: Column(
                        children: [
                          const Icon(
                            Icons.bolt_rounded,
                            color: Colors.amberAccent,
                            size: 20,
                          ),
                          Text(
                            'LV $level',
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Coins
                    _hudCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Icon(
                                Icons.monetization_on_rounded,
                                color: Colors.amber,
                                size: 19,
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'COINS',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$coins',
                            style: const TextStyle(
                              color: Colors.amberAccent,
                              fontSize: 23,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'BEST  $highestCoins',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (isGameOver)
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _gameOverPulseController,
                    builder: (context, child) {
                      final t = Curves.easeInOut.transform(
                        _gameOverPulseController.value,
                      );
                      final overlayOpacity =
                          Curves.easeOut.transform(_gameOverController.value) *
                          0.88;

                      return Container(
                        color: Colors.black.withValues(alpha: overlayOpacity),
                        child: Center(
                          child: Opacity(
                            opacity: Curves.easeOut.transform(
                              _gameOverController.value,
                            ),
                            child: Transform.scale(
                              scale: 0.82 +
                                  0.18 *
                                      Curves.easeOutBack.transform(
                                        _gameOverController.value,
                                      ),
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                ),
                                padding: const EdgeInsets.fromLTRB(
                                  22,
                                  22,
                                  22,
                                  20,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      const Color(0xFF17202A),
                                      const Color(0xFF0B1118),
                                      Colors.red.shade900.withValues(
                                        alpha: 0.28,
                                      ),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(28),
                                  border: Border.all(
                                    color: Colors.redAccent.withValues(
                                      alpha: 0.55 + (t * 0.25),
                                    ),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.redAccent.withValues(
                                        alpha: 0.16 + (t * 0.12),
                                      ),
                                      blurRadius: 28 + (t * 8),
                                      spreadRadius: 2,
                                    ),
                                    const BoxShadow(
                                      color: Colors.black54,
                                      blurRadius: 24,
                                      offset: Offset(0, 12),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Animated arrest badge
                                    Transform.scale(
                                      scale: 0.96 + (t * 0.08),
                                      child: Container(
                                        width: 78,
                                        height: 78,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: RadialGradient(
                                            colors: [
                                              Colors.redAccent.withValues(
                                                alpha: 0.95,
                                              ),
                                              Colors.red.shade900,
                                            ],
                                          ),
                                          border: Border.all(
                                            color: Colors.white24,
                                            width: 2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.redAccent
                                                  .withValues(alpha: 0.35),
                                              blurRadius: 20,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          isArrested
                                              ? Icons.local_police_rounded
                                              : Icons.warning_amber_rounded,
                                          color: Colors.white,
                                          size: 42,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),

                                    Text(
                                      isArrested
                                          ? 'GAME OVER'
                                          : 'RUN ENDED',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 30,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 2,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isArrested
                                          ? 'YOU GOT CAUGHT!'
                                          : 'WATCH OUT NEXT TIME',
                                      style: TextStyle(
                                        color: Colors.redAccent.shade100,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                    const SizedBox(height: 20),

                                    // Result stats
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _resultStat(
                                            Icons.bolt_rounded,
                                            'SCORE',
                                            '$score',
                                            Colors.white,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _resultStat(
                                            Icons.monetization_on_rounded,
                                            'COINS',
                                            '$coins',
                                            Colors.amberAccent,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _resultStat(
                                            Icons.flash_on_rounded,
                                            'LEVEL',
                                            '$level',
                                            Colors.cyanAccent,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.055,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          14,
                                        ),
                                        border: Border.all(
                                          color: Colors.white.withValues(
                                            alpha: 0.08,
                                          ),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          const Text(
                                            'BEST COINS',
                                            style: TextStyle(
                                              color: Colors.white60,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                          Text(
                                            '$highestCoins',
                                            style: const TextStyle(
                                              color: Colors.amber,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          Container(
                                            width: 1,
                                            height: 18,
                                            color: Colors.white12,
                                          ),
                                          const Text(
                                            'BEST LEVEL',
                                            style: TextStyle(
                                              color: Colors.white60,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                          Text(
                                            '$highestLevel',
                                            style: const TextStyle(
                                              color: Colors.cyanAccent,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    if (isNewHighScore)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 13),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: const [
                                            Icon(
                                              Icons.emoji_events_rounded,
                                              color: Colors.amber,
                                              size: 18,
                                            ),
                                            SizedBox(width: 6),
                                            Text(
                                              'NEW HIGH SCORE!',
                                              style: TextStyle(
                                                color: Colors.amberAccent,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 1,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                    const SizedBox(height: 20),

                                    SizedBox(
                                      width: double.infinity,
                                      height: 52,
                                      child: ElevatedButton.icon(
                                        onPressed: restartGame,
                                        icon: const Icon(
                                          Icons.replay_rounded,
                                          size: 23,
                                        ),
                                        label: const Text(
                                          'PLAY AGAIN',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.amber,
                                          foregroundColor: Colors.black,
                                          elevation: 10,
                                          shadowColor: Colors.amber.withValues(
                                            alpha: 0.35,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(17),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
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