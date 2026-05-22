import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:cyclezen/domain/models/models.dart';

/// A data point for the elevation profile chart.
class _ElevationPoint {
  final double distanceKm;
  final double elevation;
  final double? grade;

  const _ElevationPoint({
    required this.distanceKm,
    required this.elevation,
    this.grade,
  });
}

/// Displays elevation over distance as a line chart showing the route profile.
///
/// Takes a list of [Coordinate] path data (lat, lng, elevation) and renders
/// an elevation profile using fl_chart. Supports real elevation data when the
/// coordinates include `elev` values, and falls back to simulated data
/// otherwise. Shows max/min labels and matches CycleZen's green theme.
class ElevationProfile extends StatefulWidget {
  /// The route coordinates (lat, lng, optional elevation).
  final List<Coordinate> path;

  /// Total ascent in meters. Used when generating simulated elevation data.
  final double? totalAscent;

  /// Total route distance in kilometers. Computed from coordinates if not
  /// provided.
  final double? totalDistanceKm;

  /// Height of the chart area.
  final double height;

  const ElevationProfile({
    super.key,
    required this.path,
    this.totalAscent,
    this.totalDistanceKm,
    this.height = 200,
  });

  @override
  State<ElevationProfile> createState() => _ElevationProfileState();
}

class _ElevationProfileState extends State<ElevationProfile> {
  List<_ElevationPoint> _data = [];
  double _maxElevation = 0;
  double _minElevation = 0;
  double _avgElevation = 0;
  bool _hasRealData = false;

  @override
  void initState() {
    super.initState();
    _compute();
  }

