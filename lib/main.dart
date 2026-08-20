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
// Every coin collision uses a fresh low-latency player. This prevents
// stale player state from blocking sounds during repeated pickups,
// game over/restart, or after returning to the app.
//
// FIX (background music not playing):
// bg uses the default (MediaPlayer-backed) player mode, not
// lowLatency. On that mode, resume() only works on a player that
// has ALREADY been started at least once via play() and then
// paused - calling resume() on a player that was only ever
// setSourceAsset()'d (never actually played) does nothing on
// native side. That's why bg never made a sound while jump/coin
// (which use lowLatency mode) worked fine.
// Fix: the first call to playBackgroundMusic() uses play() to
// actually start it; every call after that (replays) uses the
// original fast seek(0)+resume() path. stopBackgroundMusic()
// resets the "started" flag so a later play again uses play().
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

  // Tracks whether bg has actually been started via play() at least
  // once. Needed because resume() is a no-op on a never-played
  // MediaPlayer-backed AudioPlayer.
  static bool _bgStarted = false;

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
      // If any asset is missing, the game should still run silently.
    } finally {
      _preloading = false;
    }
  }

  static Future<void> playBackgroundMusic() async {
    try {
      if (!_bgStarted) {
        // First ever start: must use play(), resume() won't work yet.
        await bg.play(AssetSource('sounds/background.mp3'));
        _bgStarted = true;
      } else {
        // Already started before (just paused/stopped-and-restarted
        // in-session) - fast path, no reload needed.
        await bg.seek(Duration.zero);
        await bg.resume();
      }
    } catch (_) {}
  }

  static Future<void> stopBackgroundMusic() async {
    try {
      await bg.stop();
      // stop() fully resets native player state, so next play must
      // go through play() again, not resume().
      _bgStarted = false;
    } catch (_) {}
  }

  // FIX (coin / jump / gameover sound stops working after a while,
  // or after restarting the game):
  // seek(0)+resume() only reliably replays a player that is already
  // in a "started then paused" state. In practice (especially after
  // the game restarts or many rapid replays happen) these effect
  // players can end up in a state where resume() silently does
  // nothing. stop() + play(source) always resets the player to a
  // clean state first and then starts fresh, so it works every
  // single time regardless of what happened before - this is the
  // reliable pattern for one-shot sound effects.
  // Every pickup gets its own temporary player. This avoids stale shared
  // player state, so repeated coins, game over/restart, and reopening the
  // app do not prevent the next successful coin hit from playing its sound.
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

// ==========================================
// POLICE SIREN BAR
// A slim strip of alternating red/blue light that sweeps back and
// forth, used at the very top and bottom of the start screen to
// give it a proper "police chase" cinematic frame.
// ==========================================
class _SirenBar extends StatelessWidget {
  final double t; // 0..1 animation progress
  final bool topBar;

  const _SirenBar({required this.t, required this.topBar});

  @override
  Widget build(BuildContext context) {
    // Two lobes of light chasing each other across the strip.
    final wave = (sin(t * 2 * pi) + 1) / 2; // 0..1
    return Container(
      height: 5,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.red.withValues(alpha: 0.15 + 0.65 * wave),
            Colors.blueAccent.withValues(alpha: 0.15 + 0.65 * (1 - wave)),
            Colors.red.withValues(alpha: 0.15 + 0.65 * wave),
            Colors.blueAccent.withValues(alpha: 0.15 + 0.65 * (1 - wave)),
          ],
          stops: const [0.0, 0.33, 0.66, 1.0],
        ),
      ),
    );
  }
}

// ==========================================
// SIREN GLOW OVERLAY
// A very soft full-screen red/blue wash that alternates slowly in
// the background, tying the whole start screen together without
// being distracting - sits behind all other UI.
// ==========================================
class _SirenGlowOverlay extends StatelessWidget {
  final double t; // 0..1

  const _SirenGlowOverlay({required this.t});

  @override
  Widget build(BuildContext context) {
    final wave = (sin(t * 2 * pi) + 1) / 2;
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.3),
            radius: 1.1,
            colors: [
              Color.lerp(
                Colors.blueAccent.withValues(alpha: 0.10),
                Colors.red.withValues(alpha: 0.10),
                wave,
              )!,
              Colors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// VIGNETTE
// Subtle edge-darkening so the center of the screen (logo + title)
// reads as the visual focus - a common cinematic/game-UI touch.
// ==========================================
class _Vignette extends StatelessWidget {
  const _Vignette();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.15,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.32)],
            stops: const [0.6, 1.0],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// SPARKLE PARTICLES
// Tiny twinkling dots drifting slowly upward in the background,
// giving the start screen a bit of ambient life/depth beyond the
// clouds - purely decorative.
// ==========================================
class _SparkleField extends StatelessWidget {
  final double t; // 0..1 looping progress

