import 'package:flutter/material.dart';
import 'package:cyclezen/domain/models/models.dart';

/// Reusable filter chips for AI and Manual route generation panels.
class RouteFilterChips extends StatelessWidget {
  final RouteFilter selected;
  final ValueChanged<RouteFilter> onChanged;

  const RouteFilterChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            'Route Style',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: RouteFilter.values.map((filter) {
            final isSelected = selected == filter;
            return _FilterChip(
              label: filter.label,
              icon: _iconFor(filter),
              isSelected: isSelected,
              isDark: isDark,
              onTap: () => onChanged(filter),
            );
          }).toList(),
        ),
      ],
    );
  }

  IconData _iconFor(RouteFilter filter) {
    return switch (filter) {
      RouteFilter.fastest => Icons.speed,
      RouteFilter.lessTraffic => Icons.traffic,
      RouteFilter.scenic => Icons.landscape,
      RouteFilter.villageRoads => Icons.nature_people,
    };
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Material(
      color: isSelected
          ? primary.withValues(alpha: isDark ? 0.25 : 0.12)
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? primary : theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? primary : theme.colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
