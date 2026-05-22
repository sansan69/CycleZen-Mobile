import 'package:cyclezen/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// First-run brand landing screen based on the supplied CycleZen design.
class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  static const _keyShown = 'cyclezen_onboarding_shown';

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with TickerProviderStateMixin {
  late final AnimationController _introController;
  late final AnimationController _ambientController;

  Future<bool> _hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(LandingPage._keyShown) ?? false;
  }

  Future<void> _startRiding() async {
    final done = await _hasCompletedOnboarding();
    if (!mounted) return;
    context.go(done ? '/home' : '/onboarding');
  }

  @override
  void initState() {
    super.initState();
    _introController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    )..forward();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _introController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.height < 760;
    final topGap = isCompact ? 16.0 : 30.0;
    final logoSize =
        (size.shortestSide * (isCompact ? 0.35 : 0.42)).clamp(124.0, 184.0);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _LandingBackdrop(ambientController: _ambientController),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  SizedBox(height: topGap),
                  _Entrance(
                    controller: _introController,
                    child: AnimatedBuilder(
                      animation: _ambientController,
                      builder: (context, child) {
                        final lift = -4 + (_ambientController.value * 8);
                        return Transform.translate(
                          offset: Offset(0, lift),
                          child: child,
                        );
                      },
                      child: Image.asset(
                        'assets/images/cyclezen_mark_transparent.png',
                        width: logoSize,
                        height: logoSize,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  _Entrance(
                    controller: _introController,
                    delay: 0.08,
                    child: const _CycleZenWordmark(),
                  ),
                  const SizedBox(height: 10),
                  _Entrance(
                    controller: _introController,
                    delay: 0.16,
                    child: const _BrandTagline(),
                  ),
                  SizedBox(height: isCompact ? 18 : 30),
                  _Entrance(
                    controller: _introController,
                    delay: 0.22,
                    child: Container(
                      width: 64,
                      height: 3,
                      decoration: BoxDecoration(
                        color: AppTheme.greenAccent,
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.greenAccent.withValues(alpha: 0.35),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  _Entrance(
                    controller: _introController,
                    delay: 0.28,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Your Cycling Companion',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                          color: AppTheme.primaryDark,
                          fontWeight: FontWeight.w800,
                          height: 1.1,
                          shadows: const [
                            Shadow(color: Colors.white70, blurRadius: 14),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Entrance(
                    controller: _introController,
                    delay: 0.34,
                    child: Text(
                      'Discover, generate, and share\namazing cycling routes.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.primaryDark.withValues(alpha: 0.78),
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                        shadows: const [
                          Shadow(color: Colors.white, blurRadius: 12),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  _Entrance(
                    controller: _introController,
                    delay: 0.46,
                    child: _SwipeStartControl(onComplete: _startRiding),
                  ),
                  const SizedBox(height: 24),
                  _Entrance(
                    controller: _introController,
                    delay: 0.54,
                    child: const _PageDots(),
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Entrance extends StatelessWidget {
  const _Entrance({
    required this.controller,
    required this.child,
    this.delay = 0,
  });

  final AnimationController controller;
  final Widget child;
  final double delay;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final progress =
            ((controller.value - delay) / (1 - delay)).clamp(0.0, 1.0);
        final eased = Curves.easeOutCubic.transform(progress);
        return Opacity(
          opacity: eased,
          child: Transform.translate(
            offset: Offset(0, 26 * (1 - eased)),
            child: Transform.scale(
              scale: 0.97 + (0.03 * eased),
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

class _LandingBackdrop extends StatelessWidget {
  const _LandingBackdrop({required this.ambientController});

  final AnimationController ambientController;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFCFE8F6),
            Color(0xFFF8FCFC),
            Color(0xFFE8F5F3),
            Color(0xFF0F4D4D),
          ],
          stops: [0, 0.35, 0.54, 1],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: ambientController,
            builder: (context, _) => CustomPaint(
              painter: _SkyPainter(progress: ambientController.value),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 104,
            height: MediaQuery.sizeOf(context).height * 0.42,
            child: Image.asset(
              'assets/images/landing_scenic_valley.png',
              fit: BoxFit.cover,
              alignment: Alignment.bottomCenter,
              filterQuality: FilterQuality.high,
            ),
          ),
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Color(0x220F4D4D),
                    Color(0xE8063638),
                  ],
                  stops: [0, 0.56, 0.76, 1],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CycleZenWordmark extends StatelessWidget {
  const _CycleZenWordmark();

  @override
  Widget build(BuildContext context) {
    final fontSize = MediaQuery.sizeOf(context).width < 380 ? 52.0 : 62.0;

    return SizedBox(
      width: double.infinity,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Cycle',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: fontSize,
                fontWeight: FontWeight.w400,
                height: 0.95,
                color: AppTheme.primaryDark,
                shadows: const [
                  Shadow(color: Colors.white70, blurRadius: 14),
                ],
              ),
            ),
            ShaderMask(
              shaderCallback: (bounds) =>
                  AppTheme.brandGradient.createShader(bounds),
              child: Text(
                'Zen',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  height: 0.95,
                  color: Colors.white,
                  shadows: const [
                    Shadow(color: Colors.white70, blurRadius: 14),
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

class _BrandTagline extends StatelessWidget {
  const _BrandTagline();

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        'DISCOVER. PLAN. RIDE. SHARE.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: AppTheme.primaryDark,
          fontWeight: FontWeight.w800,
          letterSpacing: 3.2,
          shadows: const [
            Shadow(color: Colors.white70, blurRadius: 12),
          ],
        ),
      ),
    );
  }
}

class _SwipeStartControl extends StatefulWidget {
  const _SwipeStartControl({required this.onComplete});

  final Future<void> Function() onComplete;

  @override
  State<_SwipeStartControl> createState() => _SwipeStartControlState();
}

class _SwipeStartControlState extends State<_SwipeStartControl>
    with TickerProviderStateMixin {
  static const _height = 76.0;
  static const _handleSize = 58.0;

  late final AnimationController _loopController;
  late final AnimationController _settleController;
  Animation<double>? _settleAnimation;
  double _progress = 0;
  bool _completed = false;

  @override
  void initState() {
    super.initState();
    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat();
    _settleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..addListener(() {
        final animation = _settleAnimation;
        if (animation != null) {
          setState(() => _progress = animation.value);
        }
      });
  }

  @override
  void dispose() {
    _loopController.dispose();
    _settleController.dispose();
    super.dispose();
  }

  void _updateDrag(double dx, double travel) {
    if (_completed) return;
    _settleController.stop();
    setState(() => _progress = (_progress + dx / travel).clamp(0.0, 1.0));
  }

  void _settleTo(double target, {VoidCallback? onDone}) {
    _settleAnimation = Tween<double>(begin: _progress, end: target).animate(
      CurvedAnimation(parent: _settleController, curve: Curves.easeOutCubic),
    );
    _settleController
      ..reset()
      ..forward().whenComplete(() {
        if (mounted) onDone?.call();
      });
  }

  void _endDrag() {
    if (_completed) return;
    if (_progress >= 0.72) {
      _completed = true;
      _settleTo(1, onDone: widget.onComplete);
    } else {
      _settleTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final travel = (width - _handleSize - 22).clamp(1.0, double.infinity);
          final handleX = 10 + travel * _progress;

          return Semantics(
            button: true,
            label: 'Swipe right to start riding',
            child: GestureDetector(
              onHorizontalDragUpdate: (details) =>
                  _updateDrag(details.delta.dx, travel),
              onHorizontalDragEnd: (_) => _endDrag(),
              child: AnimatedBuilder(
                animation: _loopController,
                builder: (context, _) {
                  final wave = _loopController.value;
                  return Container(
                    width: double.infinity,
                    height: _height,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [AppTheme.secondaryTeal, AppTheme.greenAccent],
                      ),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.42),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryDark.withValues(alpha: 0.36),
                          blurRadius: 26,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          left: -width + (width * 2 * wave),
                          width: width * 0.72,
                          top: 0,
                          bottom: 0,
                          child: Transform(
                            transform: Matrix4.skewX(-0.22),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white.withValues(alpha: 0),
                                    Colors.white.withValues(alpha: 0.16),
                                    Colors.white.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          width: 24 + (width - 24) * _progress,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        Opacity(
                          opacity: (1 - (_progress * 0.45)).clamp(0.55, 1),
                          child: Text(
                            _completed ? 'Starting...' : 'Swipe to Start',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 23,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              shadows: [
                                Shadow(color: Color(0x33000000), blurRadius: 8),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          right: 20,
                          child: Transform.translate(
                            offset: Offset(6 * wave, 0),
                            child: Icon(
                              Icons.keyboard_double_arrow_right_rounded,
                              size: 32,
                              color: Colors.white
                                  .withValues(alpha: 0.72 + 0.28 * wave),
                            ),
                          ),
                        ),
                        Positioned(
                          left: handleX,
                          child: AnimatedScale(
                            scale: _progress > 0.02 ? 1.04 : 1,
                            duration: const Duration(milliseconds: 160),
                            child: Container(
                              width: _handleSize,
                              height: _handleSize,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryDark
                                        .withValues(alpha: 0.26),
                                    blurRadius: 16,
                                    offset: const Offset(0, 7),
                                  ),
                                ],
                              ),
                              child: Icon(
                                _completed
                                    ? Icons.check_rounded
                                    : Icons.pedal_bike_rounded,
                                color: AppTheme.secondaryTeal,
                                size: 31,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final selected = index == 1;
        return Container(
          width: selected ? 15 : 13,
          height: selected ? 15 : 13,
          margin: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.greenAccent
                : Colors.white.withValues(alpha: 0.5),
            shape: BoxShape.circle,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppTheme.greenAccent.withValues(alpha: 0.35),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }
}

class _SkyPainter extends CustomPainter {
  const _SkyPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final cloudPaint = Paint()..color = Colors.white.withValues(alpha: 0.82);
    _cloud(canvas, Offset(-28, size.height * 0.32), 1.0, cloudPaint);
    _cloud(
      canvas,
      Offset(size.width - 110, size.height * 0.33),
      1.1,
      cloudPaint,
    );
    _cloud(canvas, Offset(-12, size.height * 0.42), 0.58, cloudPaint);

    final birdPaint = Paint()
      ..color = AppTheme.primaryDark.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;
    final drift = (progress - 0.5) * 18;
    _bird(
      canvas,
      Offset(size.width * 0.75 + drift, size.height * 0.23),
      1.0,
      birdPaint,
    );
    _bird(
      canvas,
      Offset(size.width * 0.82 + drift, size.height * 0.26),
      0.82,
      birdPaint,
    );
  }

  void _cloud(Canvas canvas, Offset origin, double scale, Paint paint) {
    final path = Path()
      ..moveTo(origin.dx, origin.dy + 52 * scale)
      ..cubicTo(
        origin.dx + 30 * scale,
        origin.dy + 24 * scale,
        origin.dx + 58 * scale,
        origin.dy + 72 * scale,
        origin.dx + 82 * scale,
        origin.dy + 34 * scale,
      )
      ..cubicTo(
        origin.dx + 118 * scale,
        origin.dy - 18 * scale,
        origin.dx + 178 * scale,
        origin.dy + 18 * scale,
        origin.dx + 182 * scale,
        origin.dy + 72 * scale,
      )
      ..lineTo(origin.dx, origin.dy + 72 * scale)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _bird(Canvas canvas, Offset origin, double scale, Paint paint) {
    final path = Path()
      ..moveTo(origin.dx - 19 * scale, origin.dy)
      ..quadraticBezierTo(
        origin.dx - 9 * scale,
        origin.dy - 8 * scale,
        origin.dx,
        origin.dy,
      )
      ..quadraticBezierTo(
        origin.dx + 10 * scale,
        origin.dy - 8 * scale,
        origin.dx + 20 * scale,
        origin.dy,
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SkyPainter oldDelegate) {
    return progress != oldDelegate.progress;
  }
}
