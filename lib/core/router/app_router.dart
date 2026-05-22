import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cyclezen/core/theme/app_theme.dart';
import 'package:cyclezen/domain/models/models.dart';
import 'package:cyclezen/features/landing/pages/landing_page.dart';
import 'package:cyclezen/features/auth/pages/auth_page.dart';
import 'package:cyclezen/features/home/pages/home_page.dart';
import 'package:cyclezen/features/routes/pages/route_detail_page.dart';
import 'package:cyclezen/features/routes/pages/saved_routes_page.dart';
import 'package:cyclezen/features/ride/pages/unified_ride_page.dart';
import 'package:cyclezen/features/profile/pages/profile_page.dart';
import 'package:cyclezen/features/dashboard/pages/dashboard_page.dart';
import 'package:cyclezen/features/onboarding/pages/onboarding_page.dart';

class AppRouter {
  late final GoRouter config = GoRouter(
    initialLocation: '/splash',
    routes: [
      // Internal splash → always routes to landing
      GoRoute(
        path: '/splash',
        builder: (context, state) => const _SplashRedirect(),
      ),

      // ── Landing (root) ──
      GoRoute(
        path: '/',
        name: 'landing',
        builder: (context, state) => const LandingPage(),
      ),

      // ── Home ──
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomePage(),
      ),

      // ── Onboarding ──
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),

      // ── Auth ──
      GoRoute(
        path: '/auth',
        name: 'auth',
        builder: (context, state) => const AuthPage(),
      ),

      // ── Detail pages ──
      GoRoute(
        path: '/route/:id',
        name: 'route-detail',
        builder: (context, state) => RouteDetailPage(
          routeId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/saved-routes',
        name: 'saved-routes',
        builder: (context, state) => const SavedRoutesPage(),
      ),
      GoRoute(
        path: '/ride',
        name: 'ride',
        builder: (context, state) => UnifiedRidePage(
          route: state.extra as CyclingRoute,
        ),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const DashboardPage(),
      ),
    ],
  );
}

/// Minimal splash that always routes to the landing page.
class _SplashRedirect extends StatefulWidget {
  const _SplashRedirect();
  @override
  State<_SplashRedirect> createState() => _SplashRedirectState();
}

class _SplashRedirectState extends State<_SplashRedirect> {
  @override
  void initState() {
    super.initState();
    // Brief pause so splash is visible, then go to landing
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) context.go('/');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppTheme.brandGradient),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 104,
                height: 104,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                  child: Padding(
                    padding: EdgeInsets.all(4),
                    child: Image(
                      image: AssetImage(
                          'assets/images/cyclezen_mark_transparent.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text('CycleZen',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              SizedBox(height: 24),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Color(0xFFECC382)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
