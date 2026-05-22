import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/models.dart';
import '../../domain/models/achievement.dart';

/// Service that defines cycling achievements and evaluates whether a set of
/// completed rides unlocks any of them.
class AchievementService {
  // ── Firestore collection helpers ──────────────────────

  final FirebaseFirestore _firestore;

  AchievementService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // ── Achievement Definitions ───────────────────────────

  /// The complete catalogue of cycling achievements.
  /// Each definition includes the threshold [requiredValue] and the [type]
  /// of metric it tracks.
  static const List<Achievement> definitions = [
    // ── Ride-count milestones ──
    Achievement(
      id: 'first_ride',
      title: 'First Ride',
      description: 'Complete your very first ride',
      icon: 'pedal_bike',
      requiredValue: 1,
      type: 'totalRides',
    ),
    Achievement(
      id: 'getting_started',
      title: 'Getting Started',
      description: 'Complete 5 rides',
      icon: 'directions_bike',
      requiredValue: 5,
      type: 'totalRides',
    ),
    Achievement(
      id: 'road_warrior',
      title: 'Road Warrior',
      description: 'Complete 25 rides',
      icon: 'route',
      requiredValue: 25,
      type: 'totalRides',
    ),

    // ── Distance milestones ──
    Achievement(
      id: 'five_k',
      title: '5K Rider',
      description: 'Ride a total of 5 kilometers',
      icon: 'straighten',
      requiredValue: 5.0,
      type: 'distance',
    ),
    Achievement(
      id: 'century_club',
      title: '100km Club',
      description: 'Ride a total of 100 kilometers',
      icon: 'emoji_events',
      requiredValue: 100.0,
      type: 'distance',
    ),
    Achievement(
      id: 'millennium_rider',
      title: '1000km Legend',
      description: 'Ride a total of 1,000 kilometers',
      icon: 'military_tech',
      requiredValue: 1000.0,
      type: 'distance',
    ),

    // ── Single-ride feats ──
    Achievement(
      id: 'century_ride',
      title: 'Century Ride',
      description: 'Complete a single ride of 100 km or more',
      icon: 'workspace_premium',
      requiredValue: 100.0,
      type: 'distance',
    ),
    Achievement(
      id: 'early_bird',
      title: 'Early Bird',
      description: 'Start a ride before 7:00 AM',
      icon: 'wb_sunny',
      requiredValue: 1,
      type: 'totalRides',
    ),
    Achievement(
      id: 'night_owl',
      title: 'Night Owl',
      description: 'Start a ride after 10:00 PM',
      icon: 'nightlight_round',
      requiredValue: 1,
      type: 'totalRides',
    ),
    Achievement(
      id: 'speed_demon',
      title: 'Speed Demon',
      description: 'Average speed above 30 km/h on any ride',
      icon: 'speed',
      requiredValue: 30.0,
      type: 'totalRides',
    ),

    // ── Elevation milestone ──
    Achievement(
      id: 'mountain_goat',
      title: 'Mountain Goat',
      description: 'Climb a total of 1,000 meters',
      icon: 'terrain',
      requiredValue: 1000.0,
      type: 'elevation',
    ),

    // ── Time milestone ──
    Achievement(
      id: 'time_traveler',
      title: 'Time Traveler',
      description: 'Spend 10 hours in the saddle',
      icon: 'timer',
      requiredValue: 36000, // 10 hours in seconds
      type: 'totalTime',
    ),
  ];

