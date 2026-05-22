import 'package:flutter/material.dart';
import 'package:cyclezen/domain/models/models.dart';
import 'package:cyclezen/features/home/widgets/route_filter_chips.dart';

class ManualRoutePanel extends StatelessWidget {
  final List<Coordinate> waypoints;
  final bool loading;
  final VoidCallback onGenerate;
  final VoidCallback onClear;
  final RouteFilter filter;
  final ValueChanged<RouteFilter> onFilterChanged;

  const ManualRoutePanel({
    super.key,
    required this.waypoints,
    required this.loading,
    required this.onGenerate,
    required this.onClear,
    required this.filter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Waypoints (${waypoints.length})',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              if (waypoints.isNotEmpty)
                TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (waypoints.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Tap the map to place waypoints.\nAt least 2 points needed for a route.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          if (waypoints.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 120),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: waypoints.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final wp = waypoints[index];
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 12,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    title: Text(
                      '${wp.lat.toStringAsFixed(4)}, ${wp.lng.toStringAsFixed(4)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          RouteFilterChips(
            selected: filter,
            onChanged: onFilterChanged,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: waypoints.length >= 2 && !loading ? onGenerate : null,
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.directions_bike),
            label: Text(loading
                ? 'Getting Route...'
                : 'Get Route (${waypoints.length} pts)'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }
}
