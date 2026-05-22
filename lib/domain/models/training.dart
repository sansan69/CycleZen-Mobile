import 'package:equatable/equatable.dart';

/// Snapshot of a cyclist's training load at a point in time.
///
/// Based on the Performance Management Chart (PMC) methodology:
///   CTL = 42-day EWMA of daily TSS  (fitness)
///   ATL =  7-day EWMA of daily TSS  (fatigue)
///   TSB = CTL - ATL                  (form: positive = fresh, negative = fatigued)
class TrainingMetrics extends Equatable {
  /// Training Stress Score for the most recent day.
  final int tss;

  /// Chronic Training Load — 42-day exponentially weighted moving average.
  final double ctl;

  /// Acute Training Load — 7-day exponentially weighted moving average.
  final double atl;

  /// Training Stress Balance = CTL - ATL.
  /// * Positive  → fresh / well-rested
  /// * Negative  → accumulating fatigue
  final double tsb;

  /// Total number of rides in the dataset.
  final int totalRides;

  /// Total distance covered across all rides (km).
  final double totalDistance;

  /// Total time spent riding across all rides (seconds).
  final int totalTime;

  const TrainingMetrics({
    required this.tss,
    required this.ctl,
    required this.atl,
    required this.tsb,
    required this.totalRides,
    required this.totalDistance,
    required this.totalTime,
  });

  /// Convenience for an empty / no-ride state.
  static const empty = TrainingMetrics(
    tss: 0,
    ctl: 0,
    atl: 0,
    tsb: 0,
    totalRides: 0,
    totalDistance: 0,
    totalTime: 0,
  );

  /// A human-readable interpretation of the current form state.
  String get formLabel {
    if (tsb > 10) return 'Fresh';
    if (tsb > 0) return 'Rested';
    if (tsb > -10) return 'Neutral';
    if (tsb > -20) return 'Fatigued';
    return 'Overreaching';
  }

  @override
  List<Object?> get props => [tss, ctl, atl, tsb, totalRides, totalDistance, totalTime];
}

/// A single day's training-load values — used for charting the PMC overtime.
class DailyLoad extends Equatable {
  /// ISO-8601 date string (e.g. "2025-01-15").
  final String date;

  /// Sum of TSS for all rides on this date.
  final int tss;

  /// Running CTL as of the end of this date.
  final double ctl;

  /// Running ATL as of the end of this date.
  final double atl;

  /// Running TSB as of the end of this date.
  final double tsb;

  const DailyLoad({
    required this.date,
    required this.tss,
    required this.ctl,
    required this.atl,
    required this.tsb,
  });

  @override
  List<Object?> get props => [date, tss, ctl, atl, tsb];
}
