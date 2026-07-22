import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;
import 'dart:js' as js;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'domain/board.dart';
import 'domain/game_controller.dart';
import 'domain/shop.dart';

void updateMusicPlayback() {
  bool enabled = Shop.instance.getSoundEnabled();
  if (kIsWeb) {
    try {
      if (enabled) {
        js.context.callMethod('playBackgroundMusic');
      } else {
        js.context.callMethod('pauseBackgroundMusic');
      }
    } catch (e) {
      print("Javascript music play error: $e");
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Shop.instance.initializeShop();
  if (kIsWeb) {
    try {
      js.context.callMethod('removeLoader');
    } catch (_) {}
  }
  runApp(
    const GlobalErrorBoundary(
      child: YutApp(),
    ),
  );
}

class GlobalErrorBoundary extends StatefulWidget {
  final Widget child;
  const GlobalErrorBoundary({super.key, required this.child});

  @override
  State<GlobalErrorBoundary> createState() => _GlobalErrorBoundaryState();
}

class _GlobalErrorBoundaryState extends State<GlobalErrorBoundary> {
  String? _error;
  String? _stackTrace;

  @override
  void initState() {
    super.initState();

    // Catch rendering and layout errors
    ErrorWidget.builder = (FlutterErrorDetails details) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _error == null) {
          setState(() {
            _error = details.exception.toString();
            _stackTrace = details.stack.toString();
          });
        }
      });
      return const SizedBox();
    };

    // Catch framework, gesture and button click exceptions
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details); // also present in developer console
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _error == null) {
          setState(() {
            _error = details.exception.toString();
            _stackTrace = details.stack.toString();
          });
        }
      });
    };

    // Catch click/callback/async exceptions
    ui.PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _error = error.toString();
            _stackTrace = stack.toString();
          });
        }
      });
      return true;
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return MaterialApp(
        title: 'Yut Game - Crash Log',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF1E262C),
        ),
        home: Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "GLOBAL RUNTIME EXCEPTION CAUGHT",
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 20),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    _error!,
                    style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  SelectableText(
                    _stackTrace ?? "",
                    style: const TextStyle(color: Colors.white70, fontSize: 11, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return widget.child;
  }
}

class YutApp extends StatelessWidget {
  const YutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GameController(isComputerPlaying: true),
      child: MaterialApp(
        title: 'Yut Game',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: const Color(0xFF56AFC1),
          scaffoldBackgroundColor: const Color(0xFF1E262C),
          fontFamily: 'Roboto',
        ),
        home: const TitleScreen(),
      ),
    );
  }
}

