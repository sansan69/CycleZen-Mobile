import 'package:flutter/material.dart';
import 'package:cyclezen/data/services/weather_service.dart';

/// Compact weather widget for the home page.
/// Shows current conditions, temperature, wind, and cycling advice.
class WeatherWidget extends StatelessWidget {
  final WeatherData? weather;
  final bool loading;

  const WeatherWidget({super.key, this.weather, this.loading = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: loading
            ? const Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)))
            : weather == null
                ? _buildError(theme)
                : _buildContent(context, theme),
      ),
    );
  }

  Widget _buildError(ThemeData theme) {
    return Row(
      children: [
        const Icon(Icons.cloud_off, size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        Text('Weather unavailable', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
      ],
    );
  }

  Widget _buildContent(BuildContext context, ThemeData theme) {
    final w = weather!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(w.weatherIcon, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Text(
              '${w.temperature.round()}°C  ${w.conditions}',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Icon(Icons.air, size: 14, color: theme.colorScheme.primary),
            const SizedBox(width: 4),
            Text('${w.windSpeed.round()} km/h', style: theme.textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          w.cyclingAdvice,
          style: theme.textTheme.bodySmall?.copyWith(
            color: w.cyclingAdvice.startsWith('✅')
                ? Colors.green
                : w.cyclingAdvice.startsWith('⚠️')
                    ? Colors.red.shade400
                    : Colors.orange,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
