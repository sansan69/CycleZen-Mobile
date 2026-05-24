import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cyclezen/domain/models/models.dart';

/// Shared Google Maps utilities used across all map pages.
class MapUtils {
  /// Dark map style — applied when device is in dark mode.
  /// Reduces glare for night cycling.
  static const String darkMapStyle = '''
[
  {
    "elementType": "geometry",
    "stylers": [{"color": "#242f3e"}]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#746855"}]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [{"color": "#242f3e"}]
  },
  {
    "featureType": "administrative.locality",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#d59563"}]
  },
  {
    "featureType": "poi",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#d59563"}]
  },
  {
    "featureType": "poi.park",
    "elementType": "geometry",
    "stylers": [{"color": "#263c3f"}]
  },
  {
    "featureType": "poi.park",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#6b9a76"}]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [{"color": "#38414e"}]
  },
  {
    "featureType": "road",
    "elementType": "geometry.stroke",
    "stylers": [{"color": "#212a37"}]
  },
  {
    "featureType": "road",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#9ca5b3"}]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [{"color": "#746855"}]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry.stroke",
    "stylers": [{"color": "#1f2835"}]
  },
  {
    "featureType": "road.highway",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#f3d19c"}]
  },
  {
    "featureType": "transit",
    "elementType": "geometry",
    "stylers": [{"color": "#2f3948"}]
  },
  {
    "featureType": "transit.station",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#d59563"}]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [{"color": "#17263c"}]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#515c6d"}]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.stroke",
    "stylers": [{"color": "#17263c"}]
  }
]
''';

  /// Build a set of polylines for a list of routes.
  /// Primary route (index 0) is green and thick; alternates are blue and thin.
  static Set<Polyline> buildRoutePolylines(List<CyclingRoute> routes) {
    final polylines = <Polyline>{};
    for (var i = 0; i < routes.length; i++) {
      polylines.add(Polyline(
        polylineId: PolylineId('route_$i'),
        points: routes[i].coordinates
            .map((c) => LatLng(c.lat, c.lng))
            .toList(),
        color: i == 0 ? Colors.green : Colors.blue.withValues(alpha: 0.5),
        width: i == 0 ? 5 : 3,
      ));
    }
    return polylines;
  }

  /// Build markers for a route: start (green), end (red), and waypoints.
  static Set<Marker> buildRouteMarkers(CyclingRoute route, {String prefix = ''}) {
    final markers = <Marker>{};
    final coords = route.coordinates;
    if (coords.isEmpty) return markers;

    // Start marker (green circle)
    markers.add(Marker(
      markerId: MarkerId('${prefix}start'),
      position: LatLng(coords.first.lat, coords.first.lng),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: InfoWindow(
        title: 'Start',
        snippet: '${route.distanceKm.toStringAsFixed(1)} km route',
      ),
    ));

    // End marker (red circle) — only if different from start
    if (coords.length > 1) {
      markers.add(Marker(
        markerId: MarkerId('${prefix}end'),
        position: LatLng(coords.last.lat, coords.last.lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'End'),
      ));
    }

    return markers;
  }

  /// Build numbered markers for manual waypoints.
  static Set<Marker> buildWaypointMarkers(List<Coordinate> waypoints) {
    final markers = <Marker>{};
    for (var i = 0; i < waypoints.length; i++) {
      markers.add(Marker(
        markerId: MarkerId('wp_$i'),
        position: LatLng(waypoints[i].lat, waypoints[i].lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          i == 0
              ? BitmapDescriptor.hueGreen
              : i == waypoints.length - 1
                  ? BitmapDescriptor.hueRed
                  : BitmapDescriptor.hueOrange,
        ),
        infoWindow: InfoWindow(title: 'Waypoint ${i + 1}'),
      ));
    }
    return markers;
  }

  /// Build a single marker for user-selected location.
  static Marker buildLocationMarker(Coordinate coord) {
    return Marker(
      markerId: const MarkerId('start'),
      position: LatLng(coord.lat, coord.lng),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
      infoWindow: const InfoWindow(title: 'Starting Point'),
    );
  }

  /// Compute bounds that encompass all coordinates, with padding.
  static LatLngBounds computeBounds(List<Coordinate> coords, {double padding = 0.02}) {
    if (coords.isEmpty) {
      // Kerala center as safe fallback
      const keralaCenter = LatLng(10.8505, 76.2711);
      return LatLngBounds(
        southwest: keralaCenter,
        northeast: keralaCenter,
      );
    }
    double minLat = coords.first.lat;
    double maxLat = coords.first.lat;
    double minLng = coords.first.lng;
    double maxLng = coords.first.lng;
    for (final c in coords) {
      if (c.lat < minLat) minLat = c.lat;
      if (c.lat > maxLat) maxLat = c.lat;
      if (c.lng < minLng) minLng = c.lng;
      if (c.lng > maxLng) maxLng = c.lng;
    }
    return LatLngBounds(
      southwest: LatLng(minLat - padding, minLng - padding),
      northeast: LatLng(maxLat + padding, maxLng + padding),
    );
  }

  /// Animate camera to fit coordinates within the map view.
  /// [paddingPx] accounts for UI overlays (cards, buttons).
  static Future<void> fitBounds(
    GoogleMapController controller,
    List<Coordinate> coords, {
    double paddingPx = 60,
  }) async {
    if (coords.isEmpty) return;
    final bounds = computeBounds(coords);
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, paddingPx),
    );
  }

  /// Build polylines for waypoint preview (dashed orange line).
  static Set<Polyline> buildWaypointPreviewLine(List<Coordinate> waypoints) {
    if (waypoints.length < 2) return {};
    return {
      Polyline(
        polylineId: const PolylineId('manual_preview'),
        points: waypoints.map((w) => LatLng(w.lat, w.lng)).toList(),
        color: Colors.orange,
        width: 3,
        patterns: [PatternItem.dash(10), PatternItem.gap(5)],
      ),
    };
  }

  /// Build a polyline for a recorded ride path (distinct from planned route).
  static Polyline buildRecordedPathPolyline(List<Coordinate> path) {
    return Polyline(
      polylineId: const PolylineId('recorded'),
      points: path.map((c) => LatLng(c.lat, c.lng)).toList(),
      color: Colors.red,
      width: 4,
    );
  }

  /// Combined markers + polylines for use in map widgets.
  static ({
    Set<Marker> markers,
    Set<Polyline> polylines,
  }) buildRouteOverlay(CyclingRoute route, {String prefix = ''}) {
    return (
      markers: buildRouteMarkers(route, prefix: prefix),
      polylines: buildRoutePolylines([route]),
    );
  }
}
