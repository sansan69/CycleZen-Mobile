import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cyclezen/core/theme/app_theme.dart';

/// Onboarding shown on first launch only.
/// 4 screens introducing CycleZen, ending with Sign In / Get Started.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  static const _keyShown = 'cyclezen_onboarding_shown';

  /// Returns true if onboarding has been completed before.
  static Future<bool> hasBeenShown() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyShown) ?? false;
  }

  /// Mark onboarding as completed so it's never shown again.
  static Future<void> markShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyShown, true);
  }

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.animateToPage(_currentPage + 1,
          duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    } else {
      _finish();
    }
  }

  void _finish() async {
    await OnboardingPage.markShown();
    if (mounted) context.go('/home');
  }

  void _goToAuth() async {
    await OnboardingPage.markShown();
    if (mounted) context.pushNamed('auth');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 16, top: 8),
                child: TextButton(
                  onPressed: _finish,
                  child: Text('Skip',
                      style: TextStyle(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                ),
              ),
            ),

            // PageView
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (p) => setState(() => _currentPage = p),
                children: [
                  _buildSlide(
                    icon: Icons.explore_outlined,
                    title: 'Discover Routes',
                    subtitle: 'Find the best cycling routes near you.\nAI-powered suggestions based on\nyour preferences and location.',
                    color: AppTheme.greenAccent,
                  ),
                  _buildSlide(
                    icon: Icons.route_outlined,
                    title: 'Plan & Navigate',
                    subtitle: 'Create custom routes with waypoints.\nGet turn-by-turn voice navigation\nand real-time weather updates.',
                    color: AppTheme.secondaryTeal,
                  ),
                  _buildSlide(
                    icon: Icons.trending_up,
                    title: 'Track & Improve',
                    subtitle: 'Record every ride with GPS tracking.\nMonitor your training load, calories,\nand unlock achievements.',
                    color: AppTheme.goldRing,
                  ),
                  _buildSlide(
                    icon: Icons.groups_outlined,
                    title: 'Ride Together',
                    subtitle: 'Share routes with friends.\nCompare stats, earn badges,\nand build your cycling legacy.',
                    color: AppTheme.primaryDark,
                    isLast: true,
                  ),
                ],
              ),
            ),

            // Dots + Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Column(
                children: [
                  // Page dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (i) {
                      final isActive = i == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),

                  // Action buttons
                  if (_currentPage < 3) ...[
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Next'),
                      ),
                    ),
                  ] else ...[
                    // Last page: Sign In + Get Started
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _goToAuth,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: AppTheme.greenAccent,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Sign In / Sign Up'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _finish,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Explore the App'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    bool isLast = false,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon in colored circle
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 56, color: color),
          ),
          const SizedBox(height: 48),
          Text(title,
              style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(subtitle,
              style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  height: 1.5),
              textAlign: TextAlign.center),
          const SizedBox(height: 48),
          // Brand tagline on last slide
          if (isLast)
            Text('DISCOVER • PLAN • RIDE • SHARE',
                style: theme.textTheme.labelMedium?.copyWith(
                    letterSpacing: 2,
                    color: AppTheme.secondaryTeal,
                    fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
