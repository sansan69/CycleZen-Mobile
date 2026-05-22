import 'package:flutter/material.dart';
import 'package:cyclezen/domain/models/models.dart';
import 'package:cyclezen/features/home/widgets/route_filter_chips.dart';

class AIRoutePanel extends StatelessWidget {
  final double radiusKm;
  final ValueChanged<double> onRadiusChanged;
  final bool loading;
  final VoidCallback onGenerate;
  final bool hasLocation;
  final RouteFilter filter;
  final ValueChanged<RouteFilter> onFilterChanged;

  const AIRoutePanel({
    super.key,
    required this.radiusKm,
    required this.onRadiusChanged,
    required this.loading,
    required this.onGenerate,
    required this.hasLocation,
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
          Text(
            'Target Distance',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: radiusKm,
                  min: 5,
                  max: 100,
                  divisions: 95,
                  label: '${radiusKm.round()} km',
                  onChanged: onRadiusChanged,
                ),
              ),
              SizedBox(
                width: 60,
                child: Text(
                  '${radiusKm.round()} km',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RouteFilterChips(
            selected: filter,
            onChanged: onFilterChanged,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: hasLocation && !loading ? onGenerate : null,
            icon: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
            label: Text(loading ? 'Generating...' : 'Generate Routes'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          if (!hasLocation)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Tap the map to select a starting point',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }
}
