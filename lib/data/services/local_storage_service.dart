import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:cyclezen/domain/models/models.dart';

/// Local JSON file persistence for routes and rides.
///
/// Works for ALL users — anonymous and signed-in.
/// When signed in, Firestore sync runs alongside local storage.
class LocalStorageService {
  static const _routesFile = 'cyclezen_routes.json';
  static const _ridesFile = 'cyclezen_rides.json';

  Future<Directory> get _dir async {
    final dir = await getApplicationDocumentsDirectory();
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  // ── Routes ──────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> _readRoutes() async {
    final file = File('${(await _dir).path}/$_routesFile');
    if (!await file.exists()) return [];
    final content = await file.readAsString();
    if (content.isEmpty) return [];
    try {
      return (jsonDecode(content) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      // Corrupted file — start fresh
      return [];
    }
  }

  Future<void> _writeRoutes(List<Map<String, dynamic>> routes) async {
    final file = File('${(await _dir).path}/$_routesFile');
    await file.writeAsString(jsonEncode(routes));
  }

  /// Save a route locally. Returns the local ID.
  Future<String> saveRoute(CyclingRoute route, {String? routeName}) async {
    final routes = await _readRoutes();
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final entry = <String, dynamic>{
      'id': id,
      'routeName': routeName ?? 'Route ${routes.length + 1}',
      'distanceKm': route.distanceKm,
      'estimatedTimeMin': route.estimatedTimeMin,
      'ascentM': route.ascentM,
      'coordinates': route.coordinates.map((c) => {
        'lat': c.lat,
        'lng': c.lng,
        if (c.elev != null) 'elev': c.elev,
      }).toList(),
      'steps': route.steps?.map((s) => {
        'distanceM': s.distanceM,
        'durationSec': s.durationSec,
        'instruction': s.instruction,
        'name': s.name,
      }).toList() ?? [],
      'savedAt': DateTime.now().toIso8601String(),
      'synced': false, // not yet synced to Firestore
    };
    routes.insert(0, entry);
    await _writeRoutes(routes);
    return id;
  }

  /// Load all locally saved routes.
  Future<List<CyclingRoute>> getSavedRoutes() async {
    final routes = await _readRoutes();
    return routes.map((r) {
      return CyclingRoute(
        id: r['id']?.toString(),
        routeName: r['routeName']?.toString(),
        distanceKm: (r['distanceKm'] as num).toDouble(),
        estimatedTimeMin: (r['estimatedTimeMin'] as num).toDouble(),
        ascentM: (r['ascentM'] as num?)?.toDouble(),
        coordinates: (r['coordinates'] as List).map((c) => Coordinate(
          lat: (c['lat'] as num).toDouble(),
          lng: (c['lng'] as num).toDouble(),
          elev: c['elev']?.toDouble(),
        )).toList(),
        steps: (r['steps'] as List?)?.map((s) => RouteStep(
          distanceM: (s['distanceM'] as num).toDouble(),
          durationSec: (s['durationSec'] as num).toDouble(),
          instruction: s['instruction']?.toString() ?? '',
          name: s['name']?.toString() ?? '',
        )).toList(),
      );
    }).toList();
  }

  Future<void> deleteRoute(String routeId) async {
    final routes = await _readRoutes();
    routes.removeWhere((r) => r['id'] == routeId);
    await _writeRoutes(routes);
  }

  /// Mark a route as synced to Firestore.
  Future<void> markRouteSynced(String localId, String firestoreId) async {
    final routes = await _readRoutes();
    for (final r in routes) {
      if (r['id'] == localId) {
        r['synced'] = true;
        r['firestoreId'] = firestoreId;
        break;
      }
    }
    await _writeRoutes(routes);
  }

  /// Get all unsynced routes (for uploading on sign-in).
  Future<List<Map<String, dynamic>>> getUnsyncedRoutes() async {
    final routes = await _readRoutes();
    return routes.where((r) => r['synced'] != true).toList();
  }

  // ── Completed Rides ─────────────────────────────────────

  Future<List<Map<String, dynamic>>> _readRides() async {
    final file = File('${(await _dir).path}/$_ridesFile');
    if (!await file.exists()) return [];
    final content = await file.readAsString();
    if (content.isEmpty) return [];
    try {
      return (jsonDecode(content) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      // Corrupted file — start fresh
      return [];
    }
  }

  Future<void> _writeRides(List<Map<String, dynamic>> rides) async {
    final file = File('${(await _dir).path}/$_ridesFile');
    await file.writeAsString(jsonEncode(rides));
  }

  /// Save a completed ride locally.
  Future<String> saveCompletedRide(RideRecording ride) async {
    final rides = await _readRides();
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final entry = <String, dynamic>{
      'id': id,
      'routeName': ride.route.routeName ?? 'Ride',
      'routeDistanceKm': ride.route.distanceKm,
      'routeAscentM': ride.route.ascentM ?? 0,
      'actualDistanceKm': ride.actualDistanceKm,
      'actualDurationSec': ride.actualDurationSec,
      'avgSpeedKmh': ride.avgSpeedKmh,
      'maxSpeedKmh': ride.maxSpeedKmh,
      'completedAt': ride.completedAt.toIso8601String(),
      'recordedPath': ride.recordedPath.map((c) => {
        'lat': c.lat,
        'lng': c.lng,
      }).toList(),
      'synced': false,
    };
    rides.insert(0, entry);
    await _writeRides(rides);
    return id;
  }

  /// Load all locally saved completed rides.
  Future<List<RideRecording>> getCompletedRides() async {
    final rides = await _readRides();
    return rides.map((r) {
      return RideRecording(
        id: r['id']?.toString(),
        route: CyclingRoute(
          distanceKm: (r['routeDistanceKm'] as num).toDouble(),
          estimatedTimeMin: 0,
          ascentM: (r['routeAscentM'] as num?)?.toDouble(),
          coordinates: [],
          routeName: r['routeName']?.toString(),
        ),
        actualDistanceKm: (r['actualDistanceKm'] as num).toDouble(),
        actualDurationSec: (r['actualDurationSec'] as num).toDouble(),
        avgSpeedKmh: (r['avgSpeedKmh'] as num?)?.toDouble() ?? 0,
        maxSpeedKmh: (r['maxSpeedKmh'] as num?)?.toDouble() ?? 0,
        recordedPath: (r['recordedPath'] as List?)?.map((c) => Coordinate(
          lat: (c['lat'] as num).toDouble(),
          lng: (c['lng'] as num).toDouble(),
        )).toList() ?? [],
        completedAt: _parseDateSafe(r['completedAt']),
      );
    }).toList();
  }

  Future<int> deleteAllRides() async {
    final rides = await _readRides();
    final count = rides.length;
    await _writeRides([]);
    return count;
  }

  /// Get all unsynced rides.
  Future<List<Map<String, dynamic>>> getUnsyncedRides() async {
    final rides = await _readRides();
    return rides.where((r) => r['synced'] != true).toList();
  }

  Future<void> markRideSynced(String localId, String firestoreId) async {
    final rides = await _readRides();
    for (final r in rides) {
      if (r['id'] == localId) {
        r['synced'] = true;
        r['firestoreId'] = firestoreId;
        break;
      }
    }
    await _writeRides(rides);
  }

  /// Sync all unsynced data to Firestore. Called on sign-in.
  Future<Map<String, int>> syncAll({
    required Future<String?> Function(Map<String, dynamic> route) syncRoute,
    required Future<String?> Function(Map<String, dynamic> ride) syncRide,
  }) async {
    var routeCount = 0;
    var rideCount = 0;

    final unsyncedRoutes = await getUnsyncedRoutes();
    for (final r in unsyncedRoutes) {
      final firestoreId = await syncRoute(r);
      final rid = r['id'];
      if (firestoreId != null && rid != null) {
        await markRouteSynced(rid.toString(), firestoreId);
        routeCount++;
      }
    }

    final unsyncedRides = await getUnsyncedRides();
    for (final r in unsyncedRides) {
      final firestoreId = await syncRide(r);
      final rid = r['id'];
      if (firestoreId != null && rid != null) {
        await markRideSynced(rid.toString(), firestoreId);
        rideCount++;
      }
    }

    return {'routes': routeCount, 'rides': rideCount};
  }

  /// Safely parse an ISO date string, returning epoch on failure.
  static DateTime _parseDateSafe(dynamic value) {
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {}
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
