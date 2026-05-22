import 'package:flutter/material.dart';
import '../../../domain/models/achievement.dart';

/// Displays a single achievement badge with its icon, title, description,
/// and either a progress bar (when locked) or the earned date (when unlocked).
///
/// Colors adapt to the app's green cycling theme — unlocked badges glow
/// green; locked badges use muted surface tones.
class AchievementBadge extends StatelessWidget {
  final Achievement achievement;

  /// Progress fraction between 0.0 and 1.0. Only used when the achievement
  /// is locked. Defaults to 0.0 when not provided.
  final double progress;

  const AchievementBadge({
    super.key,
    required this.achievement,
    this.progress = 0.0,
  });

  // ── Icon mapping ──────────────────────────────────────

  static const Map<String, IconData> _iconMap = {
    'pedal_bike': Icons.pedal_bike,
    'directions_bike': Icons.directions_bike,
    'route': Icons.route,
    'straighten': Icons.straighten,
    'emoji_events': Icons.emoji_events,
    'military_tech': Icons.military_tech,
    'workspace_premium': Icons.workspace_premium,
    'wb_sunny': Icons.wb_sunny,
    'nightlight_round': Icons.nightlight_round,
    'speed': Icons.speed,
    'terrain': Icons.terrain,
    'timer': Icons.timer,
  };

  IconData get _icon => _iconMap[achievement.icon] ?? Icons.emoji_events;

  // ── Theme-aware colours ───────────────────────────────

  Color _accentColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return achievement.isUnlocked
        ? const Color(0xFF22C55E) // Cycling green
        : brightness == Brightness.dark
            ? Colors.grey.shade700
            : Colors.grey.shade400;
  }

  Color _backgroundColor(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return achievement.isUnlocked
        ? (brightness == Brightness.dark
            ? const Color(0xFF22C55E).withOpacity(0.12)
            : const Color(0xFF22C55E).withOpacity(0.08))
        : (brightness == Brightness.dark
            ? const Color(0xFF1A1A2E)
            : Colors.grey.shade100);
  }

  // ── Build ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.isUnlocked;
    final theme = Theme.of(context);
    final accent = _accentColor(context);
    final bg = _backgroundColor(context);
    final clampedProgress = progress.clamp(0.0, 1.0);

    return Card(
      elevation: unlocked ? 2 : 0,
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: unlocked ? accent.withOpacity(0.5) : Colors.transparent,
          width: unlocked ? 1.5 : 0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Icon ──
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withOpacity(unlocked ? 0.2 : 0.1),
              ),
              child: Icon(_icon, color: accent, size: 26),
            ),
            const SizedBox(height: 10),

            // ── Title ──
            Text(
              achievement.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: unlocked
                    ? accent
                    : theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),

            // ── Description ──
            Text(
              achievement.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),

            // ── Progress bar (locked) or earned date (unlocked) ──
            if (unlocked)
              Text(
                'Earned ${_formatDate(achievement.earnedAt!)}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: accent.withOpacity(0.8),
                  fontWeight: FontWeight.w500,
                ),
              )
            else ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: clampedProgress,
                  minHeight: 6,
                  backgroundColor: accent.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation(accent),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(clampedProgress * 100).toInt()}%',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}
