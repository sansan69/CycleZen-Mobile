import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cyclezen/core/theme/app_theme.dart';
import 'package:cyclezen/core/constants/app_assets.dart';
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

/// Custom page builder with smooth slide transitions for native-feel navigation.
class _SlideTransitionPage extends CustomTransitionPage<void> {
  _SlideTransitionPage({
    required super.child,
    super.key,
  }) : super(
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      // Slide from right + gentle fade
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.08, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        )),
        child: FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: const Interval(0, 0.5, curve: Curves.easeIn),
          ),
          child: child,
        ),
      );
    },
  );
}

class AppRouter {
  final GlobalKey<NavigatorState>? navigatorKey;

  AppRouter({this.navigatorKey});

  late final GoRouter config = GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/splash',
    routes: [
      // Internal splash → always routes to landing
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) => const MaterialPage(
          child: _SplashRedirect(),
        ),
      ),

      // ── Landing (root) ──
      GoRoute(
        path: '/',
        name: 'landing',
        pageBuilder: (context, state) => const MaterialPage(
          child: LandingPage(),
        ),
      ),

      // ── Home (with slide transition) ──
      GoRoute(
        path: '/home',
        name: 'home',
        pageBuilder: (context, state) => _SlideTransitionPage(
          child: const HomePage(),
        ),
      ),

      // ── Onboarding ──
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        pageBuilder: (context, state) => _SlideTransitionPage(
          child: const OnboardingPage(),
        ),
      ),

      // ── Auth ──
      GoRoute(
        path: '/auth',
        name: 'auth',
        pageBuilder: (context, state) => _SlideTransitionPage(
          child: const AuthPage(),
        ),
      ),

      // ── Detail pages ──
      GoRoute(
        path: '/route/:id',
        name: 'route-detail',
        pageBuilder: (context, state) => _SlideTransitionPage(
          child: RouteDetailPage(
            routeId: state.pathParameters['id'] ?? '',
          ),
        ),
      ),
      GoRoute(
        path: '/saved-routes',
        name: 'saved-routes',
        pageBuilder: (context, state) => _SlideTransitionPage(
          child: const SavedRoutesPage(),
        ),
      ),
      GoRoute(
        path: '/ride',
        name: 'ride',
        pageBuilder: (context, state) {
          final route = state.extra;
          if (route is! CyclingRoute) {
            return const MaterialPage(
              child: Scaffold(body: Center(child: Text('Invalid route data'))),
            );
          }
          return _SlideTransitionPage(
            child: UnifiedRidePage(route: route),
          );
        },
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        pageBuilder: (context, state) => _SlideTransitionPage(
          child: const ProfilePage(),
        ),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        pageBuilder: (context, state) => _SlideTransitionPage(
          child: const DashboardPage(),
        ),
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
                          AppAssets.logoMark),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 16),
              Text('CycleZen',
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              SizedBox(height: 24),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: AppTheme.goldRing),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
