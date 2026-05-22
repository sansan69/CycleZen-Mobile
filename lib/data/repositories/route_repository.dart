import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cyclezen/domain/models/models.dart';

class RouteRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;

  // ORS API key — same as webapp
  static const _orsApiKey = '5b3ce3597851110001cf62485eca65c05eb84463b163981f99875542';
  static const _googleMapsApiKey = 'AIzaSyDoCRiWM2oL2ka68KFtrUCw-RqIcDXU6zs';

  /// AI route generation via OpenRouteService (round-trip loops)
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
    // ORS cycling profiles do NOT support avoid_features=highways.
    // Strategy: use profile + preference to achieve filtering:
    //   fastest       → cycling-regular, recommended (balanced, efficient)
    //   lessTraffic   → cycling-regular, shortest    (smaller/quieter roads)
    //   scenic        → cycling-road, shortest       (road touring on varied routes)
    //   villageRoads  → cycling-mountain, shortest   (unpaved/trail preference)
    final profile = switch (filter) {
      RouteFilter.fastest || RouteFilter.lessTraffic => 'cycling-regular',
      RouteFilter.scenic => 'cycling-road',
      RouteFilter.villageRoads => 'cycling-mountain',
    };

    final preference = switch (filter) {
      RouteFilter.fastest => 'recommended',
      _ => 'shortest', // lessTraffic, scenic, villageRoads — prefer smaller roads
    };

    final body = <String, dynamic>{
      'coordinates': [
        [start.lng, start.lat]
      ],
      'options': <String, dynamic>{
        'round_trip': {
          'length': lengthM.toInt(),
          'points': 3,
          'seed': Random().nextInt(10000),
        },
      },
      'preference': preference,
      'geometry_simplify': 'true',
      'instructions_format': 'text',
      'language': 'en',
    };

    final response = await http.post(
      Uri.parse('https://api.openrouteservice.org/v2/directions/$profile/geojson'),
      headers: {
        'Authorization': _orsApiKey,
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('ORS API error: ${response.statusCode} ${response.body}');
    }

    final data = jsonDecode(response.body);
    final feature = data['features'][0];
    final summary = feature['properties']['summary'];
    final coords = (feature['geometry']['coordinates'] as List)
        .map((c) => Coordinate(lat: c[1], lng: c[0], elev: c.length > 2 ? c[2]?.toDouble() : null))
        .toList();

    final steps = (feature['properties']['segments']?[0]?['steps'] as List?)
        ?.map((s) => RouteStep(
              distanceM: (s['distance'] as num).toDouble(),
              durationSec: (s['duration'] as num).toDouble(),
              instruction: s['instruction']?.toString() ?? '',
              name: s['name']?.toString() ?? '',
            ))
        .toList();

    return CyclingRoute(
      distanceKm: (summary['distance'] as num).toDouble() / 1000,
      estimatedTimeMin: (summary['duration'] as num).toDouble() / 60,
      coordinates: coords,
      ascentM: summary['ascent']?.toDouble(),
      steps: steps,
    );
  }

  /// Manual route via Google Maps Directions API
  /// Uses driving mode because bicycling mode is not supported in India.
  Future<CyclingRoute> generateManualRoute(
    List<Coordinate> waypoints, {
    RouteFilter filter = RouteFilter.fastest,
  }) async {
    final origin = Uri.encodeQueryComponent('${waypoints.first.lat},${waypoints.first.lng}');
    final dest = Uri.encodeQueryComponent('${waypoints.last.lat},${waypoints.last.lng}');

    var url = 'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=$origin&destination=$dest&mode=driving&key=$_googleMapsApiKey';

    // Apply filter: avoid highways for non-fastest modes
    if (filter != RouteFilter.fastest) {
      url += '&avoid=highways';
    }

    if (waypoints.length > 2) {
      final wp = Uri.encodeQueryComponent(
        waypoints
            .sublist(1, waypoints.length - 1)
            .map((w) => '${w.lat},${w.lng}')
            .join('|'),
      );
      url += '&waypoints=$wp';
    }

    final response = await http.get(Uri.parse(url));
    final data = jsonDecode(response.body);

    if (data['status'] != 'OK') {
      throw Exception('Route not found. Try different waypoints. (${data['status']})');
    }

    final route = data['routes'][0];
    final legs = route['legs'] as List;
    var totalDist = 0.0;
    var totalDur = 0.0;

    for (final leg in legs) {
      totalDist += (leg['distance']['value'] as num).toDouble();
      totalDur += (leg['duration']['value'] as num).toDouble();
    }

    final coords = _decodePolyline(route['overview_polyline']['points']);

    final allSteps = <RouteStep>[];
    for (final leg in legs) {
      for (final step in (leg['steps'] as List)) {
        final instr = (step['html_instructions'] as String).replaceAll(RegExp(r'<[^>]*>'), '');
        allSteps.add(RouteStep(
          distanceM: (step['distance']['value'] as num).toDouble(),
          durationSec: (step['duration']['value'] as num).toDouble(),
          instruction: instr,
          name: '',
        ));
      }
    }

    return CyclingRoute(
      distanceKm: totalDist / 1000,
      estimatedTimeMin: totalDur / 60,
      coordinates: coords,
      steps: allSteps,
    );
  }

  List<Coordinate> _decodePolyline(String encoded) {
    final points = <Coordinate>[];
    var index = 0;
    final len = encoded.length;
    var lat = 0;
    var lng = 0;

    while (index < len) {
      var shift = 0;
      var result = 0;
      int byte;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      final dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20);
      final dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(Coordinate(lat: lat / 1e5, lng: lng / 1e5));
    }
    return points;
  }

  /// Save route to Firestore (same DB as webapp)
  Future<void> saveRoute(CyclingRoute route, {String? routeName}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Not authenticated');

    await _firestore
        .collection('users')
        .doc(uid)
        .collection('rides')
        .add({
      'routeData': {
        'distance': route.distanceKm,
        'estimatedTime': route.estimatedTimeMin,
        'coordinates': route.coordinates.map((c) => {
          'lat': c.lat,
          'lng': c.lng,
          if (c.elev != null) 'elev': c.elev,
        }).toList(),
        if (route.ascentM != null) 'ascent': route.ascentM,
        'steps': route.steps?.map((s) => {
          'distance': s.distanceM,
          'duration': s.durationSec,
          'instruction': s.instruction,
          'name': s.name,
          'way_points': [0, 0],
        }).toList() ?? [],
      },
      'timestamp': FieldValue.serverTimestamp(),
      'routeName': routeName ?? 'Route on ${DateTime.now().toIso8601String().substring(0, 10)}',
    });
  }

  /// Fetch saved routes from Firestore
  Future<List<CyclingRoute>> getSavedRoutes() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return [];

    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('rides')
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      final rd = data['routeData'] as Map<String, dynamic>;
      return CyclingRoute(
        id: doc.id,
        distanceKm: (rd['distance'] as num).toDouble(),
        estimatedTimeMin: (rd['estimatedTime'] as num).toDouble(),
        coordinates: (rd['coordinates'] as List)
            .map((c) => Coordinate(
                  lat: (c['lat'] as num).toDouble(),
                  lng: (c['lng'] as num).toDouble(),
                  elev: c['elev']?.toDouble(),
                ))
            .toList(),
        ascentM: rd['ascent']?.toDouble(),
        routeName: data['routeName']?.toString(),
      );
    }).toList();
  }

  Future<void> deleteRoute(String routeId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _firestore.collection('users').doc(uid).collection('rides').doc(routeId).delete();
  }
}