// ============================================================================
// TITLE SCREEN
// ============================================================================
class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key});

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen> with SingleTickerProviderStateMixin {
  late AnimationController _ticker;
  final List<Snowflake> _snowflakes = [];
  final double _snowHeight = 800;
  final double _snowWidth = 600;

  bool _isMenuShifted = false; // Controls sliding translation of menu panels

  @override
  void initState() {
    super.initState();
    _ticker = AnimationController(vsync: this, duration: const Duration(seconds: 10))
      ..addListener(_tickSnow)
      ..repeat();

    final rand = Random();
    for (int i = 0; i < 40; i++) {
      _snowflakes.add(
        Snowflake(
          x: rand.nextDouble() * _snowWidth,
          y: rand.nextDouble() * _snowHeight,
          speed: 25 + rand.nextDouble() * 40,
          radius: 1.5 + rand.nextDouble() * 3,
        ),
      );
    }
  }

  void _tickSnow() {
    setState(() {
      for (var flake in _snowflakes) {
        flake.y += flake.speed * 0.016; // Assumes ~60fps ticks
        if (flake.y > _snowHeight) {
          flake.y = -10;
          flake.x = Random().nextDouble() * _snowWidth;
        }
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final controller = Provider.of<GameController>(context);

    // Pick background depending on the time of day
    final hour = DateTime.now().hour;
    String bgAsset = "assets/images/backgroundnoon.png";
    if (hour < 5 || hour >= 21) {
      bgAsset = "assets/images/backgroundnight.png";
    } else if ((hour >= 5 && hour < 9) || (hour >= 18 && hour < 21)) {
      bgAsset = "assets/images/backgrounddawn.png";
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        updateMusicPlayback();
      },
      child: Scaffold(
        body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.asset(
              bgAsset,
              fit: BoxFit.cover,
            ),
          ),
          
          // Snowflake Animation Overlay
          Positioned.fill(
            child: CustomPaint(
              painter: SnowPainter(_snowflakes, _snowWidth, _snowHeight),
            ),
          ),

          // Content Wrapper
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Container(
                  width: min(size.width, 500),
                  height: max(size.height * 0.9, 650),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Game Logo
                      Hero(
                        tag: 'logo',
                        child: Container(
                          height: 180,
                          decoration: const BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage("assets/images/yut.png"),
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),

                      // Sound Quick-Toggle
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: Icon(
                              controller.soundOn ? Icons.volume_up : Icons.volume_off,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: () {
                              controller.toggleSound();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(controller.soundOn ? "Sound Unmuted" : "Sound Muted"),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
                          ),
                        ],
                      ),

                      // Sliding Menu Panels
                      SizedBox(
                        height: 300,
                        child: Stack(
                          children: [
                            // Main Panel
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOut,
                              left: _isMenuShifted ? -500 : 0,
                              right: _isMenuShifted ? 500 : 0,
                              child: Column(
                                children: [
                                  _menuButton("START GAME", () {
                                    setState(() => _isMenuShifted = true);
                                  }),
                                  const SizedBox(height: 16),
                                  _menuButton("AVATAR SHOP", () => _showShopDialog(context)),
                                  const SizedBox(height: 16),
                                  _menuButton("HOW TO PLAY", () => _showHowToPlayDialog(context)),
                                  const SizedBox(height: 16),
                                  _menuButton("OPTIONS", () => _showOptionsDialog(context)),
                                ],
                              ),
                            ),

                            // Play Mode Panel (Slides in)
                            AnimatedPositioned(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOut,
                              left: _isMenuShifted ? 0 : 500,
                              right: _isMenuShifted ? 0 : -500,
                              child: Column(
                                children: [
                                  _menuButton("VS COMPUTER", () {
                                    controller.isComputerPlaying = true;
                                    controller.resetGame();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const GameScreen()),
                                    );
                                  }),
                                  const SizedBox(height: 16),
                                  _menuButton("LOCAL 2 PLAYERS", () {
                                    controller.isComputerPlaying = false;
                                    controller.resetGame();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const GameScreen()),
                                    );
                                  }),
                                  const SizedBox(height: 16),
                                  _menuButton("BACK", () {
                                    setState(() => _isMenuShifted = false);
                                  }, isSecondary: true),
                                ],
                              ),
                            ),
                          ],
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
    );
  }

  Widget _menuButton(String text, VoidCallback onPressed, {bool isSecondary = false}) {
    return Container(
      width: double.infinity,
      height: 52,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isSecondary ? const Color(0xFF455A64) : const Color(0xFF56AFC1),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        onPressed: onPressed,
        child: Text(text),
      ),
    );
  }

  // ============================================================================
  // SHOP DIALOG (Persisted)
  // ============================================================================
  void _showShopDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final shop = Shop.instance;
            final coins = shop.getCoins();
            final unlocked = shop.getUnlockedAvatars();
            final selected = shop.getSelectedAnimals();

            return AlertDialog(
              backgroundColor: const Color(0xFF2C3E50),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Avatar Shop", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1C40F),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.monetization_on, color: Colors.black, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          "$coins",
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 380,
                child: ListView(
                  children: shop.costs.keys.map((animal) {
                    bool isOwn = shop.isUnlocked(animal);
                    int cost = shop.costs[animal]!;
                    bool isP1Selected = selected[0] == animal;
                    bool isP2Selected = selected[1] == animal;

                    return Card(
                      color: const Color(0xFF34495E),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            // Icon Avatar Image
                            Image.asset(
                              shop.getIconImagePath(animal),
                              width: 44,
                              height: 44,
                              errorBuilder: (_, __, ___) => const Icon(Icons.pets, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    animal,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  const SizedBox(height: 4),
                                  if (!isOwn)
                                    Row(
                                      children: [
                                        const Icon(Icons.monetization_on, color: Colors.amber, size: 14),
                                        const SizedBox(width: 2),
                                        Text("$cost coins", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                                      ],
                                    )
                                  else
                                    const Text("Unlocked", style: TextStyle(color: Colors.green, fontSize: 12)),
                                ],
                              ),
                            ),

                            // Actions: Purchase or Select
                            if (!isOwn)
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF27AE60)),
                                onPressed: coins >= cost
                                    ? () {
                                        if (shop.makePurchase(animal)) {
                                          setDialogState(() {});
                                          setState(() {}); // refresh title
                                        }
                                      }
                                    : null,
                                child: const Text("BUY"),
                              )
                            else
                              Row(
                                children: [
                                  Column(
                                    children: [
                                      const Text("P1", style: TextStyle(color: Colors.cyan, fontSize: 10)),
                                      Checkbox(
                                        value: isP1Selected,
                                        activeColor: Colors.cyan,
                                        onChanged: (val) async {
                                          if (val == true) {
                                            if (selected[1] == animal) {
                                              shop.switchAvatars();
                                            } else {
                                              shop.changeAvatar(0, animal);
                                            }
                                            await shop.saveAvatars();
                                            setDialogState(() {});
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                  Column(
                                    children: [
                                      const Text("P2", style: TextStyle(color: Colors.orange, fontSize: 10)),
                                      Checkbox(
                                        value: isP2Selected,
                                        activeColor: Colors.orange,
                                        onChanged: (val) async {
                                          if (val == true) {
                                            if (selected[0] == animal) {
                                              shop.switchAvatars();
                                            } else {
                                              shop.changeAvatar(1, animal);
                                            }
                                            await shop.saveAvatars();
                                            setDialogState(() {});
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("CLOSE", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================================
  // HOW TO PLAY DIALOG
  // ============================================================================
  void _showHowToPlayDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C3E50),
          title: const Text("How To Play", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.7,
            child: Scrollbar(
              child: ListView(
                padding: const EdgeInsets.only(right: 8),
                children: [
                  Image.asset("assets/images/banner.png", height: 100, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox()),
                  const SizedBox(height: 16),
                  
                  // Section 1
                  const Text(
                    "OBJECTIVE\n\nThe first player to move all 4 of his or her pieces around the board wins.\n\n"
                    "ROLL PHASE\n\nDuring your turn, you will be prompted to throw the sticks with the roll button.\n",
                    style: TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
                  ),
                  Image.asset("assets/images/rollbutton1.png", height: 80, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox()),
                  const SizedBox(height: 16),

                  // Section 2
                  const Text(
                    "If you roll a 4 or 5, you get to roll again. In addition, if you land on an opponent's piece, you get to roll again.\n\n"
                    "MOVE PHASE\n\nYour possible moves are shown in the 5 circles near the bottom.\n",
                    style: TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
                  ),
                  Image.asset("assets/images/roll_example.png", height: 50, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox()),
                  const SizedBox(height: 16),

                  // Section 3
                  const Text(
                    "To move, click any one of your available pieces (the jumping pieces) and select a yellow tile, which indicates a possible location you can move to with that piece. Stack your pieces together to move faster around the board!\n",
                    style: TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
                  ),
                  Image.asset("assets/images/yellow_tile_example.png", height: 260, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox()),
                  const SizedBox(height: 16),

                  // Section 4
                  const Text(
                    "POSSIBLE ROLLS AND RATES\n\n"
                    "• -1 (Back-Do): 6.25%\n"
                    "• 1 (Do): 18.75%\n"
                    "• 2 (Gae): 37.50%\n"
                    "• 3 (Geol): 25.00%\n"
                    "• 4 (Yut): 6.25%\n"
                    "• 5 (Mo): 6.25%\n\n"
                    "Note: These rates are averages and you may get luckier or unluckier!\n",
                    style: TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Image.asset("assets/images/circleminus1.png", width: 34, height: 34, errorBuilder: (_, __, ___) => const SizedBox()),
                      Image.asset("assets/images/circle1.png", width: 34, height: 34, errorBuilder: (_, __, ___) => const SizedBox()),
                      Image.asset("assets/images/circle2.png", width: 34, height: 34, errorBuilder: (_, __, ___) => const SizedBox()),
                      Image.asset("assets/images/circle3.png", width: 34, height: 34, errorBuilder: (_, __, ___) => const SizedBox()),
                      Image.asset("assets/images/circle4.png", width: 34, height: 34, errorBuilder: (_, __, ___) => const SizedBox()),
                      Image.asset("assets/images/circle5.png", width: 34, height: 34, errorBuilder: (_, __, ___) => const SizedBox()),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Section 5
                  const Text(
                    "REMAINING PIECES\n\n"
                    "Pieces off the board that need to be completed will be shown at the top. Pieces already completed will have medals. Pieces on the board will not be shown at the top.\n",
                    style: TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
                  ),
                  Image.asset("assets/images/rollbar_example.png", height: 50, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox()),
                  const SizedBox(height: 16),

                  // Section 6 & 7
                  const Text(
                    "COINS\n\n"
                    "Earn coins to buy new avatars!\n\n"
                    "• Earn 1 coin for playing a two player match\n"
                    "• Earn 1 coin for losing against a computer\n"
                    "• Earn 3 coins for winning against a computer\n",
                    style: TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
                  ),
                  Image.asset("assets/images/welcome.png", height: 150, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox()),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OKAY", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  // ============================================================================
  // OPTIONS DIALOG
  // ============================================================================
  void _showOptionsDialog(BuildContext context) {
    final shop = Shop.instance;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C3E50),
          title: const Text("Options", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatefulBuilder(
                builder: (context, setStateDialog) {
                  return SwitchListTile(
                    activeColor: Colors.cyan,
                    title: const Text("Background Music", style: TextStyle(color: Colors.white)),
                    value: shop.getSoundEnabled(),
                    onChanged: (val) {
                      setStateDialog(() {
                        shop.setSoundEnabled(val);
                      });
                      updateMusicPlayback();
                    },
                  );
                },
              ),
              const Divider(color: Colors.grey),
              ListTile(
                leading: const Icon(Icons.share, color: Colors.cyan),
                title: const Text("Share App", style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Link copied to clipboard!")),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.info, color: Colors.cyan),
                title: const Text("Credits", style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: const Color(0xFF2C3E50),
                      title: const Text("Credits", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Yut Game - Ported to Flutter\n\nDeveloper: Jeffrey Chan\n",
                            style: TextStyle(color: Colors.white, height: 1.4),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () {
                              if (kIsWeb) {
                                try {
                                  js.context.callMethod('open', ['https://github.com/superjeffc']);
                                } catch (_) {}
                              }
                            },
                            child: const Text(
                              "Website: https://github.com/superjeffc",
                              style: TextStyle(color: Colors.cyan, decoration: TextDecoration.underline),
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("OK", style: TextStyle(color: Colors.white)),
                        )
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CLOSE", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}

// Custom vector painter for snowfall effect
class SnowPainter extends CustomPainter {
  final List<Snowflake> flakes;
  final double width;
  final double height;

  SnowPainter(this.flakes, this.width, this.height);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.85);

    // Scale drawing coordinate mapping to the actual viewport size
    double scaleX = size.width / width;
    double scaleY = size.height / height;

    for (var flake in flakes) {
      canvas.drawCircle(Offset(flake.x * scaleX, flake.y * scaleY), flake.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class Snowflake {
  double x;
  double y;
  double speed;
  double radius;
  Snowflake({required this.x, required this.y, required this.speed, required this.radius});
}

// ============================================================================
// GAME SCREEN (THE BOARD)
// ============================================================================
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  Timer? _blinkTimer;
  bool _blinkState = false;

  @override
  void initState() {
    super.initState();
    _blinkTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (mounted) {
        setState(() {
          _blinkState = !_blinkState;
        });
      }
    });
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    super.dispose();
  }
  // Calculates coordinates dynamically based on display dimensions
  Map<int, Offset> _calculateTileOffsets(double width, double height) {
    double boardSize = height * 0.58;
    if (boardSize > width) boardSize = width;
    double padding = boardSize / 50.0;
    double space = boardSize / 25.0;
    double tileSize = (boardSize - padding * 2 - space * 5) / 6;
    double heightOffset = height / 20.0;
    double yShift = heightOffset / 2;

    Map<int, Offset> offsets = {};

    // Tiles 0 to 5 (Right side going up)
    for (int i = 0; i < 6; i++) {
      double x = width / 2 + boardSize / 2 - tileSize - padding;
      double y = height * 0.4 + boardSize / 2 - i * (tileSize + space) - tileSize - padding + yShift;
      offsets[i] = Offset(x, y);
    }

    // Tiles 6 to 9 (Top side going left)
    for (int i = 6; i < 10; i++) {
      double x = offsets[5]!.dx - (i - 5) * (tileSize + space);
      double y = offsets[5]!.dy;
      offsets[i] = Offset(x, y);
    }

    // Tiles 10 to 15 (Left side going down)
    for (int i = 10; i < 16; i++) {
      double x = offsets[9]!.dx - tileSize - space;
      double y = offsets[5 - (i - 10)]!.dy;
      offsets[i] = Offset(x, y);
    }

    // Tiles 16 to 19 (Bottom side going right)
    for (int i = 16; i < 20; i++) {
      double x = offsets[9 - (i - 16)]!.dx;
      double y = offsets[15]!.dy;
      offsets[i] = Offset(x, y);
    }

    // Diagonal 20 to 24 (Top-Left corner to Bottom-Right corner, passing center 22)
    for (int i = 20; i < 25; i++) {
      double x = width / 2 - tileSize / 2 + (22 - i) * (offsets[0]!.dx - (width / 2 - tileSize / 2)) / 3;
      double y = height * 0.4 - tileSize / 2 - (22 - i) * (offsets[0]!.dy - yShift - (height * 0.4 - tileSize / 2)) / 3 + yShift;
      offsets[i] = Offset(x, y);
    }

    // Diagonal 25 to 28 (Top-Right corner to Bottom-Left corner, skipping center 22)
    for (int i = 25; i < 29; i++) {
      int j = i;
      if (i > 26) j++;
      double x = width / 2 - tileSize / 2 + (j - 27) * (offsets[0]!.dx - (width / 2 - tileSize / 2)) / 3;
      double y = height * 0.4 - tileSize / 2 + (j - 27) * (offsets[0]!.dy - yShift - (height * 0.4 - tileSize / 2)) / 3 + yShift;
      offsets[i] = Offset(x, y);
    }

    return offsets;
  }

  @override
  Widget build(BuildContext context) {
    final controller = Provider.of<GameController>(context);
    final size = MediaQuery.of(context).size;
    final shop = Shop.instance;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        updateMusicPlayback();
      },
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          _showQuitConfirmation(context);
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF1E262C),
          body: Stack(
          children: [
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
            double width = constraints.maxWidth;
            double height = constraints.maxHeight;

            double boardSize = height * 0.58;
            if (boardSize > width) boardSize = width;
            double padding = boardSize / 50.0;
            double tileSize = (boardSize - padding * 2 - (boardSize / 25.0) * 5) / 6;

            final offsets = _calculateTileOffsets(width, height);
            final selectedAvatars = shop.getSelectedAnimals();

            return Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () {
                      if (controller.selectedPieceIndex != -1) {
                        controller.cancelSelection();
                      }
                    },
                    child: Image.asset(
                      "assets/images/board_clear.png",
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // 1. Board Lines (Background layer)
                if (offsets.containsKey(10) && offsets.containsKey(0) && offsets.containsKey(15))
                  Positioned(
                    left: offsets[10]!.dx + tileSize / 2,
                    top: offsets[10]!.dy + tileSize / 2,
                    width: offsets[0]!.dx - offsets[10]!.dx,
                    height: offsets[15]!.dy - offsets[10]!.dy,
                    child: Opacity(
                      opacity: 0.5,
                      child: Image.asset(
                        "assets/images/board_lines.png",
                        fit: BoxFit.fill,
                      ),
                    ),
                  ),

                // 2. Start Banner overlay
                if (offsets.containsKey(0))
                  Positioned(
                    left: offsets[0]!.dx + tileSize / 8,
                    top: offsets[0]!.dy + tileSize / 8,
                    width: 3.0 * tileSize / 4.0,
                    height: 3.0 * tileSize / 4.0,
                    child: Image.asset("assets/images/start_tile.png"),
                  ),

                // 3. Arrow Overlays
                ...[0, 5, 10, 22, 15].map((tileIdx) {
                  if (!offsets.containsKey(tileIdx)) return const SizedBox();
                  double rot = 0;
                  if (tileIdx == 0) rot = -pi / 2;
                  if (tileIdx == 5) rot = 135 * pi / 180;
                  if (tileIdx == 10 || tileIdx == 22) rot = 45 * pi / 180;

                  return Positioned(
                    left: offsets[tileIdx]!.dx + tileSize / 5,
                    top: offsets[tileIdx]!.dy + tileSize / 5,
                    width: 3.0 * tileSize / 5.0,
                    height: 3.0 * tileSize / 5.0,
                    child: Transform.rotate(
                      angle: rot,
                      child: Opacity(
                        opacity: 0.6,
                        child: Image.asset("assets/images/arrow.png"),
                      ),
                    ),
                  );
                }),

                // 4. Highlighted / Flashing Tile Buttons
                ...offsets.keys.map((tileIdx) {
                  bool isSpecial = Board.specialTiles.contains(tileIdx);
                  bool isHighlighted = controller.highlightedTiles.contains(tileIdx);

                  String tileAsset;
                  if (isHighlighted && _blinkState) {
                    tileAsset = isSpecial ? "assets/images/orange_marker2.png" : "assets/images/blue_marker2.png";
                  } else {
                    tileAsset = isSpecial ? "assets/images/orange_marker.png" : "assets/images/blue_marker.png";
                  }

                  return Positioned(
                    left: offsets[tileIdx]!.dx,
                    top: offsets[tileIdx]!.dy,
                    width: tileSize,
                    height: tileSize,
                    child: GestureDetector(
                      onTap: () {
                        if (isHighlighted) {
                          controller.makeMove(tileIdx);
                        } else {
                          controller.cancelSelection();
                        }
                      },
                      child: Image.asset(
                        tileAsset,
                        fit: BoxFit.contain,
                      ),
                    ),
                  );
                }),

                // 5. Finished Overlay Trigger (Double finish box)
                if (controller.highlightedTiles.contains(32) && offsets.containsKey(0))
                  Positioned(
                    left: offsets[0]!.dx - tileSize * 0.8,
                    top: offsets[0]!.dy + tileSize + 8,
                    width: tileSize * 2,
                    height: tileSize,
                    child: InkWell(
                      onTap: () => controller.makeMove(32),
                      child: Image.asset(
                        _blinkState ? "assets/images/finish2.png" : "assets/images/finish1.png",
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),

                // 6. Active Player Pieces on the Board
                for (int pIdx = 0; pIdx < 2; pIdx++)
                  ...List.generate(4, (pieceIdx) {
                    final player = controller.players[pIdx];
                    final piece = player.pieces[pieceIdx];
                    final animal = selectedAvatars[pIdx];

                    if (piece.location == -1 || piece.location == 32) {
                      return const SizedBox();
                    }

                    final offset = offsets[piece.location] ?? Offset.zero;

                    // Determine if this piece should be jumping (is selectable)
                    bool isSelectable = controller.turn == pIdx &&
                                        !controller.isGameOver &&
                                        controller.board.getPosRollCount() > 0 &&
                                        !controller.isRollInProgress &&
                                        !controller.isMoveInProgress;

                    return AnimatedPositioned(
                      key: ValueKey("piece_${pIdx}_$pieceIdx"),
                      duration: const Duration(milliseconds: 180),
                      left: offset.dx + 2,
                      top: offset.dy + 2,
                      width: tileSize - 4,
                      height: tileSize - 4,
                      child: GestureDetector(
                        onTap: () {
                          if (controller.highlightedTiles.contains(piece.location)) {
                            // Execute Move/Stack/Capture!
                            controller.makeMove(piece.location);
                          } else if (controller.turn == pIdx) {
                            controller.selectPiece(pieceIdx);
                          }
                        },
                        child: AnimatedPiece(
                          animal: animal,
                          stackValue: piece.value,
                          isSelectable: isSelectable,
                          size: tileSize - 4,
                        ),
                      ),
                    );
                  }),

                // 7. Dynamic Top/Bottom Player Stat Bars
                Positioned(
                  left: 0,
                  top: 0,
                  width: width,
                  height: height / 10,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // P1 Bar (Left)
                      Opacity(
                        opacity: controller.turn == 0 ? 1.0 : 0.45,
                        child: Container(
                          width: width / 2.05,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: const BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage("assets/images/bar1.png"),
                              fit: BoxFit.fill,
                            ),
                          ),
                          child: Row(
                            children: [
                              Image.asset(shop.getIconImagePath(selectedAvatars[0]), width: 38),
                              const SizedBox(width: 8),
                              const Text("Player 1", style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              // Completed medals
                              ...List.generate(controller.players[0].score, (_) => const Icon(Icons.star, color: Colors.amber, size: 16)),
                              // Pieces off the board
                              ...List.generate(
                                4 - controller.players[0].numPieces,
                                (_) => Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 2),
                                  child: Image.asset(
                                    shop.getImagePath(selectedAvatars[0], 1),
                                    width: 18,
                                    height: 18,
                                  ),
                                ),
                              ),
                              const Spacer(),
                            ],
                          ),
                        ),
                      ),
                      // P2 / Computer Bar (Right)
                      Opacity(
                        opacity: controller.turn == 1 ? 1.0 : 0.45,
                        child: SizedBox(
                          width: width / 2.05,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Transform.flip(
                                  flipX: true,
                                  child: Image.asset(
                                    "assets/images/bar2.png",
                                    fit: BoxFit.fill,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    const Spacer(),
                                    // Pieces off the board
                                    ...List.generate(
                                      4 - controller.players[1].numPieces,
                                      (_) => Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 2),
                                        child: Image.asset(
                                          shop.getImagePath(selectedAvatars[1], 1),
                                          width: 18,
                                          height: 18,
                                        ),
                                      ),
                                    ),
                                    ...List.generate(controller.players[1].score, (_) => const Icon(Icons.star, color: Colors.amber, size: 16)),
                                    const SizedBox(width: 8),
                                    Text(controller.isComputerPlaying ? "Computer" : "Player 2", style: const TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(width: 8),
                                    Image.asset(shop.getIconImagePath(selectedAvatars[1]), width: 38),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // QUIT Button (Middle left of the screen)
                Positioned(
                  left: 12,
                  top: height / 2 - 30,
                  width: 60,
                  height: 60,
                  child: InkWell(
                    onTap: () {
                      _showQuitConfirmation(context);
                    },
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Image.asset(
                          "assets/images/quit1.png",
                          width: 50,
                          height: 50,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(Icons.exit_to_app, color: Colors.white, size: 30),
                        ),
                        const Positioned(
                          bottom: 0,
                          child: Text(
                            "QUIT",
                            style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold, backgroundColor: Colors.black54),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 8. Roll Trigger Clicker (Start new piece button)
                if (controller.players[controller.turn].numPieces < 4 && 
                    controller.board.getPosRollCount() > 0 && 
                    !controller.board.rollEmpty() &&
                    !(controller.turn == 1 && controller.isComputerPlaying))
                  Positioned(
                    left: width - 76,
                    bottom: height * 0.03,
                    width: 60,
                    height: 60,
                    child: InkWell(
                      onTap: () {
                        controller.selectPiece(-1);
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedPiece(
                            animal: selectedAvatars[controller.turn],
                            stackValue: 1,
                            isSelectable: true,
                            size: 50,
                          ),
                          const Positioned(
                            bottom: 0,
                            child: Text(
                              "Press me!",
                              style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold, backgroundColor: Colors.black54),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // 9. Roll Slot indicators (Bottom center)
                Positioned(
                  left: 12,
                  bottom: height * 0.03,
                  width: width - 88,
                  height: 48,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      int roll = controller.board.rollArray[index];
                      String img = "assets/images/white_marker.png";
                      if (roll == -1) img = "assets/images/circleminus1.png";
                      if (roll == 1) img = "assets/images/circle1.png";
                      if (roll == 2) img = "assets/images/circle2.png";
                      if (roll == 3) img = "assets/images/circle3.png";
                      if (roll == 4) img = "assets/images/circle4.png";
                      if (roll == 5) img = "assets/images/circle5.png";

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 40,
                        height: 40,
                        child: Image.asset(img),
                      );
                    }),
                  ),
                ),

                // 10. Floating Game Rules and Tip Prompts
                if (offsets.containsKey(15))
                  Positioned(
                    left: 24,
                    top: offsets[15]!.dy + tileSize + 20,
                    width: width - 48,
                    child: Column(
                    children: [
                      Text(
                        controller.statusText,
                        style: const TextStyle(fontSize: 20, color: Color(0xFF2C3E50), fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        controller.tipsText,
                        style: const TextStyle(fontSize: 15, color: Color(0xFF7F8C8D), fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),

                // 11. Large Primary ROLL BUTTON
                if ((controller.board.rollEmpty() || controller.tipsText == "Roll again!") && 
                    !(controller.turn == 1 && controller.isComputerPlaying) && 
                    !controller.isRollInProgress && 
                    !controller.isMoveInProgress && 
                    !controller.isGameOver)
                  Positioned(
                    left: width / 2 - 70,
                    bottom: height * 0.12,
                    width: 140,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: controller.turn == 0 ? const Color(0xFF56AFC1) : const Color(0xFFE57C38),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                          side: BorderSide(
                            color: _blinkState ? Colors.yellow : Colors.transparent,
                            width: 3.5,
                          ),
                        ),
                      ),
                      onPressed: () {
                        controller.rollSticks();
                      },
                      child: const Text(
                        "THROW",
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ),

                // 12. Stick Roll Physics Overlay Screen
                if (controller.isRollInProgress)
                  Positioned.fill(
                    child: SticksRollOverlay(rollValue: controller.currentRollValue),
                  ),

                // 13. Game Over Panel modal
                if (controller.isGameOver)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black87,
                      child: Center(
                        child: Card(
                          color: const Color(0xFF2C3E50),
                          margin: const EdgeInsets.all(24),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text("GAME OVER", style: TextStyle(fontSize: 26, color: Colors.white, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 16),
                                Text(
                                  controller.players[0].hasWon() ? "Congratulations, you won!" : "Computer wins!",
                                  style: const TextStyle(fontSize: 18, color: Colors.amber),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    ElevatedButton(
                                      onPressed: () {
                                        controller.resetGame();
                                      },
                                      child: const Text("PLAY AGAIN"),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE74C3C)),
                                      onPressed: () {
                                        Navigator.pop(context);
                                      },
                                      child: const Text("QUIT"),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
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

  void _showQuitConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C3E50),
          title: const Text("Exit game?", style: TextStyle(color: Colors.white)),
          content: const Text("The current game progress will be lost.", style: TextStyle(color: Colors.grey)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL", style: TextStyle(color: Colors.white)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Pop dialog
                Navigator.pop(context); // Return to title
              },
              child: const Text("QUIT", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}

// ============================================================================
// STICKS PHYSICS ROLL OVERLAY
// ============================================================================
class SticksRollOverlay extends StatefulWidget {
  final int rollValue;
  const SticksRollOverlay({super.key, required this.rollValue});

  @override
  State<SticksRollOverlay> createState() => _SticksRollOverlayState();
}

class _SticksRollOverlayState extends State<SticksRollOverlay> {
  late Timer _animationTimer;
  int _currentFrame = 1;
  final Random _rand = Random();

  @override
  void initState() {
    super.initState();
    // Cycle rapidly through stick textures to simulate movement
    _animationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _currentFrame = _rand.nextInt(10) + 1; // Frames 1 to 10
      });
    });
  }

  @override
  void dispose() {
    _animationTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Displays stick sprites rotating
            SizedBox(
              height: 200,
              width: 200,
              child: Image.asset(
                _currentFrame == 1
                    ? "assets/images/stick.png"
                    : "assets/images/stick$_currentFrame.png",
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "THROWING STICKS...",
              style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2.0),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SELF-CONTAINED ANIMATED ANIMAL PIECE
// ============================================================================
class AnimatedPiece extends StatefulWidget {
  final String animal;
  final int stackValue;
  final bool isSelectable;
  final double size;

  const AnimatedPiece({
    super.key,
    required this.animal,
    required this.stackValue,
    required this.isSelectable,
    required this.size,
  });

  @override
  State<AnimatedPiece> createState() => _AnimatedPieceState();
}

class _AnimatedPieceState extends State<AnimatedPiece> {
  Timer? _timer;
  int _frame = 0;

  @override
  void initState() {
    super.initState();
    if (widget.isSelectable) {
      _startAnimation();
    }
  }

  @override
  void didUpdateWidget(AnimatedPiece oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSelectable != oldWidget.isSelectable) {
      if (widget.isSelectable) {
        _startAnimation();
      } else {
        _stopAnimation();
      }
    }
  }

  void _startAnimation() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 180), (timer) {
      if (mounted) {
        setState(() {
          _frame = (_frame + 1) % 4;
        });
      }
    });
  }

  void _stopAnimation() {
    _timer?.cancel();
    _timer = null;
    if (mounted) {
      setState(() {
        _frame = 0;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shop = Shop.instance;
    String imagePath = widget.isSelectable
        ? shop.getJumpFrames(widget.animal, widget.stackValue)[_frame]
        : shop.getImagePath(widget.animal, widget.stackValue);

    return Image.asset(
      imagePath,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
    );
  }
}