  const _SparkleField({required this.t});

  static final List<Offset> _seeds = List.generate(18, (i) {
    final rnd = Random(i * 97);
    return Offset(rnd.nextDouble(), rnd.nextDouble());
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          children: List.generate(_seeds.length, (i) {
            final seed = _seeds[i];
            final speed = 0.4 + (i % 5) * 0.15;
            final localT = (t * speed + seed.dx) % 1.0;
            final dy = h * (1 - localT);
            final dx = seed.dx * w + sin(localT * 4 * pi + i) * 10;
            final twinkle = (sin(t * 2 * pi * (2 + i % 3) + i) + 1) / 2;

            return Positioned(
              left: dx,
              top: dy,
              child: Opacity(
                opacity: 0.15 + twinkle * 0.35,
                child: Container(
                  width: 3,
                  height: 3,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

// ==========================================
// CITY SKYLINE SILHOUETTE
// A static row of building silhouettes with a handful of slowly
// blinking window lights, anchored to the bottom of the start
// screen. Adds depth and a "city at night, on the run" cinematic
// backdrop behind the clouds/logo without competing with them.
// ==========================================
class _SkylineSilhouette extends StatelessWidget {
  final double t; // 0..1 looping progress, drives window blink

  const _SkylineSilhouette({required this.t});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return CustomPaint(
            size: Size(constraints.maxWidth, 150),
            painter: _SkylinePainter(t: t),
          );
        },
      ),
    );
  }
}

class _SkylinePainter extends CustomPainter {
  final double t;
  _SkylinePainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final buildingPaint = Paint()..color = Colors.black.withValues(alpha: 0.38);
    final windowPaint = Paint();

    final rnd = Random(7);
    double x = -20;
    int seed = 0;

    while (x < size.width + 20) {
      final w = 34.0 + rnd.nextDouble() * 46;
      final h = 55.0 + rnd.nextDouble() * 85;
      final rect = Rect.fromLTWH(x, size.height - h, w, h);
      canvas.drawRect(rect, buildingPaint);

      // A sparse grid of windows, some blinking on a slow cycle.
      final cols = (w / 12).floor().clamp(1, 6);
      final rows = (h / 16).floor().clamp(1, 8);
      for (int r = 0; r < rows; r++) {
        for (int c = 0; c < cols; c++) {
          seed++;
          if (seed % 3 == 0) continue; // leave gaps, not every window lit
          final blink = (sin(t * 2 * pi * 1.3 + seed * 0.7) + 1) / 2; // 0..1
          final alpha = (0.10 + blink * 0.22).clamp(0.0, 0.32);
          windowPaint.color = Colors.amberAccent.withValues(alpha: alpha);
          canvas.drawRect(
            Rect.fromLTWH(rect.left + 6 + c * 12, rect.top + 8 + r * 16, 5, 8),
            windowPaint,
          );
        }
      }

      x += w + 6;
    }
  }

  @override
  bool shouldRepaint(covariant _SkylinePainter oldDelegate) {
    return oldDelegate.t != t;
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

  // Police-style red/blue siren sweep for the top/bottom bars and
  // the soft background glow wash.
  late AnimationController _sirenController;

  double loadingProgress = 0.0;
  bool isLoaded = false;

  Timer? loadingTimer;

  @override
  void initState() {
    super.initState();

    // Preload all sounds now, in parallel with the loading bar below,
    // so there is zero delay the first time a sound is triggered.
    // Background music starts as soon as it's ready, right here on
    // the loading screen, instead of waiting for the game to open.
    SoundManager.preload().then((_) {
      if (mounted) {
        SoundManager.playBackgroundMusic();
      }
    });

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

    _sirenController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
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
    _sirenController.dispose();
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
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
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
                  Color.lerp(Colors.green[900], Colors.green[700], t)!,
                  Color.lerp(Colors.teal[800], Colors.green[800], t)!,
                  Color.lerp(Colors.blueGrey[900], Colors.teal[900], t)!,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
            child: child,
          );
        },
        child: Stack(
          children: [
            const Positioned.fill(child: _FloatingClouds()),
            AnimatedBuilder(
              animation: _sirenController,
              builder: (context, _) {
                return Positioned.fill(
                  child: _SparkleField(t: _sirenController.value),
                );
              },
            ),
            AnimatedBuilder(
              animation: _sirenController,
              builder: (context, _) {
                return Positioned.fill(
                  child: _SirenGlowOverlay(t: _sirenController.value),
                );
              },
            ),
            AnimatedBuilder(
              animation: _sirenController,
              builder: (context, _) {
                return Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _SkylineSilhouette(t: _sirenController.value),
                );
              },
            ),
            const Positioned.fill(child: _Vignette()),
            // Top siren bar
            AnimatedBuilder(
              animation: _sirenController,
              builder: (context, _) {
                return Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _SirenBar(t: _sirenController.value, topBar: true),
                );
              },
            ),
            // Bottom siren bar
            AnimatedBuilder(
              animation: _sirenController,
              builder: (context, _) {
                return Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _SirenBar(t: _sirenController.value, topBar: false),
                );
              },
            ),
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
                        shadows: [Shadow(color: Colors.black45, blurRadius: 6)],
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Small tagline under the title, fading/sliding in
                  // together with the title above it.
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
                    child: Text(
                      'DODGE  •  COLLECT  •  ESCAPE',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 3,
                        shadows: const [
                          Shadow(color: Colors.black45, blurRadius: 4),
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
                                          _ringRotateController.value * 2 * pi,
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
                              scale: Tween<double>(begin: 0.85, end: 1.0)
                                  .animate(
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

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  static const int laneCount = 3;

  int playerLane = 1;
  double playerY = 0.7;

  // Smoothed visual-only lane position: the player's *logical* lane
  // (playerLane, used for all collision/gameplay checks) still
  // changes instantly on swipe, but the character glides toward it
  // on screen instead of teleporting - this is what makes lane
  // changes read as a real running motion instead of the character
  // just "popping" into place.
  double playerLaneAnim = 1.0;

  int policeLane = 1;
  double policeY = 0.9;
  double policeLaneAnim = 1.0;
  int policeLaneDelayCounter = 0;

  // Scroll offset for the roadside buildings/trees parallax layer.
  double sceneryOffset = 0;

  List<FallingItem> items = [];
  List<FloatingPopup> popups = [];
  List<_DustParticle> dustParticles = [];

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
  late AnimationController
  _shakeController; // screen shake + red flash on arrest
  late AnimationController
  _scoreBumpController; // score pop when coins are collected
  late Animation<double> _scoreBumpAnimation;
  late AnimationController
  _gameOverController; // entrance for the game-over card
  late AnimationController _gameOverPulseController; // subtle card glow/pulse

  // Level-up banner: pops in with the new level number whenever the
  // player crosses into a new level, then fades back out on its own.
  late AnimationController _levelUpController;

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
          duration: const Duration(milliseconds: 700),
        )..addListener(() {
          if (mounted) setState(() {});
        });

    _gameOverPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _levelUpController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 1400),
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
    coins = 0;
    level = 1;
    isNewHighScore = false;
    speed = 0.006;

    playerLane = 1;
    playerLaneAnim = 1.0;

    policeLane = 1;
    policeY = 0.9;
    policeLaneAnim = 1.0;
    policeLaneDelayCounter = 0;
    sceneryOffset = 0;
    dustParticles.clear();

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
    _levelUpController.reset();

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

      sceneryOffset += speed * 260;
      if (sceneryOffset > _SceneryPainter.patternHeight) {
        sceneryOffset -= _SceneryPainter.patternHeight;
      }

      // Ease the on-screen lane position toward the logical lane -
      // this is what turns an instant lane swap into a smooth glide.
      playerLaneAnim += (playerLane - playerLaneAnim) * 0.28;
      policeLaneAnim += (policeLane - policeLaneAnim) * 0.22;

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

      // Kick up a small dust puff behind the player's feet every
      // few ticks while running on the ground - skipped mid-air so
      // it doesn't look like the character is dragging dust through
      // the sky during a jump.
      if (!isJumping && tickCounter % 5 == 0) {
        dustParticles.add(
          _DustParticle(
            laneAnim: playerLaneAnim,
            y: playerY,
            drift: random.nextDouble() * 10 - 5,
          ),
        );
      }
      for (var dust in dustParticles) {
        dust.life--;
      }
      dustParticles.removeWhere((dust) => dust.life <= 0);

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
        _levelUpController.forward(from: 0);
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
    _levelUpController.dispose();
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

  // Wraps buildItemWidget() with a grounding shadow underneath and,
  // for cars, a fading motion-blur trail behind them - small touches
  // that make oncoming traffic read as fast and "real" rather than
  // flat sprites falling down the screen.
  Widget _buildItemVisual(FallingItem item) {
    switch (item.type) {
      case ItemType.car:
        return Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            // Speed-blur streaks trailing above the car (the
            // direction it came from), strength scales with speed.
            if (speed > 0.010)
              Positioned(
                top: -34 * ((speed - 0.006) / 0.018).clamp(0.0, 1.0) - 6,
                child: Opacity(
                  opacity: (0.5 * ((speed - 0.006) / 0.018)).clamp(0.0, 0.5),
                  child: Container(
                    width: 30,
                    height: 34 * ((speed - 0.006) / 0.018).clamp(0.2, 1.0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0),
                          Colors.white.withValues(alpha: 0.35),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                width: 46,
                height: 13,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.30),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -8),
              child: buildItemWidget(item),
            ),
          ],
        );

      case ItemType.barricade:
      case ItemType.bush:
        // A gentle side-to-side sway, phase offset per item, so a
        // row of hurdles doesn't feel like a static wall.
        final sway = sin((tickCounter + item.hashCode) * 0.06) * 2.5;
        return Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 44),
              child: Container(
                width: 50,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.26),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(sway, 0),
              child: buildItemWidget(item),
            ),
          ],
        );

