import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cyclezen/domain/models/models.dart';

/// Compact ride summary replacing the elevation profile chart.
///
/// Shows what cyclists actually care about:
/// - Difficulty rating (color-coded badge)
/// - Calorie estimate
/// - Elevation stats as concise text
class RideSummary extends StatelessWidget {
  final CyclingRoute route;

  const RideSummary({super.key, required this.route});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final difficulty = _calcDifficulty(route);
    final calories = _estimateCalories(route);
    final ascent = route.ascentM ?? 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Row(
            children: [
              Icon(Icons.analytics_outlined, size: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
              const SizedBox(width: 6),
              Text('Ride Summary',
                  style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),

          // Three-column stats
          Row(
            children: [
              // ── Difficulty ──
              Expanded(
                child: _SummaryTile(
                  icon: _difficultyIcon(difficulty),
                  iconColor: _difficultyColor(difficulty),
                  label: difficulty.label,
                  value: difficulty.subLabel,
                ),
              ),

              // ── Calories ──
              Expanded(
                child: _SummaryTile(
                  icon: Icons.local_fire_department,
                  iconColor: Colors.orange,
                  label: '~$calories kcal',
                  value: 'Est. burn',
                ),
              ),

              // ── Climbing ──
              Expanded(
                child: _SummaryTile(
                  icon: Icons.terrain,
                  iconColor: ascent > 100
                      ? Colors.red.shade400
                      : theme.colorScheme.primary,
                  label: ascent > 0 ? '↑ ${ascent.round()} m' : 'Flat',
                  value: ascent > 200 ? _climbCategory(ascent) : 'No climbs',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Difficulty ────────────────────────────────────────────

_Difficulty _calcDifficulty(CyclingRoute route) {
  final dist = route.distanceKm;
  final ascent = route.ascentM ?? 0;

  if (dist > 100 || ascent > 1000) {
    return _Difficulty('Extreme', 'Pro level', Icons.warning_amber_rounded,
        Colors.red.shade700);
  }
  if (dist > 50 || ascent > 500) {
    return _Difficulty('Hard', 'Experienced', Icons.fitness_center,
        Colors.orange.shade700);
  }
  if (dist > 20 || ascent > 100) {
    return _Difficulty('Moderate', 'Intermediate', Icons.trending_up,
        Colors.amber.shade700);
  }
  return _Difficulty('Easy', 'Beginner', Icons.check_circle_outline,
      Colors.green.shade600);
}

Color _difficultyColor(_Difficulty d) => d.color;
IconData _difficultyIcon(_Difficulty d) => d.icon;

String _climbCategory(double ascentM) {
  if (ascentM > 1500) return 'HC Climb';
  if (ascentM > 800) return 'Cat 1';
  if (ascentM > 500) return 'Cat 2';
  if (ascentM > 300) return 'Cat 3';
  return 'Cat 4';
}

// ── Calories ──────────────────────────────────────────────

int _estimateCalories(CyclingRoute route) {
  // ~30 kcal per km on flat, + extra for climbing
  const kcalPerKm = 30.0;
  const kcalPerAscentM = 0.15;
  final flatKcal = route.distanceKm * kcalPerKm;
  final climbKcal = (route.ascentM ?? 0) * kcalPerAscentM;
  return (flatKcal + climbKcal).round();
}

// ── Difficulty model ──────────────────────────────────────

class _Difficulty {
  final String label;
  final String subLabel;
  final IconData icon;
  final Color color;
  const _Difficulty(this.label, this.subLabel, this.icon, this.color);
}

// ── Summary tile ──────────────────────────────────────────

class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  const _SummaryTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 22, color: iconColor),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 2),
        Text(value,
            style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
            textAlign: TextAlign.center),
      ],
    );
  }
}
