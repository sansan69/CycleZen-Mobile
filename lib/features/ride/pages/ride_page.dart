import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cyclezen/domain/models/models.dart';
import 'package:cyclezen/features/ride/services/ride_tracking_service.dart';
import 'package:cyclezen/data/repositories/ride_repository.dart';
import 'package:cyclezen/shared/utils/map_utils.dart';

class RidePage extends StatefulWidget {
  final CyclingRoute route;
  const RidePage({super.key, required this.route});

  @override
  State<RidePage> createState() => _RidePageState();
}

class _RidePageState extends State<RidePage> {
  final RideTrackingService _trackingService = RideTrackingService();
  final RideRepository _rideRepo = RideRepository();
  RideState _rideState = const RideState(
    status: RideStatus.idle,
    distanceKm: 0,
    elapsed: Duration.zero,
    avgSpeedKmh: 0,
    maxSpeedKmh: 0,
    currentSpeedKmh: 0,
  );
  StreamSubscription<RideState>? _stateSub;
  StreamSubscription<List<Coordinate>>? _pathSub;
  GoogleMapController? _mapController;
  final List<LatLng> _recordedPath = [];
  bool _cameraInitialized = false;

  CyclingRoute get _route => widget.route;

  @override
  void initState() {
    super.initState();
    _stateSub = _trackingService.stateStream.listen((state) {
      if (mounted) setState(() => _rideState = state);
    });
    // Listen for recorded path updates
    _pathSub = _trackingService.pathStream.listen((path) {
      setState(() {
        _recordedPath.clear();
        _recordedPath.addAll(path.map((c) => LatLng(c.lat, c.lng)));
      });
      // Follow rider on map during active ride
      if (_rideState.status == RideStatus.active && _recordedPath.isNotEmpty && _mapController != null) {
        _mapController!.animateCamera(CameraUpdate.newLatLng(
          _recordedPath.last,
        ));
      }
    });
  }

  // ── Camera init ───────────────────────────────────────────

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    // Fit camera to show the planned route
    MapUtils.fitBounds(controller, _route.coordinates, paddingPx: 60);
  }

  // ── Ride controls ─────────────────────────────────────────

  Future<void> _startRide() async {
    final hasPermission = await _trackingService.requestPermissions();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission required')),
        );
      }
      return;
    }
    _trackingService.startRide();
  }

  void _togglePause() {
    if (_rideState.status == RideStatus.active) {
      _trackingService.pauseRide();
    } else if (_rideState.status == RideStatus.paused) {
      _trackingService.resumeRide();
    }
  }

  Future<void> _stopRide() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Ride?'),
        content: Text(
          'Distance: ${_rideState.distanceKm.toStringAsFixed(2)} km\n'
          'Time: ${_formatDuration(_rideState.elapsed)}',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('End Ride')),
        ],
      ),
    );

    if (confirmed != true) return;

    final recording = _trackingService.stopRide(plannedRoute: _route);
    try {
      await _rideRepo.saveCompletedRide(recording);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ride saved!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save error: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) Navigator.pop(context);
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m ${s}s';
    return '${m}m ${s}s';
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _pathSub?.cancel();
    _trackingService.dispose();
    super.dispose();
  }

  // ── UI ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Build polylines: planned route (blue dashed) + recorded path (red solid)
    final polylines = <Polyline>{
      // Planned route
      Polyline(
        polylineId: const PolylineId('planned'),
        points: _route.coordinates.map((c) => LatLng(c.lat, c.lng)).toList(),
        color: Colors.blue.withValues(alpha: 0.4),
        width: 4,
        patterns: [PatternItem.dash(8), PatternItem.gap(4)],
      ),
    };

    // Recorded path during ride
    if (_recordedPath.length > 1) {
      polylines.add(Polyline(
        polylineId: const PolylineId('recorded'),
        points: List.from(_recordedPath),
        color: Colors.red,
        width: 5,
      ));
    }

    // Markers
    final markers = MapUtils.buildRouteMarkers(_route, prefix: 'ride_');

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(
                _route.coordinates.first.lat,
                _route.coordinates.first.lng,
              ),
              zoom: 15,
            ),
            onMapCreated: _onMapCreated,
            myLocationEnabled: true,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            polylines: polylines,
            markers: markers,
          ),

          // Stats overlay
          if (_rideState.status != RideStatus.idle)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_rideState.currentSpeedKmh.toStringAsFixed(1)}',
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                      const Text('km/h', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _RideStat(label: 'Distance', value: '${_rideState.distanceKm.toStringAsFixed(2)} km'),
                          _RideStat(label: 'Time', value: _formatDuration(_rideState.elapsed)),
                          _RideStat(label: 'Avg', value: '${_rideState.avgSpeedKmh.toStringAsFixed(1)} km/h'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Controls
          Positioned(
            bottom: 32,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (_rideState.status == RideStatus.idle)
                  _RideButton(
                    icon: Icons.play_arrow,
                    label: 'Start',
                    color: Colors.green,
                    onTap: _startRide,
                  ),
                if (_rideState.status == RideStatus.active || _rideState.status == RideStatus.paused)
                  _RideButton(
                    icon: _rideState.status == RideStatus.paused ? Icons.play_arrow : Icons.pause,
                    label: _rideState.status == RideStatus.paused ? 'Resume' : 'Pause',
                    color: Colors.orange,
                    onTap: _togglePause,
                  ),
                if (_rideState.status != RideStatus.idle)
                  _RideButton(
                    icon: Icons.stop,
                    label: 'End',
                    color: Colors.red,
                    onTap: _stopRide,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RideStat extends StatelessWidget {
  final String label;
  final String value;
  const _RideStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
      ],
    );
  }
}

class _RideButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _RideButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      ),
    );
  }
}
