import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../domain/models/models.dart';
import '../../../../domain/models/achievement.dart';
import '../../../../data/services/achievement_service.dart';
import 'achievement_badge.dart';

/// A responsive grid that displays every cycling achievement — both unlocked
/// and locked — with progress bars for those still in progress.
///
/// Accepts an optional [AchievementService] instance and a list of
/// [RideRecording] rides to compute unlocked achievements and progress.
/// Alternatively, supply [achievements] and [progress] map directly.
class AchievementsGrid extends StatelessWidget {
  /// Pre-computed list of achievements. If not provided, computed from rides.
  final List<Achievement>? achievements;

  /// Progress values keyed by achievement id. If not provided, computed.
  final Map<String, double>? progress;

  /// The rides to evaluate achievements against.
  final List<RideRecording>? rides;

  /// Optional service instance (defaults to a cached instance).
  final AchievementService? service;

  static final AchievementService _defaultService = AchievementService();

  /// Whether the grid is in a loading state.
  final bool loading;

  /// Max cross-axis count for the grid (defaults to 2).
  final int crossAxisCount;

  const AchievementsGrid({
    super.key,
    this.achievements,
    this.progress,
    this.rides,
    this.service,
    this.loading = false,
    this.crossAxisCount = 2,
  });

  @override
  Widget build(BuildContext context) {
    // ── Loading state ──
    if (loading) {
      return _buildLoadingGrid(context);
    }

    // ── Resolve data ──
    final effectiveService = service ?? _defaultService;
    List<Achievement> resolvedAchievements;
    Map<String, double> resolvedProgress;

    if (achievements != null && progress != null) {
      resolvedAchievements = achievements!;
      resolvedProgress = progress!;
    } else if (rides != null) {
      // Use the rides list directly
      final rideList = rides!;
      resolvedAchievements = effectiveService.calculateAchievements(rideList);
      resolvedProgress = effectiveService.getProgress(rideList);
    } else {
      // Show all definitions in locked state
      resolvedAchievements = AchievementService.definitions
          .map((def) => def.copyWith(clearEarnedAt: true))
          .toList();
      resolvedProgress = {};
    }

    // ── Empty state ──
    if (resolvedAchievements.isEmpty) {
      return _buildEmptyState(context);
    }

    // Separate unlocked and locked for sorted display
    final unlocked = resolvedAchievements
        .where((a) => a.isUnlocked)
        .toList();
    final locked = resolvedAchievements
        .where((a) => !a.isUnlocked)
        .toList();

    final sorted = [...unlocked, ...locked];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ──
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Text(
                'Achievements',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${unlocked.length}/${resolvedAchievements.length}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: const Color(0xFF22C55E),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ],
          ),
        ),

        // ── Grid ──
        LayoutBuilder(
          builder: (context, constraints) {
            // Responsive: use fewer columns on narrow screens
            final effectiveColumns =
                constraints.maxWidth < 360 ? 2 : crossAxisCount;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: effectiveColumns,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: sorted.length,
              itemBuilder: (context, index) {
                final achievement = sorted[index];
                final prog = resolvedProgress[achievement.id] ?? 0.0;
                final fraction = achievement.requiredValue > 0
                    ? (prog / achievement.requiredValue).clamp(0.0, 1.0)
                    : 0.0;

                return AchievementBadge(
                  achievement: achievement,
                  progress: fraction,
                ).animate().fadeIn(delay: (100 * index).ms, duration: 400.ms).scale(begin: const Offset(0.85, 0.85));
              },
            );
          },
        ),
      ],
    );
  }

  // ── Loading skeleton ──────────────────────────────────

  Widget _buildLoadingGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Achievements',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: 6,
          itemBuilder: (context, index) {
            return Card(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF1A1A2E)
                  : Colors.grey.shade100,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          },
        ),
      ],
    );
  }

  // ── Empty state ───────────────────────────────────────

  Widget _buildEmptyState(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Achievements',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Column(
            children: [
              Icon(
                Icons.emoji_events_outlined,
                size: 64,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.3),
              ),
              const SizedBox(height: 12),
              Text(
                'No achievements yet. Go ride!',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                'Complete rides to earn badges for distance,\nclimbing, consistency, and more.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.4),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
