import 'package:cyclezen/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// First-run brand landing screen based on the supplied CycleZen design.
class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  static const _keyShown = 'cyclezen_onboarding_shown';

  Future<bool> _hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyShown) ?? false;
  }

  Future<void> _startRiding(BuildContext context) async {
    final done = await _hasCompletedOnboarding();
    if (!context.mounted) return;
    context.go(done ? '/home' : '/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isCompact = size.height < 760;
    final topGap = isCompact ? 18.0 : 36.0;
    final logoSize =
        (size.shortestSide * (isCompact ? 0.33 : 0.4)).clamp(118.0, 176.0);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _LandingBackdrop(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  SizedBox(height: topGap),
                  Image.asset(
                    'assets/images/cyclezen_mark.png',
                    width: logoSize,
                    height: logoSize,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                  const SizedBox(height: 4),
                  const _CycleZenWordmark(),
                  const SizedBox(height: 10),
                  const _BrandTagline(),
                  SizedBox(height: isCompact ? 20 : 34),
                  Container(
                    width: 64,
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppTheme.greenAccent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 22),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Your Cycling Companion',
                      textAlign: TextAlign.center,
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: AppTheme.primaryDark,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                              ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Discover, generate, and share\namazing cycling routes.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: const Color(0xFF3D4B52),
                          fontSize: 17,
                          height: 1.35,
                        ),
                  ),
                  const Spacer(),
                  _StartRidingButton(onPressed: () => _startRiding(context)),
                  const SizedBox(height: 26),
                  const _PageDots(),
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

class _LandingBackdrop extends StatelessWidget {
  const _LandingBackdrop();

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
          CustomPaint(painter: _SkyPainter()),
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
                    Color(0x440F4D4D),
                    Color(0xEE063638),
                  ],
                  stops: [0, 0.58, 0.78, 1],
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
              fontWeight: FontWeight.w600,
              letterSpacing: 3.2,
            ),
      ),
    );
  }
}

class _StartRidingButton extends StatelessWidget {
  const _StartRidingButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: double.infinity,
            height: 76,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [AppTheme.secondaryTeal, AppTheme.greenAccent],
              ),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryDark.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: const BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.pedal_bike_rounded,
                      color: AppTheme.secondaryTeal, size: 31),
                ),
                const Expanded(
                  child: Text(
                    'Start Riding',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded,
                    size: 44, color: Colors.white),
              ],
            ),
          ),
        ),
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
          width: 14,
          height: 14,
          margin: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.greenAccent
                : Colors.white.withValues(alpha: 0.45),
            shape: BoxShape.circle,
          ),
        );
      }),
    );
  }
}

class _SkyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cloudPaint = Paint()..color = Colors.white.withValues(alpha: 0.8);
    _cloud(canvas, Offset(-28, size.height * 0.32), 1.0, cloudPaint);
    _cloud(
        canvas, Offset(size.width - 110, size.height * 0.33), 1.1, cloudPaint);
    _cloud(canvas, Offset(-12, size.height * 0.42), 0.58, cloudPaint);

    final birdPaint = Paint()
      ..color = AppTheme.primaryDark.withValues(alpha: 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeCap = StrokeCap.round;
    _bird(
        canvas, Offset(size.width * 0.75, size.height * 0.23), 1.0, birdPaint);
    _bird(
        canvas, Offset(size.width * 0.82, size.height * 0.26), 0.82, birdPaint);
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
          origin.dy + 34 * scale)
      ..cubicTo(
          origin.dx + 118 * scale,
          origin.dy - 18 * scale,
          origin.dx + 178 * scale,
          origin.dy + 18 * scale,
          origin.dx + 182 * scale,
          origin.dy + 72 * scale)
      ..lineTo(origin.dx, origin.dy + 72 * scale)
      ..close();
    canvas.drawPath(path, paint);
  }

  void _bird(Canvas canvas, Offset origin, double scale, Paint paint) {
    final path = Path()
      ..moveTo(origin.dx - 19 * scale, origin.dy)
      ..quadraticBezierTo(
          origin.dx - 9 * scale, origin.dy - 8 * scale, origin.dx, origin.dy)
      ..quadraticBezierTo(origin.dx + 10 * scale, origin.dy - 8 * scale,
          origin.dx + 20 * scale, origin.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
