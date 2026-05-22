import 'package:flutter/material.dart';
import 'package:cyclezen/domain/models/models.dart';
import 'package:cyclezen/features/home/widgets/ride_summary.dart';

class RouteCard extends StatelessWidget {
  final CyclingRoute route;
  final VoidCallback? onSave;
  final VoidCallback? onRide;
  final VoidCallback? onExportGpx;
  final VoidCallback? onTap;
  final bool isSelected;

  const RouteCard({
    super.key,
    required this.route,
    this.onSave,
    this.onRide,
    this.onExportGpx,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? BorderSide(color: theme.colorScheme.primary, width: 2.5)
            : BorderSide.none,
      ),
      elevation: isSelected ? 4 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    isSelected ? Icons.route : Icons.route_outlined,
                    color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      route.routeName ?? 'Cycling Route',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'On map',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Stats row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatChip(icon: Icons.straighten, label: '${route.distanceKm.toStringAsFixed(1)} km'),
                  _StatChip(icon: Icons.timer, label: '${route.estimatedTimeMin.round()} min'),
                  if (route.ascentM != null)
                    _StatChip(icon: Icons.terrain, label: '${route.ascentM!.round()} m↑'),
                  _StatChip(icon: Icons.pin_drop, label: '${route.coordinates.length} pts'),
                ],
              ),
              const SizedBox(height: 12),

              // Ride summary (replaces elevation chart)
              RideSummary(route: route),
              const SizedBox(height: 12),

              // Buttons: Ride (primary) + Save + Export
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  if (onRide != null)
                    _ActionButton(icon: Icons.directions_bike, label: 'Start Ride', onTap: onRide!, isPrimary: true),
                  if (onSave != null)
                    _ActionButton(icon: Icons.bookmark_border, label: 'Save', onTap: onSave!),
                  if (onExportGpx != null)
                    _ActionButton(icon: Icons.share, label: 'GPX', onTap: onExportGpx!),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _StatChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;
  const _ActionButton({required this.icon, required this.label, required this.onTap, this.isPrimary = false});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        foregroundColor: isPrimary
            ? Theme.of(context).colorScheme.onPrimary
            : Theme.of(context).colorScheme.onSurface,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}
