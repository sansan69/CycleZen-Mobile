import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cyclezen/domain/models/models.dart';
import 'package:cyclezen/data/services/local_storage_service.dart';

class RideRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  final LocalStorageService _local = LocalStorageService();

  bool get _isSignedIn => _auth.currentUser != null;

  /// Save completed ride: always local first, Firestore if signed in.
  Future<void> saveCompletedRide(RideRecording ride) async {
    // 1. Always save locally
    await _local.saveCompletedRide(ride);

    // 2. Try Firestore if signed in
    if (_isSignedIn) {
      try {
        await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .collection('rides')
            .add({
          'routeName': ride.route.routeName ?? 'Ride',
          'routeData': {
            'distance': ride.route.distanceKm,
            'estimatedTime': ride.route.estimatedTimeMin,
            'ascentM': ride.route.ascentM ?? 0,
            'coordinates': ride.route.coordinates.map((c) => {
              'lat': c.lat, 'lng': c.lng,
            }).toList(),
          },
          'actualDistanceCoveredKm': ride.actualDistanceKm,
          'actualDurationSeconds': ride.actualDurationSec,
          'avgSpeedKmh': ride.avgSpeedKmh,
          'maxSpeedKmh': ride.maxSpeedKmh,
          'completedAt': Timestamp.fromDate(ride.completedAt),
          'recordedPath': ride.recordedPath.map((c) => {
            'lat': c.lat, 'lng': c.lng,
          }).toList(),
          'timestamp': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Firestore save failed: $e'); // data is safe locally
      }
    }
  }

  /// Get completed rides: merge local + Firestore.
  Future<List<RideRecording>> getCompletedRides() async {
    final localRides = await _local.getCompletedRides();
    final rides = <String, RideRecording>{};

    // Local first
    for (final r in localRides) {
      if (r.id != null) rides[r.id!] = r;
    }

    // Firestore overlay (if signed in)
    if (_isSignedIn) {
      try {
        final snapshot = await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .collection('rides')
            .where('completedAt', isNull: false)
            .orderBy('completedAt', descending: true)
            .get();

        for (final doc in snapshot.docs) {
          final data = doc.data();
          rides[doc.id] = RideRecording(
            id: doc.id,
            route: CyclingRoute(
              distanceKm: (data['routeData']['distance'] as num).toDouble(),
              estimatedTimeMin: (data['routeData']['estimatedTime'] as num).toDouble(),
              ascentM: (data['routeData']['ascentM'] as num?)?.toDouble(),
              coordinates: [],
              routeName: data['routeName']?.toString(),
            ),
            actualDistanceKm: (data['actualDistanceCoveredKm'] as num?)?.toDouble() ?? 0,
            actualDurationSec: (data['actualDurationSeconds'] as num?)?.toDouble() ?? 0,
            avgSpeedKmh: (data['avgSpeedKmh'] as num?)?.toDouble() ?? 0,
            maxSpeedKmh: (data['maxSpeedKmh'] as num?)?.toDouble() ?? 0,
            recordedPath: [],
            completedAt: (data['completedAt'] as Timestamp).toDate(),
          );
        }
      } catch (e) {
        debugPrint('Firestore op failed: $e');
      }
    }

    return rides.values.toList();
  }

  /// Delete all completed rides locally + Firestore.
  Future<int> deleteAllRides() async {
    final localCount = await _local.deleteAllRides();
    if (_isSignedIn) {
      try {
        final snapshot = await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .collection('rides')
            .get();
        final batch = _firestore.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        return snapshot.docs.length + localCount;
      } catch (e) {
        debugPrint('Firestore op failed: $e');
      }
    }
    return localCount;
  }
}
