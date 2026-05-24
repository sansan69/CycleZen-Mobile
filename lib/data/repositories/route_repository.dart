import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cyclezen/domain/models/models.dart';
import 'package:cyclezen/data/services/local_storage_service.dart';

class RouteRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  final LocalStorageService _local = LocalStorageService();

  // ORS API key
  static const _orsApiKey = '5b3ce3597851110001cf62485eca65c05eb84463b163981f99875542';
  static const _googleMapsApiKey = 'AIzaSyDoCRiWM2oL2ka68KFtrUCw-RqIcDXU6zs';

  bool get _isSignedIn => _auth.currentUser != null;

  // ── Route generation (unchanged) ──────────────────────────

  Future<List<CyclingRoute>> generateAIRoutes({
    required Coordinate location,
    required double radiusKm,
    int count = 3,
    RouteFilter filter = RouteFilter.fastest,
  }) async {
    final routes = <CyclingRoute>[];
    for (var i = 0; i < count; i++) {
      try {
        final route = await _fetchORSRoute(location, radiusKm * 1000, filter: filter);
        routes.add(route);
      } catch (e) {
        if (routes.isEmpty && i == count - 1) rethrow;
      }
    }
    return routes;
  }

  Future<CyclingRoute> _fetchORSRoute(Coordinate start, double lengthM, {RouteFilter filter = RouteFilter.fastest}) async {
    final profile = switch (filter) {
      RouteFilter.fastest || RouteFilter.lessTraffic => 'cycling-regular',
      RouteFilter.scenic => 'cycling-road',
      RouteFilter.villageRoads => 'cycling-mountain',
    };
    final preference = switch (filter) {
      RouteFilter.fastest => 'recommended',
      _ => 'shortest',
    };
    final body = <String, dynamic>{
      'coordinates': [[start.lng, start.lat]],
      'options': <String, dynamic>{
        'round_trip': {'length': lengthM.toInt(), 'points': 3, 'seed': Random().nextInt(10000)},
      },
      'preference': preference,
      'geometry_simplify': 'true',
      'instructions_format': 'text',
      'language': 'en',
    };
    final response = await http.post(
      Uri.parse('https://api.openrouteservice.org/v2/directions/$profile/geojson'),
      headers: {'Authorization': _orsApiKey, 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (response.statusCode != 200) throw Exception('ORS API error: ${response.statusCode}');
    final data = jsonDecode(response.body);
    final feature = data['features'][0];
    final summary = feature['properties']['summary'];
    final coords = (feature['geometry']['coordinates'] as List)
        .map((c) => Coordinate(lat: c[1], lng: c[0], elev: c.length > 2 ? c[2]?.toDouble() : null)).toList();
    final steps = (feature['properties']['segments']?[0]?['steps'] as List?)
        ?.map((s) => RouteStep(
              distanceM: (s['distance'] as num).toDouble(),
              durationSec: (s['duration'] as num).toDouble(),
              instruction: s['instruction']?.toString() ?? '',
              name: s['name']?.toString() ?? '',
            )).toList();
    return CyclingRoute(
      distanceKm: (summary['distance'] as num).toDouble() / 1000,
      estimatedTimeMin: (summary['duration'] as num).toDouble() / 60,
      coordinates: coords, ascentM: summary['ascent']?.toDouble(), steps: steps,
    );
  }

  Future<CyclingRoute> generateManualRoute(List<Coordinate> waypoints, {RouteFilter filter = RouteFilter.fastest}) async {
    final origin = Uri.encodeQueryComponent('${waypoints.first.lat},${waypoints.first.lng}');
    final dest = Uri.encodeQueryComponent('${waypoints.last.lat},${waypoints.last.lng}');
    var url = 'https://maps.googleapis.com/maps/api/directions/json?origin=$origin&destination=$dest&mode=bicycling&key=$_googleMapsApiKey';
    if (filter != RouteFilter.fastest) url += '&avoid=highways';
    if (waypoints.length > 2) {
      final wp = Uri.encodeQueryComponent(waypoints.sublist(1, waypoints.length - 1).map((w) => '${w.lat},${w.lng}').join('|'));
      url += '&waypoints=$wp';
    }
    final response = await http.get(Uri.parse(url));
    final data = jsonDecode(response.body);
    if (data['status'] != 'OK') throw Exception('Route not found. (${data['status']})');
    final route = data['routes'][0];
    final legs = route['legs'] as List;
    var totalDist = 0.0, totalDur = 0.0;
    for (final leg in legs) {
      totalDist += (leg['distance']['value'] as num).toDouble();
      totalDur += (leg['duration']['value'] as num).toDouble();
    }
    final coords = _decodePolyline(route['overview_polyline']['points']);
    final allSteps = <RouteStep>[];
    for (final leg in legs) {
      for (final step in (leg['steps'] as List)) {
        allSteps.add(RouteStep(
          distanceM: (step['distance']['value'] as num).toDouble(),
          durationSec: (step['duration']['value'] as num).toDouble(),
          instruction: (step['html_instructions'] as String).replaceAll(RegExp(r'<[^>]*>'), ''),
          name: '',
        ));
      }
    }
    return CyclingRoute(distanceKm: totalDist / 1000, estimatedTimeMin: totalDur / 60, coordinates: coords, steps: allSteps);
  }

  List<Coordinate> _decodePolyline(String encoded) {
    final points = <Coordinate>[];
    var index = 0, lat = 0, lng = 0;
    while (index < encoded.length) {
      var shift = 0, result = 0; int byte;
      do { byte = encoded.codeUnitAt(index++) - 63; result |= (byte & 0x1f) << shift; shift += 5; } while (byte >= 0x20);
      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      shift = 0; result = 0;
      do { byte = encoded.codeUnitAt(index++) - 63; result |= (byte & 0x1f) << shift; shift += 5; } while (byte >= 0x20);
      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      points.add(Coordinate(lat: lat / 1e5, lng: lng / 1e5));
    }
    return points;
  }

  // ── Save & Load (local-first, Firestore sync) ─────────────

  /// Save route: always local first, then Firestore if signed in.
  Future<void> saveRoute(CyclingRoute route, {String? routeName}) async {
    // 1. Save locally (always works)
    final localId = await _local.saveRoute(route, routeName: routeName);

    // 2. Try Firestore if signed in
    if (_isSignedIn) {
      try {
        final docRef = await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .collection('rides')
            .add({
          'routeData': {
            'distance': route.distanceKm,
            'estimatedTime': route.estimatedTimeMin,
            'coordinates': route.coordinates.map((c) => {
              'lat': c.lat, 'lng': c.lng,
              if (c.elev != null) 'elev': c.elev,
            }).toList(),
            if (route.ascentM != null) 'ascent': route.ascentM,
            'steps': route.steps?.map((s) => {
              'distance': s.distanceM, 'duration': s.durationSec,
              'instruction': s.instruction, 'name': s.name, 'way_points': [0, 0],
            }).toList() ?? [],
          },
          'timestamp': FieldValue.serverTimestamp(),
          'routeName': routeName ?? 'Route on ${DateTime.now().toIso8601String().substring(0, 10)}',
        });
        await _local.markRouteSynced(localId, docRef.id);
      } catch (e) {
        debugPrint('Firestore save failed (route sync): $e'); // data is still safe locally
      }
    }
  }

  /// Get saved routes: merge local + Firestore, deduplicate by ID.
  Future<List<CyclingRoute>> getSavedRoutes() async {
    final localRoutes = await _local.getSavedRoutes();
    final routes = <String, CyclingRoute>{};

    // Local first
    for (final r in localRoutes) {
      if (r.id != null) routes[r.id!] = r;
    }

    // Firestore overlay (if signed in)
    if (_isSignedIn) {
      try {
        final snapshot = await _firestore
            .collection('users')
            .doc(_auth.currentUser!.uid)
            .collection('rides')
            .orderBy('timestamp', descending: true)
            .get();

        for (final doc in snapshot.docs) {
          final data = doc.data();
          final rd = data['routeData'] as Map<String, dynamic>;
          routes[doc.id] = CyclingRoute(
            id: doc.id,
            distanceKm: (rd['distance'] as num).toDouble(),
            estimatedTimeMin: (rd['estimatedTime'] as num).toDouble(),
            coordinates: (rd['coordinates'] as List).map((c) => Coordinate(
              lat: (c['lat'] as num).toDouble(),
              lng: (c['lng'] as num).toDouble(),
              elev: c['elev']?.toDouble(),
            )).toList(),
            ascentM: rd['ascent']?.toDouble(),
            routeName: data['routeName']?.toString(),
          );
        }
      } catch (e) {
        debugPrint('Firestore op failed: $e');
      }
    }

    return routes.values.toList();
  }

  Future<void> deleteRoute(String routeId) async {
    await _local.deleteRoute(routeId);
    if (_isSignedIn) {
      try {
        await _firestore.collection('users').doc(_auth.currentUser!.uid).collection('rides').doc(routeId).delete();
      } catch (e) {
        debugPrint('Firestore op failed: $e');
      }
    }
  }

  /// Sync all local data to Firestore. Called after sign-in.
  Future<Map<String, int>> syncLocalToCloud() async {
    if (!_isSignedIn) return {'routes': 0, 'rides': 0};

    return _local.syncAll(
      syncRoute: (routeData) async {
        try {
          final docRef = await _firestore
              .collection('users')
              .doc(_auth.currentUser!.uid)
              .collection('rides')
              .add(routeData['routeData'] ?? routeData);
          return docRef.id;
        } catch (_) {
          return null;
        }
      },
      syncRide: (rideData) async {
        try {
          final docRef = await _firestore
              .collection('users')
              .doc(_auth.currentUser!.uid)
              .collection('rides')
              .add(rideData);
          return docRef.id;
        } catch (_) {
          return null;
        }
      },
    );
  }
}
