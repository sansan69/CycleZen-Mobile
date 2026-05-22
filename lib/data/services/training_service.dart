import 'dart:math';

import '../../domain/models/models.dart';
import '../../domain/models/training.dart';

/// Service that calculates cycling training metrics using the
/// Performance Management Chart (PMC) methodology.
///
/// Reference formulas are drawn from the Next.js training module at
/// ~/cyclezen/src/shared/lib/training.ts (TSS, intensity factors)
/// and standard CTL/ATL/TSB EWMA formulas.
class TrainingService {
  // ── Constants (matching training.ts) ──────────────────

  static const double _defaultWeightKg = 70;

  /// Intensity factors by difficulty — exact match to training.ts.
  static const Map<String, double> intensityFactors = {
    'Easy': 0.55,
    'Moderate': 0.65,
    'Hard': 0.80,
    'Expert': 0.95,
  };

  static const double _defaultIF = 0.65;

  // EWMA time constants (days).
  static const int _ctlDays = 42;
  static const int _atlDays = 7;

  // ── Public API ────────────────────────────────────────

  /// Compute a snapshot of the current training state.
  ///
  /// Sorts [rides] by completion date, aggregates daily TSS, then walks
  /// forward day-by-day to compute running CTL / ATL / TSB.  Returns the
  /// final values (latest day) plus cumulative ride totals.
  TrainingMetrics calculateMetrics(List<RideRecording> rides) {
    if (rides.isEmpty) return TrainingMetrics.empty;

    final daily = _buildDailyTSSMap(rides);
    if (daily.isEmpty) return TrainingMetrics.empty;

    // Sum totals for the snapshot.
    double totalDistance = 0;
    int totalTime = 0;
    for (final ride in rides) {
      totalDistance += ride.actualDistanceKm;
      totalTime += ride.actualDurationSec.round();
    }

    // Walk the daily map in chronological order, computing EWMA.
    final sortedDates = daily.keys.toList()..sort();
    double ctl = 0;
    double atl = 0;
    int lastTSS = 0;

    for (final date in sortedDates) {
      final tss = daily[date]!;
      ctl = ctl + (tss - ctl) / _ctlDays;
      atl = atl + (tss - atl) / _atlDays;
      lastTSS = tss;
    }

    return TrainingMetrics(
      tss: lastTSS,
      ctl: _round2(ctl),
      atl: _round2(atl),
      tsb: _round2(ctl - atl),
      totalRides: rides.length,
      totalDistance: _round2(totalDistance),
      totalTime: totalTime,
    );
  }

  /// Build the full day-by-day PMC history for charting.
  ///
  /// Returns one [DailyLoad] entry per calendar date that has at least one
  /// ride.  Each entry includes the running CTL/ATL/TSB values as of the
  /// end of that day.
  List<DailyLoad> getDailyLoadHistory(List<RideRecording> rides) {
    if (rides.isEmpty) return [];

    final daily = _buildDailyTSSMap(rides);
    if (daily.isEmpty) return [];

    final sortedDates = daily.keys.toList()..sort();
    final List<DailyLoad> history = [];

    double ctl = 0;
    double atl = 0;

    for (final date in sortedDates) {
      final tss = daily[date]!;
      ctl = ctl + (tss - ctl) / _ctlDays;
      atl = atl + (tss - atl) / _atlDays;

      history.add(DailyLoad(
        date: date,
        tss: tss,
        ctl: _round2(ctl),
        atl: _round2(atl),
        tsb: _round2(ctl - atl),
      ));
    }

    return history;
  }

  // ── TSS (exact match to training.ts) ──────────────────

  /// Calculate TSS for a single ride using the formula:
  ///   TSS = (minutes × IF² × 100) / 60
  ///
  /// This is the **exact** formula from training.ts `calculateTSS()`.
  int calculateTSS(double rideMinutes, double intensityFactor) {
    if (rideMinutes <= 0 || intensityFactor <= 0) return 0;
    return ((rideMinutes * pow(intensityFactor, 2) * 100) / 60).round();
  }

  /// Convenience: calculate TSS directly from a [RideRecording].
  ///
  /// Infers the intensity factor from the ride's difficulty / ascent ratio.
  /// Mirrors `calculateRideTSS()` in training.ts.
  int calculateRideTSS(RideRecording ride) {
    final minutes = ride.actualDurationSec / 60;
    final if_ = _getIntensityFactor(ride);
    return calculateTSS(minutes, if_);
  }

  // ── FTP Estimation (matching training.ts) ─────────────

  /// Estimate Functional Threshold Power without a power meter.
  ///
  /// Formula (training.ts `estimateFTP()`):
  ///   FTP = (bestAvgSpeedKmh × weightKg × 3.5) / 200
  int estimateFTP(List<RideRecording> rides) {
    if (rides.isEmpty) return 0;

    double bestSpeed = 0;
    for (final ride in rides) {
      if (ride.avgSpeedKmh > bestSpeed) {
        bestSpeed = ride.avgSpeedKmh;
      }
    }

    if (bestSpeed <= 0) return 0;
    return ((bestSpeed * _defaultWeightKg * 3.5) / 200).round();
  }

  // ── Weekly Load (matching training.ts) ────────────────