  @override
  void didUpdateWidget(covariant ElevationProfile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path ||
        oldWidget.totalAscent != widget.totalAscent ||
        oldWidget.totalDistanceKm != widget.totalDistanceKm) {
      _compute();
    }
  }

  void _compute() {
    final coords = widget.path;
    if (coords.length < 2) {
      _data = [];
      _maxElevation = 0;
      _minElevation = 0;
      _avgElevation = 0;
      _hasRealData = false;
      return;
    }

    // Calculate total distance from coordinates
    double totalDist = widget.totalDistanceKm ?? _calcTotalDistance(coords);

    // Check if we have real elevation data
    _hasRealData = coords.any((c) => c.elev != null);

    final totalAscent = widget.totalAscent ?? 0;

    if (_hasRealData) {
      _data = _buildRealElevation(coords);
    } else {
      _data = _buildSimulatedElevation(coords, totalAscent, totalDist);
    }

    if (_data.isNotEmpty) {
      _maxElevation = _data.map((p) => p.elevation).reduce(max);
      _minElevation = _data.map((p) => p.elevation).reduce(min);
      _avgElevation = _data.map((p) => p.elevation).reduce((a, b) => a + b) /
          _data.length;
    }
  }

  /// Approximate total distance from coordinate deltas (km).
  double _calcTotalDistance(List<Coordinate> coords) {
    double dist = 0;
    for (int i = 1; i < coords.length; i++) {
      final prev = coords[i - 1];
      final curr = coords[i];
      final dLat = (curr.lat - prev.lat) * 111.32;
      final dLng = (curr.lng - prev.lng) *
          111.32 *
          cos(prev.lat * pi / 180);
      dist += sqrt(dLat * dLat + dLng * dLng);
    }
    return dist;
  }

  /// Build profile from real elevation data on coordinates.
  List<_ElevationPoint> _buildRealElevation(List<Coordinate> coords) {
    final points = <_ElevationPoint>[];
    double cumulativeDist = 0;

    for (int i = 0; i < coords.length; i++) {
      if (i > 0) {
        final prev = coords[i - 1];
        final curr = coords[i];
        final dLat = (curr.lat - prev.lat) * 111320;
        final dLng = (curr.lng - prev.lng) *
            111320 *
            cos(prev.lat * pi / 180);
        cumulativeDist += sqrt(dLat * dLat + dLng * dLng) / 1000;
      }

      final elev = coords[i].elev ?? 0;

      double? grade;
      if (i > 0 && points.isNotEmpty) {
        final prevPt = points.last;
        final distDiff = cumulativeDist - prevPt.distanceKm;
        final elevDiff = elev - prevPt.elevation;
        if (distDiff > 0.001) {
          grade = (elevDiff / (distDiff * 1000)) * 100;
        }
      }

      points.add(_ElevationPoint(
        distanceKm: double.parse(cumulativeDist.toStringAsFixed(2)),
        elevation: elev.roundToDouble(),
        grade: grade != null
            ? double.parse(grade.toStringAsFixed(1))
            : null,
      ));
    }

    return points;
  }

  /// Simulate elevation with a sinusoidal pattern.
  List<_ElevationPoint> _buildSimulatedElevation(
    List<Coordinate> coords,
    double totalAscent,
    double totalDistanceKm,
  ) {
    final points = <_ElevationPoint>[];
    final numPoints = min(coords.length, 200);
    final step = max(1, coords.length ~/ numPoints);

    final oscillations = 2 + (totalAscent > 200 ? 1 : 0);

    for (int i = 0; i < numPoints && i * step < coords.length; i++) {
      final progress = i / (numPoints - 1);
      final sinComponent = sin(progress * pi * oscillations);
      final hillFactor = 1 - (sinComponent * 0.7).abs();

      final baseElevation = totalAscent * 0.1 +
          totalAscent * 0.8 * sin(progress * pi) * hillFactor;

      final elev = max(0, baseElevation + (Random().nextDouble() - 0.5) * 10);

      double? grade;
      if (i > 0) {
        final prevElev = points.last.elevation;
        final distDiff = (totalDistanceKm / (numPoints - 1)) * 1000;
        if (distDiff > 0.001) {
          grade = ((elev - prevElev) / distDiff) * 100;
        }
      }

      points.add(_ElevationPoint(
        distanceKm: double.parse((progress * totalDistanceKm).toStringAsFixed(2)),
        elevation: elev.roundToDouble(),
        grade: grade != null
            ? double.parse(grade.toStringAsFixed(1))
            : null,
      ));
    }

    return points;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final mutedForeground = theme.colorScheme.onSurface.withValues(alpha: 0.6);

    if (_data.isEmpty) {
      return _buildEmptyState(theme);
    }

    final spots = _data
        .map((p) => FlSpot(p.distanceKm, p.elevation))
        .toList();

    const gridColor = Color(0x20FFFFFF); // subtle white grid on dark

    return Container(
      padding: const EdgeInsets.all(16),
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
          // Header row
          Row(
            children: [
              Icon(
                Icons.show_chart,
                size: 16,
                color: mutedForeground,
              ),
              const SizedBox(width: 6),
              Text(
                'Elevation Profile',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Text(
                'Max: ${_maxElevation.round()} m',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: mutedForeground,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                widget.totalAscent != null && widget.totalAscent! > 0
                    ? 'Gain: +${widget.totalAscent!.round()} m'
                    : 'Min: ${_minElevation.round()} m',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: mutedForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Chart
          SizedBox(
            height: widget.height,
            child: LineChart(
              LineChartData(
                minY: _minElevation - (_maxElevation - _minElevation) * 0.1,
                maxY: _maxElevation + (_maxElevation - _minElevation) * 0.1,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: _calcGridInterval(),
                  getDrawingHorizontalLine: (value) => const FlLine(
                    color: gridColor,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      interval: _calcXInterval(),
                      getTitlesWidget: (value, meta) {
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            '${value.toInt()} km',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                              color: mutedForeground,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      interval: _calcGridInterval(),
                      getTitlesWidget: (value, meta) {
                        return SideTitleWidget(
                          meta: meta,
                          child: Text(
                            '${value.toInt()} m',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                              color: mutedForeground,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  enabled: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (spot) =>
                        theme.colorScheme.surfaceContainerHighest,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final point = _data[spot.spotIndex];
                        final lines = <String>[
                          '${point.distanceKm} km',
                          'Elev: ${point.elevation.round()} m',
                        ];
                        if (point.grade != null) {
                          final sign = point.grade! > 0 ? '+' : '';
                          lines.add('Grade: $sign${point.grade}%');
                        }
                        return LineTooltipItem(
                          lines.join('\n'),
                          TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 12,
                          ),
                        );
                      }).toList();
                    },
                  ),
                  handleBuiltInTouches: true,
                  getTouchedSpotIndicator:
                      (LineChartBarData barData, List<int> spotIndexes) {
                    return spotIndexes.map((index) {
                      return TouchedSpotIndicatorData(
                        FlLine(color: primary, strokeWidth: 1.5),
                        FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, bar, index) =>
                              FlDotCirclePainter(
                            radius: 4,
                            color: primary,
                            strokeWidth: 2,
                            strokeColor: theme.colorScheme.surface,
                          ),
                        ),
                      );
                    }).toList();
                  },
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: primary,
                    barWidth: 2.5,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          primary.withValues(alpha: 0.3),
                          primary.withValues(alpha: 0.02),
                        ],
                      ),
                    ),
                  ),
                ],
                // Average elevation reference line
                extraLinesData: ExtraLinesData(
                  horizontalLines: [
                    HorizontalLine(
                      y: _avgElevation,
                      color: mutedForeground.withValues(alpha: 0.4),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                      label: HorizontalLineLabel(
                        show: true,
                        alignment: Alignment.bottomRight,
                        padding: const EdgeInsets.only(right: 4, bottom: 2),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 9,
                          color: mutedForeground,
                        ),
                        labelResolver: (_) =>
                            'Avg ${_avgElevation.round()}m',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Empty state note when using simulated data
          if (!_hasRealData && _data.length < widget.path.length)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Center(
                child: Text(
                  'ⓘ Elevation data is interpolated',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: mutedForeground,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Container(
      height: widget.height + 80,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          'No elevation data available.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  /// Compute a reasonable Y-axis grid interval.
  double _calcGridInterval() {
    final range = _maxElevation - _minElevation;
    if (range <= 1) return 0.5;
    if (range <= 5) return 1;
    if (range <= 20) return 5;
    if (range <= 100) return 20;
    if (range <= 500) return 100;
    if (range <= 2000) return 200;
    return 500;
  }

  /// Compute a reasonable X-axis label interval based on total distance.
  double _calcXInterval() {
    if (_data.isEmpty) return 1;
    final totalDist = _data.last.distanceKm;
    if (totalDist <= 2) return 0.5;
    if (totalDist <= 5) return 1;
    if (totalDist <= 20) return 5;
    if (totalDist <= 50) return 10;
    if (totalDist <= 200) return 25;
    return 50;
  }
}
