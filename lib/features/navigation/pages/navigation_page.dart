import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cyclezen/domain/models/models.dart';
import 'package:cyclezen/features/navigation/services/navigation_service.dart';
import 'package:cyclezen/shared/utils/map_utils.dart';

class NavigationPage extends StatefulWidget {
  final CyclingRoute route;
  const NavigationPage({super.key, required this.route});

  @override
  State<NavigationPage> createState() => _NavigationPageState();
}

class _NavigationPageState extends State<NavigationPage> {
  final NavigationService _navService = NavigationService();
  GoogleMapController? _mapController;
  Coordinate? _currentPosition;
  String _currentInstruction = 'Starting navigation...';
  double _remainingDistanceKm = 0;

  CyclingRoute get _route => widget.route;

  @override
  void initState() {
    super.initState();
    _navService.initialize();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startNavigation();
    });
  }

  void _startNavigation() {
    _navService.startNavigation(
      steps: _route.steps ?? [],
      coordinates: _route.coordinates,
    );
    _startLocationUpdates();
    if (_route.steps != null && _route.steps!.isNotEmpty) {
      setState(() => _currentInstruction = _route.steps!.first.instruction);
    }
    setState(() => _remainingDistanceKm = _route.distanceKm);
  }

  void _startLocationUpdates() {
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen((pos) {
      final coord = Coordinate(lat: pos.latitude, lng: pos.longitude);
      setState(() => _currentPosition = coord);
      _navService.updatePosition(coord);

      // Update remaining distance
      if (_route.coordinates.isNotEmpty) {
        final lastCoord = _route.coordinates.last;
        final dist = Geolocator.distanceBetween(
          coord.lat, coord.lng, lastCoord.lat, lastCoord.lng,
        );
        setState(() => _remainingDistanceKm = dist / 1000);
      }

      // Follow user on map
      _mapController?.animateCamera(CameraUpdate.newLatLng(
        LatLng(pos.latitude, pos.longitude),
      ));
    });
  }

  @override
  void dispose() {
    _navService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Map
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(
                _route.coordinates.first.lat,
                _route.coordinates.first.lng,
              ),
              zoom: 16,
            ),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            onMapCreated: (c) {
              _mapController = c;
              MapUtils.fitBounds(c, _route.coordinates, paddingPx: 80);
            },
            polylines: {
              Polyline(
                polylineId: const PolylineId('nav_route'),
                points: _route.coordinates
                    .map((c) => LatLng(c.lat, c.lng))
                    .toList(),
                color: Colors.green,
                width: 5,
              ),
            },
            markers: MapUtils.buildRouteMarkers(_route, prefix: 'nav_'),
          ),

          // Top info bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _currentInstruction,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _InfoItem(
                          icon: Icons.straighten,
                          label: '${_remainingDistanceKm.toStringAsFixed(1)} km',
                        ),
                        _InfoItem(
                          icon: Icons.timer,
                          label: '${(_remainingDistanceKm / (_currentPosition != null ? 15 : 20) * 60).round()} min', // rough ETA
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Stop button
          Positioned(
            bottom: 32,
            left: 16,
            right: 16,
            child: ElevatedButton.icon(
              onPressed: () {
                _navService.stopNavigation();
                Navigator.pop(context);
              },
              icon: const Icon(Icons.stop),
              label: const Text('End Navigation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}