  /// Calculate weekly training load and trend.
  ///
  /// Sums TSS for the past 7 days and compares against the previous 7 days.
  /// Mirrors `calculateWeeklyLoad()` in training.ts.
  WeeklyLoadResult calculateWeeklyLoad(
    List<RideRecording> rides, {
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final fourteenDaysAgo = now.subtract(const Duration(days: 14));

    // Current week (past 7 days) — date >= sevenDaysAgo && date <= now
    final currentWeekRides = rides.where((ride) {
      final date = ride.completedAt;
      return !date.isBefore(sevenDaysAgo) && !date.isAfter(now);
    });

    // Previous week (8–14 days ago) — date >= fourteenDaysAgo && date < sevenDaysAgo
    final previousWeekRides = rides.where((ride) {
      final date = ride.completedAt;
      return !date.isBefore(fourteenDaysAgo) && date.isBefore(sevenDaysAgo);
    });

    final currentLoad =
        currentWeekRides.fold<int>(0, (sum, ride) => sum + calculateRideTSS(ride));
    final previousLoad =
        previousWeekRides.fold<int>(0, (sum, ride) => sum + calculateRideTSS(ride));

    // Determine trend
    String trend;
    String trendLabel;
    if (previousLoad == 0) {
      trend = currentLoad > 0 ? '↑' : '→';
      trendLabel = currentLoad > 0 ? 'increasing' : 'stable';
    } else {
      final change = (currentLoad - previousLoad) / previousLoad;
      if (change > 0.1) {
        trend = '↑';
        trendLabel = 'increasing';
      } else if (change < -0.1) {
        trend = '↓';
        trendLabel = 'decreasing';
      } else {
        trend = '→';
        trendLabel = 'stable';
      }
    }

    // Recovery recommendation
    String recommendation;
    if (currentLoad > 500) {
      recommendation =
          'Rest day recommended — your training load is high. Take 1–2 days off for recovery.';
    } else if (currentLoad > 350) {
      recommendation =
          'Consider an easy spin or active recovery day. Keep intensity low.';
    } else if (currentLoad > 0) {
      recommendation = "You're in a good training zone. Continue as planned.";
    } else {
      recommendation = 'No rides this week. Get out and ride!';
    }

    return WeeklyLoadResult(
      load: currentLoad,
      trend: trend,
      trendLabel: trendLabel,
      recommendation: recommendation,
    );
  }

  // ── Training Load Chart Data (matching training.ts) ───

  /// Build daily TSS data for the past N days.
  ///
  /// Returns one entry per calendar date for the specified window.
  /// Mirrors `buildTrainingLoadData()` in training.ts.
  List<TrainingLoadData> buildTrainingLoadData(
    List<RideRecording> rides, {
    int days = 14,
  }) {
    final result = <TrainingLoadData>[];
    final now = DateTime.now();

    for (int i = days - 1; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dateStr = _dateKey(date);

      // Find rides on this calendar date
      final dayRides = rides.where((ride) {
        return _dateKey(ride.completedAt) == dateStr;
      });

      final tss = dayRides.fold<int>(0, (sum, ride) => sum + calculateRideTSS(ride));
      result.add(TrainingLoadData(date: dateStr, tss: tss));
    }

    return result;
  }

  /// Get a color for a bar based on TSS value.
  /// (Returns a Flutter Color code as 0xAARRGGBB int.)
  static int getTSSColor(int tss) {
    if (tss < 50) return 0xFF22C55E; // green-500
    if (tss < 100) return 0xFFEAB308; // yellow-500
    if (tss < 150) return 0xFFF97316; // orange-500
    return 0xFFEF4444; // red-500
  }

  // ── Private helpers ──────────────────────────────────

  /// Build a map of ISO date → total TSS for that day.
  Map<String, int> _buildDailyTSSMap(List<RideRecording> rides) {
    final map = <String, int>{};
    for (final ride in rides) {
      final key = _dateKey(ride.completedAt);
      map[key] = (map[key] ?? 0) + calculateRideTSS(ride);
    }
    return map;
  }

  /// Infer intensity factor from the ride, matching training.ts logic.
  ///
  /// 1. If the route has an explicit difficulty field in the future, use it.
  /// 2. Otherwise, infer from ascent/distance ratio.
  /// 3. Default to "Moderate" (IF = 0.65).
  double _getIntensityFactor(RideRecording ride) {
    // Infer difficulty from ascent/distance ratio (training.ts getDifficultyFromRide)
    final ascent = ride.route.ascentM;
    if (ascent != null && ascent > 0 && ride.actualDistanceKm > 0) {
      final ratio = ascent / ride.actualDistanceKm;
      if (ratio < 15) return intensityFactors['Easy']!;
      if (ratio < 30) return intensityFactors['Moderate']!;
      if (ratio < 50) return intensityFactors['Hard']!;
      return intensityFactors['Expert']!;
    }
    return _defaultIF;
  }

  /// Return "YYYY-MM-DD" string for a [DateTime].
  String _dateKey(DateTime dt) {
    return '${dt.year}-${_pad2(dt.month)}-${_pad2(dt.day)}';
  }

  String _pad2(int n) => n.toString().padLeft(2, '0');

  double _round2(double v) {
    return (v * 100).roundToDouble() / 100;
  }
}

// ── Simple result types (mirror training.ts return shapes) ──

/// Result of weekly load calculation.
class WeeklyLoadResult {
  final int load;
  final String trend;
  final String trendLabel;
  final String recommendation;

  const WeeklyLoadResult({
    required this.load,
    required this.trend,
    required this.trendLabel,
    required this.recommendation,
  });
}

/// A single day's TSS for chart display.
class TrainingLoadData {
  final String date;
  final int tss;

  const TrainingLoadData({required this.date, required this.tss});
}