  /// Quick lookup of a definition by id.
  static Achievement? definitionById(String id) {
    try {
      return definitions.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  // ── Core calculation ─────────────────────────────────

  /// Evaluates every achievement against the provided [rides] and returns a
  /// list of [Achievement] objects.
  ///
  /// * Unlocked achievements have [Achievement.earnedAt] set to the date the
  ///   threshold was crossed.
  /// * Locked achievements have [earnedAt] == null (use [getProgress] to
  ///   obtain the current progress value for display).
  List<Achievement> calculateAchievements(List<RideRecording> rides) {
    if (rides.isEmpty) {
      return definitions
          .map((def) => def.copyWith(clearEarnedAt: true))
          .toList();
    }

    // Sort rides by completion date (oldest first) so we can pin the
    // "earned at" date to the ride that crossed the threshold.
    final sorted =
        List<RideRecording>.from(rides)
          ..sort((a, b) => a.completedAt.compareTo(b.completedAt));

    // ── Aggregate totals ──
    double totalDistanceKm = 0;
    double totalDurationSec = 0;
    double totalAscent = 0;
    int totalRides = sorted.length;

    for (final ride in sorted) {
      totalDistanceKm += ride.actualDistanceKm;
      totalDurationSec += ride.actualDurationSec;
      totalAscent += ride.route.ascentM ?? 0;
    }

    // ── Evaluate each definition ──
    final Map<String, Achievement> results = {};
    for (final def in definitions) {
      results[def.id] = _evaluate(
        def,
        sorted,
        totalDistanceKm,
        totalRides,
        totalDurationSec,
        totalAscent,
      );
    }

    return results.values.toList();
  }

  /// Returns current progress for each achievement as a map of id → value
  /// (in the achievement's native unit).
  Map<String, double> getProgress(List<RideRecording> rides) {
    double totalDistanceKm = 0;
    double totalDurationSec = 0;
    double totalAscent = 0;
    int totalRides = rides.length;

    for (final ride in rides) {
      totalDistanceKm += ride.actualDistanceKm;
      totalDurationSec += ride.actualDurationSec;
      totalAscent += ride.route.ascentM ?? 0;
    }

    final Map<String, double> progress = {};
    for (final def in definitions) {
      switch (def.type) {
        case 'totalRides':
          // For special single-ride checks (early_bird, night_owl, speed_demon),
          // progress = 1 if at least one ride qualifies.
          if (def.id == 'early_bird') {
            final hasIt = rides.any(
              (r) => r.completedAt.hour < 7,
            );
            progress[def.id] = hasIt ? 1.0 : 0.0;
          } else if (def.id == 'night_owl') {
            final hasIt = rides.any(
              (r) =>
                  r.completedAt.hour >= 22 || r.completedAt.hour < 4,
            );
            progress[def.id] = hasIt ? 1.0 : 0.0;
          } else if (def.id == 'speed_demon') {
            final hasIt = rides.any((r) => r.avgSpeedKmh >= 30.0);
            progress[def.id] = hasIt ? 1.0 : 0.0;
          } else {
            progress[def.id] = totalRides.toDouble();
          }
          break;
        case 'distance':
          if (def.id == 'century_ride') {
            // Single-ride century
            final hasIt = rides.any((r) => r.actualDistanceKm >= 100.0);
            progress[def.id] = hasIt ? 100.0 : (rides.isNotEmpty
                ? rides.map((r) => r.actualDistanceKm).reduce(
                    (a, b) => a > b ? a : b)
                : 0.0);
          } else {
            progress[def.id] = totalDistanceKm;
          }
          break;
        case 'totalTime':
          progress[def.id] = totalDurationSec;
          break;
        case 'elevation':
          progress[def.id] = totalAscent;
          break;
        default:
          progress[def.id] = 0;
      }
    }

    return progress;
  }

  // ── Private helpers ──────────────────────────────────

  Achievement _evaluate(
    Achievement def,
    List<RideRecording> sorted,
    double totalDistanceKm,
    int totalRides,
    double totalDurationSec,
    double totalAscent,
  ) {
    switch (def.id) {
      // ── Ride-count milestones ──
      case 'first_ride':
        return _cumulativeCheck(def, totalRides.toDouble(), sorted.first.completedAt);

      case 'getting_started':
        return _cumulativeCheck(def, totalRides.toDouble(),
            totalRides >= 5 ? sorted[4].completedAt : null);

      case 'road_warrior':
        return _cumulativeCheck(def, totalRides.toDouble(),
            totalRides >= 25 ? sorted[24].completedAt : null);

      // ── Distance milestones (cumulative) ──
      case 'five_k':
        return _cumulativeDistanceCheck(def, sorted, totalDistanceKm, 5.0);

      case 'century_club':
        return _cumulativeDistanceCheck(def, sorted, totalDistanceKm, 100.0);

      case 'millennium_rider':
        return _cumulativeDistanceCheck(def, sorted, totalDistanceKm, 1000.0);

      // ── Single-ride feats ──
      case 'century_ride':
        for (final ride in sorted) {
          if (ride.actualDistanceKm >= 100.0) {
            return def.copyWith(earnedAt: ride.completedAt);
          }
        }
        return def.copyWith(clearEarnedAt: true);

      case 'early_bird':
        for (final ride in sorted) {
          if (ride.completedAt.hour < 7) {
            return def.copyWith(earnedAt: ride.completedAt);
          }
        }
        return def.copyWith(clearEarnedAt: true);

      case 'night_owl':
        for (final ride in sorted) {
          if (ride.completedAt.hour >= 22 || ride.completedAt.hour < 4) {
            return def.copyWith(earnedAt: ride.completedAt);
          }
        }
        return def.copyWith(clearEarnedAt: true);

      case 'speed_demon':
        for (final ride in sorted) {
          if (ride.avgSpeedKmh >= 30.0) {
            return def.copyWith(earnedAt: ride.completedAt);
          }
        }
        return def.copyWith(clearEarnedAt: true);

      // ── Elevation milestone ──
      case 'mountain_goat':
        return _cumulativeAscentCheck(def, sorted, totalAscent, 1000.0);

      // ── Time milestone ──
      case 'time_traveler':
        return _cumulativeTimeCheck(def, sorted, totalDurationSec, 36000);

      default:
        return def.copyWith(clearEarnedAt: true);
    }
  }

  /// Generic check for a cumulative metric tracked by ride count.
  Achievement _cumulativeCheck(
    Achievement def,
    double currentValue,
    DateTime? earnedDate,
  ) {
    if (currentValue >= def.requiredValue && earnedDate != null) {
      return def.copyWith(earnedAt: earnedDate);
    }
    return def.copyWith(clearEarnedAt: true);
  }

  /// Check a cumulative distance threshold, pinning the earned-at date to
  /// the ride that pushed the total over the line.
  Achievement _cumulativeDistanceCheck(
    Achievement def,
    List<RideRecording> sorted,
    double totalDistanceKm,
    double threshold,
  ) {
    if (totalDistanceKm < threshold) {
      return def.copyWith(clearEarnedAt: true);
    }

    double running = 0;
    for (final ride in sorted) {
      running += ride.actualDistanceKm;
      if (running >= threshold) {
        return def.copyWith(earnedAt: ride.completedAt);
      }
    }
    // Fallback (shouldn't be reached)
    return def.copyWith(earnedAt: sorted.last.completedAt);
  }

  /// Check a cumulative ascent threshold.
  Achievement _cumulativeAscentCheck(
    Achievement def,
    List<RideRecording> sorted,
    double totalAscent,
    double threshold,
  ) {
    if (totalAscent < threshold) {
      return def.copyWith(clearEarnedAt: true);
    }

    double running = 0;
    for (final ride in sorted) {
      running += ride.route.ascentM ?? 0;
      if (running >= threshold) {
        return def.copyWith(earnedAt: ride.completedAt);
      }
    }
    return def.copyWith(earnedAt: sorted.last.completedAt);
  }

  /// Check a cumulative time threshold.
  Achievement _cumulativeTimeCheck(
    Achievement def,
    List<RideRecording> sorted,
    double totalDurationSec,
    double threshold,
  ) {
    if (totalDurationSec < threshold) {
      return def.copyWith(clearEarnedAt: true);
    }

    double running = 0;
    for (final ride in sorted) {
      running += ride.actualDurationSec;
      if (running >= threshold) {
        return def.copyWith(earnedAt: ride.completedAt);
      }
    }
    return def.copyWith(earnedAt: sorted.last.completedAt);
  }

  // ── Firestore persistence ─────────────────────────────

  /// Fetches the current user's earned achievements from Firestore and
  /// merges them with the full definition list so the UI always displays
  /// every achievement (locked or unlocked).
  Future<List<Achievement>> fetchFromFirestore(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('achievements')
          .get();

      final Map<String, DateTime> earnedMap = {};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final timestamp = data['earnedAt'] as Timestamp?;
        if (timestamp != null) {
          earnedMap[doc.id] = timestamp.toDate();
        }
      }

      return definitions.map((def) {
        final earned = earnedMap[def.id];
        return earned != null ? def.copyWith(earnedAt: earned) : def.copyWith(clearEarnedAt: true);
      }).toList();
    } catch (_) {
      // Return definitions-only on error (all locked)
      return definitions.map((d) => d.copyWith(clearEarnedAt: true)).toList();
    }
  }

  /// Persists a newly earned achievement to Firestore.
  Future<void> saveToFirestore(String userId, Achievement achievement) async {
    if (!achievement.isUnlocked) return;
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('achievements')
          .doc(achievement.id)
          .set({
        'id': achievement.id,
        'title': achievement.title,
        'description': achievement.description,
        'icon': achievement.icon,
        'requiredValue': achievement.requiredValue,
        'type': achievement.type,
        'earnedAt': Timestamp.fromDate(achievement.earnedAt!),
      });
    } catch (_) {
      // Silently ignore persistence errors — local calculation still works.
    }
  }

  /// Calculates achievements from rides, saves any newly unlocked ones to
  /// Firestore, and returns the full list.
  Future<List<Achievement>> calculateAndSave(
    String userId,
    List<RideRecording> rides,
  ) async {
    final calculated = calculateAchievements(rides);

    // Persist only newly unlocked achievements
    for (final achievement in calculated) {
      if (achievement.isUnlocked) {
        await saveToFirestore(userId, achievement);
      }
    }

    return calculated;
  }
}
