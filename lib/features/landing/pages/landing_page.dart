import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Exact-match landing page with centered teal card, route illustration,
/// gold tagline, heading, subtitle, and "Start Riding →" CTA.
class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  static const _keyShown = 'cyclezen_onboarding_shown';

  Future<bool> _hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyShown) ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFE8F4F8),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 40),

              // ── Tagline ──
              Text(
                'DISCOVER. PLAN. RIDE. SHARE.',
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFECC382).withValues(alpha: 0.85),
                  letterSpacing: 3,
                ),
              ),
              const SizedBox(height: 20),

              // ── Centered card ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFF02494D),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      // Route preview illustration
                      SizedBox(
                        height: 130,
                        child: CustomPaint(
                          size: Size(screenWidth - 56, 130),
                          painter: _CardRoutePainter(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // CycleZen brand inside card
                      const Text(
                        'CycleZen',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // ── Heading ──
              const Text(
                'Your Cycling\nCompanion',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 14),

              // ── Subtitle ──
              Text(
                'Discover, generate, and share\namazing cycling routes.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Montserrat',
                  fontSize: 14.5,
                  color: const Color(0xFF0F172A).withValues(alpha: 0.5),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),

              // ── Start Riding button ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 44),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final done = await _hasCompletedOnboarding();
                      if (!context.mounted) return;
                      if (done) {
                        context.go('/home');
                      } else {
                        context.go('/onboarding');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF02494D),
                      foregroundColor: const Color(0xFFECC382),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Start Riding',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 6),
                        Text('→', style: TextStyle(fontSize: 20)),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // ── Bottom teal bar ──
              Container(
                width: double.infinity,
                height: 80,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF02494D), Color(0xFF001214)],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Center(
                  child: TextButton(
                    onPressed: () => context.pushNamed('auth'),
                    child: Text(
                      'I already have an account',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.5),
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

// ── Card route illustration painter ────────────────────

class _CardRoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Background road network — subtle lighter lines
    final bgPaint = Paint()
      ..color = const Color(0xFF359780).withValues(alpha: 0.2)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    _drawRoad(canvas, size, bgPaint,
        Offset(size.width * 0.1, size.height * 0.8),
        Offset(size.width * 0.55, size.height * 0.15), 0.3);
    _drawRoad(canvas, size, bgPaint,
        Offset(size.width * 0.4, size.height * 0.9),
        Offset(size.width * 0.85, size.height * 0.55), -0.2);

    // Main highlighted route — bright green
    final routePaint = Paint()
      ..color = const Color(0xFF359780)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(size.width * 0.08, size.height * 0.65);
    path.cubicTo(
      size.width * 0.25, size.height * 0.15,
      size.width * 0.55, size.height * 0.7,
      size.width * 0.72, size.height * 0.35,
    );
    path.cubicTo(
      size.width * 0.82, size.height * 0.15,
      size.width * 0.92, size.height * 0.45,
      size.width * 0.95, size.height * 0.3,
    );
    canvas.drawPath(path, routePaint);

    // Gold accent route
    final goldPaint = Paint()
      ..color = const Color(0xFFECC382).withValues(alpha: 0.7)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final goldPath = Path();
    goldPath.moveTo(size.width * 0.05, size.height * 0.8);
    goldPath.cubicTo(
      size.width * 0.3, size.height * 0.5,
      size.width * 0.6, size.height * 0.85,
      size.width * 0.9, size.height * 0.55,
    );
    canvas.drawPath(goldPath, goldPaint);

    // Start pin — gold circle
    final startPaint = Paint()
      ..color = const Color(0xFFECC382)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.08, size.height * 0.65), 7, startPaint);
    final startRing = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(size.width * 0.08, size.height * 0.65), 7, startRing);

    // End pin — white/green flag marker
    final endPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.95, size.height * 0.3), 8, endPaint);
    final endRing = Paint()
      ..color = const Color(0xFFECC382)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(size.width * 0.95, size.height * 0.3), 8, endRing);

    // Checkmark inside end pin
    final checkPaint = Paint()
      ..color = const Color(0xFF02494D)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final checkPath = Path();
    final cx = size.width * 0.95;
    final cy = size.height * 0.3;
    checkPath.moveTo(cx - 3.5, cy);
    checkPath.lineTo(cx - 0.5, cy + 3);
    checkPath.lineTo(cx + 3, cy - 2.5);
    canvas.drawPath(checkPath, checkPaint);

    // Scattered location dots
    final dotPaint = Paint()
      ..color = const Color(0xFFECC382).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    for (final (dx, dy) in [
      (0.35, 0.25), (0.65, 0.4), (0.2, 0.5), (0.5, 0.55), (0.75, 0.65)
    ]) {
      canvas.drawCircle(
        Offset(size.width * dx, size.height * dy), 2, dotPaint);
    }
  }

  void _drawRoad(Canvas canvas, Size size, Paint paint,
      Offset from, Offset to, double curve) {
    final path = Path();
    path.moveTo(from.dx, from.dy);
    final cx = (from.dx + to.dx) / 2 + size.width * curve;
    final cy = (from.dy + to.dy) / 2;
    path.quadraticBezierTo(cx, cy, to.dx, to.dy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