      case ItemType.coin:
        return buildItemWidget(item);
    }
  }

  Widget buildItemWidget(FallingItem item) {
    switch (item.type) {
      case ItemType.coin:
        // Gentle bob + a soft glow ring behind the coin, phase offset
        // per-coin (via its hashCode) so a row of coins doesn't bob
        // in perfect unison - reads as more alive/professional.
        final wobble = sin((tickCounter + item.hashCode) * 0.15) * 4;
        final glowPulse = (sin((tickCounter + item.hashCode) * 0.08) + 1) / 2;
        return Transform.translate(
          offset: Offset(0, wobble),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Colors.amberAccent.withValues(
                        alpha: 0.22 + glowPulse * 0.18,
                      ),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
              safeImage('assets/game/coin.png', width: 45, height: 45),
            ],
          ),
        );

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
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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

    // The road no longer spans the full screen width - narrowing it
    // leaves real grass strips on both sides for the scrolling
    // scenery (buildings/trees) to actually be visible in, instead
    // of being fully hidden behind an edge-to-edge road.
    final roadWidth = size.width * 0.82;
    final laneWidth = roadWidth / laneCount;
    final roadLeft = (size.width - roadWidth) / 2;

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

              // Roadside scenery (buildings/trees) scrolling in the
              // grass strips on either side of the road - adds
              // parallax depth and a stronger sense of forward speed.
              Positioned(
                left: 0,
                top: 0,
                width: roadLeft,
                height: size.height,
                child: CustomPaint(
                  painter: _SceneryPainter(offset: sceneryOffset, isLeft: true),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                width: roadLeft,
                height: size.height,
                child: CustomPaint(
                  painter: _SceneryPainter(
                    offset: sceneryOffset,
                    isLeft: false,
                  ),
                ),
              ),

              // Road surface with a soft gradient + side curbs for depth
              Positioned(
                left: roadLeft,
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
                left: roadLeft,
                top: 0,
                width: 6,
                height: size.height,
                child: Container(color: Colors.amber[700]),
              ),
              Positioned(
                left: roadLeft + roadWidth - 6,
                top: 0,
                width: 6,
                height: size.height,
                child: Container(color: Colors.amber[700]),
              ),

              ...List.generate(laneCount - 1, (index) {
                double dividerLeft = roadLeft + (index + 1) * laneWidth;

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
                  left: roadLeft + item.lane * laneWidth + laneWidth / 2 - 40,
                  top: item.y * size.height,
                  child: _buildItemVisual(item),
                );
              }),

              // Dust puffs kicked up behind the player's feet while
              // running - small fading grey circles that drift and
              // shrink, giving the ground contact a bit of life.
              ...dustParticles.map((dust) {
                final opacity =
                    (dust.life / _DustParticle.maxLife).clamp(0.0, 1.0) * 0.35;
                final progress = 1 - (dust.life / _DustParticle.maxLife);
                return Positioned(
                  left:
                      roadLeft +
                      dust.laneAnim * laneWidth +
                      laneWidth / 2 -
                      6 +
                      dust.drift * progress,
                  top: dust.y * size.height + 40 - (progress * 14),
                  child: Opacity(
                    opacity: opacity,
                    child: Container(
                      width: 10 + progress * 8,
                      height: 10 + progress * 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
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
                  left: roadLeft + popup.x * laneWidth + laneWidth / 2 - 20,
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

              // Ground shadows for player and police - grounds them
              // visually and squashes/fades while airborne, a classic
              // runner-game polish touch.
              Positioned(
                left:
                    roadLeft + policeLaneAnim * laneWidth + laneWidth / 2 - 22,
                top: policeY * size.height - policeJumpOffset + 48,
                child: Opacity(
                  opacity: (0.30 * (1 - (policeJumpOffset / jumpHeight) * 0.75))
                      .clamp(0.06, 0.30),
                  child: Transform.scale(
                    scale: (1 - (policeJumpOffset / jumpHeight) * 0.4).clamp(
                      0.5,
                      1.0,
                    ),
                    child: Container(
                      width: 40,
                      height: 11,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left:
                    roadLeft + playerLaneAnim * laneWidth + laneWidth / 2 - 24,
                top: playerY * size.height - playerJumpOffset + 52,
                child: Opacity(
                  opacity: (0.32 * (1 - (playerJumpOffset / jumpHeight) * 0.75))
                      .clamp(0.06, 0.32),
                  child: Transform.scale(
                    scale: (1 - (playerJumpOffset / jumpHeight) * 0.4).clamp(
                      0.5,
                      1.0,
                    ),
                    child: Container(
                      width: 44,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ),

              // Police - lifts up when policeIsJumping is active
              Positioned(
                left:
                    roadLeft + policeLaneAnim * laneWidth + laneWidth / 2 - 27,
                top: policeY * size.height - policeJumpOffset,
                child: safeImage(
                  'assets/game/police.png',
                  width: 55,
                  height: 55,
                ),
              ),

              // Flashing red/blue siren light above the police car -
              // sells the "pursuit" theme at a glance.
              Positioned(
                left:
                    roadLeft + policeLaneAnim * laneWidth + laneWidth / 2 - 10,
                top: policeY * size.height - policeJumpOffset - 12,
                child: Builder(
                  builder: (context) {
                    final onRed = (tickCounter ~/ 8) % 2 == 0;
                    final sirenColor = onRed
                        ? Colors.redAccent
                        : Colors.blueAccent;
                    return Container(
                      width: 20,
                      height: 9,
                      decoration: BoxDecoration(
                        color: sirenColor,
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: [
                          BoxShadow(
                            color: sirenColor.withValues(alpha: 0.85),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Player - lifts up when isJumping is active, with a
              // squash-and-stretch anchored at the feet, a small
              // continuous running bob while grounded, and a lean
              // that tilts into whichever direction it's currently
              // gliding toward its target lane.
              Positioned(
                left:
                    roadLeft + playerLaneAnim * laneWidth + laneWidth / 2 - 30,
                top:
                    playerY * size.height -
                    playerJumpOffset -
                    (isJumping ? 0 : (sin(tickCounter * 0.35) + 1) * 2.5),
                child: Transform.rotate(
                  angle: ((playerLane - playerLaneAnim) * -0.5).clamp(
                    -0.22,
                    0.22,
                  ),
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
              ),

              // Speed-lines overlay - fades in once the chase has
              // ramped up, reinforcing how fast things have gotten.
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _SpeedLinesPainter(
                      intensity: (((speed - 0.006) / (0.024 - 0.006)) - 0.35)
                          .clamp(0.0, 1.0),
                      phase: (tickCounter % 60) / 60,
                    ),
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

              // Level-up banner - pops in briefly whenever the player
              // reaches a new level, then fades away on its own.
              if (_levelUpController.value > 0)
                Positioned(
                  top: 118,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Builder(
                      builder: (context) {
                        final v = _levelUpController.value;
                        double opacity;
                        double scale;
                        if (v < 0.25) {
                          final t = v / 0.25;
                          opacity = t;
                          scale = 0.7 + 0.3 * Curves.easeOutBack.transform(t);
                        } else if (v < 0.7) {
                          opacity = 1.0;
                          scale = 1.0;
                        } else {
                          final t = (v - 0.7) / 0.3;
                          opacity = (1 - t).clamp(0.0, 1.0);
                          scale = 1.0;
                        }
                        return Opacity(
                          opacity: opacity.clamp(0.0, 1.0),
                          child: Center(
                            child: Transform.scale(
                              scale: scale,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Colors.amber, Colors.deepOrange],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.amber.withValues(
                                        alpha: 0.55,
                                      ),
                                      blurRadius: 22,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.flash_on_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'LEVEL $level',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.2,
                                        shadows: [
                                          Shadow(
                                            color: Colors.black38,
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
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
                              scale:
                                  0.82 +
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
                                      isArrested ? 'GAME OVER' : 'RUN ENDED',
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
                                        borderRadius: BorderRadius.circular(14),
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
                                            borderRadius: BorderRadius.circular(
                                              17,
                                            ),
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

// ==========================================
// ROADSIDE SCENERY
// Scrolling building/tree silhouettes painted in the grass strips
// on either side of the road. Purely decorative, driven by a
// scroll offset that advances with game speed - gives the whole
// scene a sense of depth and forward motion instead of a flat
// green background.
// ==========================================
class _SceneryPainter extends CustomPainter {
  final double offset;
  final bool isLeft;
  static const double patternHeight = 240.0;

  _SceneryPainter({required this.offset, required this.isLeft});

  @override
  void paint(Canvas canvas, Size size) {
    final buildingPaint = Paint()
      ..color = Colors.blueGrey.shade900.withValues(alpha: 0.55);
    final windowPaint = Paint()
      ..color = Colors.amberAccent.withValues(alpha: 0.30);
    final treeTopPaint = Paint()
      ..color = Colors.green.shade900.withValues(alpha: 0.55);
    final trunkPaint = Paint()
      ..color = Colors.brown.shade800.withValues(alpha: 0.55);

    double startY = -patternHeight + (offset % patternHeight);
    int i = 0;

    while (startY < size.height) {
      final isBuilding = (i + (isLeft ? 0 : 1)).isEven;

      if (isBuilding) {
        final w = size.width * 0.68;
        final h = 92.0;
        final rect = Rect.fromLTWH(
          isLeft ? size.width - w : 0,
          startY + 30,
          w,
          h,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)),
          buildingPaint,
        );

        for (int r = 0; r < 3; r++) {
          for (int c = 0; c < 2; c++) {
            canvas.drawRect(
              Rect.fromLTWH(
                rect.left + 8 + c * (w / 2),
                rect.top + 10 + r * 26,
                w / 2 - 16,
                13,
              ),
              windowPaint,
            );
          }
        }
      } else {
        final cx = isLeft ? size.width * 0.72 : size.width * 0.28;
        final cy = startY + 78;
        canvas.drawRect(Rect.fromLTWH(cx - 3, cy + 16, 6, 20), trunkPaint);
        canvas.drawCircle(Offset(cx, cy), 24, treeTopPaint);
        canvas.drawCircle(Offset(cx - 10, cy + 8), 16, treeTopPaint);
      }

      startY += patternHeight;
      i++;
    }
  }

  @override
  bool shouldRepaint(covariant _SceneryPainter oldDelegate) {
    return oldDelegate.offset != offset;
  }
}

// ==========================================
// SPEED LINES
// Faint streaks racing down from the edges of the screen once the
// game has ramped up past moderate speed - a classic "going fast"
// cue that kicks in gradually rather than being always-on.
// ==========================================
class _SpeedLinesPainter extends CustomPainter {
  final double intensity; // 0..1
  final double phase; // 0..1 looping

  _SpeedLinesPainter({required this.intensity, required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    if (intensity <= 0) return;

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16 * intensity)
      ..strokeWidth = 2;

    final rnd = Random(3);
    for (int i = 0; i < 10; i++) {
      final fromLeft = i.isEven;
      final baseX = fromLeft
          ? rnd.nextDouble() * size.width * 0.22
          : size.width - rnd.nextDouble() * size.width * 0.22;
      final speedT = (phase * (1.2 + (i % 4) * 0.3) + i * 0.13) % 1.0;
      final len = 40.0 + intensity * 60;
      final y = speedT * (size.height + len) - len;

      canvas.drawLine(
        Offset(baseX, y),
        Offset(baseX + (fromLeft ? -8 : 8), y + len),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpeedLinesPainter oldDelegate) {
    return oldDelegate.intensity != intensity || oldDelegate.phase != phase;
  }
}

// A short-lived dust puff kicked up behind the player's feet while
// running (not while airborne) - a small, classic runner-game touch
// that sells the sense of speed on the ground.
class _DustParticle {
  double laneAnim;
  double y;
  double drift;
  int life;
  static const int maxLife = 20;

  _DustParticle({
    required this.laneAnim,
    required this.y,
    required this.drift,
    this.life = maxLife,
  });
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
