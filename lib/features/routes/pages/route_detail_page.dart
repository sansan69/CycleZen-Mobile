import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cyclezen/domain/models/models.dart';
import 'package:cyclezen/data/repositories/route_repository.dart';
import 'package:cyclezen/data/services/gpx_service.dart';
import 'package:cyclezen/features/home/widgets/ride_summary.dart';
import 'package:cyclezen/shared/utils/map_utils.dart';

class RouteDetailPage extends StatefulWidget {
  final String routeId;
  const RouteDetailPage({super.key, required this.routeId});

  @override
  State<RouteDetailPage> createState() => _RouteDetailPageState();
}

class _RouteDetailPageState extends State<RouteDetailPage> {
  final RouteRepository _routeRepo = RouteRepository();
  CyclingRoute? _route;
  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    final routes = await _routeRepo.getSavedRoutes();
    final route = routes.where((r) => r.id == widget.routeId).firstOrNull;
    if (mounted) setState(() => _route = route);
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_route != null) {
      MapUtils.fitBounds(controller, _route!.coordinates, paddingPx: 60);
    }
  }

  Future<void> _exportGpx() async {
    if (_route == null) return;
    try {
      final file = await GpxService.exportToFile(_route!);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('GPX saved: ${file.path}'), backgroundColor: Colors.blue),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('GPX error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _startRide() {
    if (_route != null) context.pushNamed('ride', extra: _route);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_route?.routeName ?? 'Route Details'),
        actions: [
          if (_route != null) ...[
            IconButton(icon: const Icon(Icons.share), tooltip: 'Export GPX', onPressed: _exportGpx),
            IconButton(icon: const Icon(Icons.directions_bike), tooltip: 'Start Ride', onPressed: _startRide),
          ],
        ],
      ),
      body: _route == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    height: 300,
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: LatLng(_route!.coordinates.first.lat, _route!.coordinates.first.lng),
                        zoom: 13,
                      ),
                      onMapCreated: _onMapCreated,
                      polylines: {
                        Polyline(
                          polylineId: const PolylineId('detail'),
                          points: _route!.coordinates.map((c) => LatLng(c.lat, c.lng)).toList(),
                          color: Colors.green, width: 5,
                        ),
                      },
                      markers: MapUtils.buildRouteMarkers(_route!, prefix: 'dtl_'),
                      zoomControlsEnabled: false, mapToolbarEnabled: false,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Stats', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 12),
                        _DetailRow(label: 'Distance', value: '${_route!.distanceKm.toStringAsFixed(1)} km'),
                        _DetailRow(label: 'Est. Time', value: '${_route!.estimatedTimeMin.round()} min'),
                        if (_route!.ascentM != null)
                          _DetailRow(label: 'Ascent', value: '${_route!.ascentM!.round()} m'),
                        _DetailRow(label: 'Points', value: '${_route!.coordinates.length}'),
                        const SizedBox(height: 16),

                        // Ride summary
                        RideSummary(route: _route!),
                        const SizedBox(height: 16),

                        // Turn-by-turn
                        if (_route!.steps != null && _route!.steps!.isNotEmpty) ...[
                          Text('Turn-by-Turn', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 8),
                          ...(_route!.steps!.take(10).map((s) => ListTile(
                                dense: true,
                                leading: const Icon(Icons.turn_right, size: 20),
                                title: Text(s.instruction),
                                subtitle: Text('${s.distanceM.round()} m'),
                              ))),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label, value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey)),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
