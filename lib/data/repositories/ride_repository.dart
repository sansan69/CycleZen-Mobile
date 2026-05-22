import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cyclezen/domain/models/models.dart';

class RideRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;

  Future<void> saveCompletedRide(RideRecording ride) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Not authenticated');

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('rides')
        .add({
      'routeName': ride.route.routeName ?? 'Ride',
      'routeData': {
        'distance': ride.route.distanceKm,
        'estimatedTime': ride.route.estimatedTimeMin,
        'ascentM': ride.route.ascentM ?? 0,
        'coordinates': ride.route.coordinates.map((c) => {
          'lat': c.lat,
          'lng': c.lng,
        }).toList(),
      },
      'actualDistanceCoveredKm': ride.actualDistanceKm,
      'actualDurationSeconds': ride.actualDurationSec,
      'avgSpeedKmh': ride.avgSpeedKmh,
      'maxSpeedKmh': ride.maxSpeedKmh,
      'completedAt': Timestamp.fromDate(ride.completedAt),
      'recordedPath': ride.recordedPath.map((c) => {
        'lat': c.lat,
        'lng': c.lng,
      }).toList(),
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<List<RideRecording>> getCompletedRides() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('rides')
        .where('completedAt', isNull: false)
        .orderBy('completedAt', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return RideRecording(
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
    }).toList();
  }

  /// Delete all completed rides for the current user
  Future<int> deleteAllRides() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return 0;

    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('rides')
        .get();

    final batch = _firestore.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    return snapshot.docs.length;
  }
}
