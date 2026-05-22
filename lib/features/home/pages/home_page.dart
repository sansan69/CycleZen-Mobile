import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cyclezen/domain/models/models.dart';
import 'package:cyclezen/data/repositories/route_repository.dart';
import 'package:cyclezen/data/services/gpx_service.dart';
import 'package:cyclezen/data/services/weather_service.dart';
import 'package:cyclezen/features/home/widgets/route_mode_toggle.dart';
import 'package:cyclezen/features/home/widgets/route_card.dart';
import 'package:cyclezen/features/home/widgets/ai_route_panel.dart';
import 'package:cyclezen/features/home/widgets/manual_route_panel.dart';
import 'package:cyclezen/features/home/widgets/weather_widget.dart';
import 'package:cyclezen/features/auth/bloc/auth_bloc.dart';
import 'package:cyclezen/shared/utils/map_utils.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final RouteRepository _routeRepo = RouteRepository();
  final WeatherService _weatherService = WeatherService();
  RouteMode _mode = RouteMode.ai;
  RouteFilter _filter = RouteFilter.fastest;
  Coordinate? _selectedLocation;
  double _radiusKm = 10;
  List<CyclingRoute>? _routes;
  bool _loading = false;
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  final List<Coordinate> _manualWaypoints = [];
  WeatherData? _weather;
  bool _weatherLoading = false;
  int? _selectedRouteIndex;

  @override
  void initState() {
    super.initState();
    // Don't block render on GPS — show map immediately, get location in background
    WidgetsBinding.instance.addPostFrameCallback((_) => _getCurrentLocation());
  }

  // ── Location ──────────────────────────────────────────────

  Future<void> _getCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied')),
          );
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permanently denied. Enable in Settings.'), duration: Duration(seconds: 4)),
        );
        return;
      }

      // Try cached position first — instant if available
      Position? pos = await Geolocator.getLastKnownPosition();
      pos ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
      );

      if (!mounted) return;
      setState(() {
        _selectedLocation = Coordinate(lat: pos!.latitude, lng: pos!.longitude);
      });
      _rebuildOverlays();
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(pos!.latitude, pos!.longitude), 15));
      _fetchWeather();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location error: $e')),
      );
    }
  }

  Future<void> _fetchWeather() async {
    if (_selectedLocation == null) return;
    setState(() => _weatherLoading = true);
    final w = await _weatherService.getWeather(_selectedLocation!);
    if (mounted) setState(() { _weather = w; _weatherLoading = false; });
  }

  // ── Map overlays ─────────────────────────────────────────

  void _rebuildOverlays() {
    final markers = <Marker>{};
    final polylines = <Polyline>{};

    if (_selectedLocation != null && _mode == RouteMode.ai) {
      markers.add(MapUtils.buildLocationMarker(_selectedLocation!));
    }
    if (_manualWaypoints.isNotEmpty) {
      markers.addAll(MapUtils.buildWaypointMarkers(_manualWaypoints));
      polylines.addAll(MapUtils.buildWaypointPreviewLine(_manualWaypoints));
    }
    if (_routes != null && _routes!.isNotEmpty) {
      if (_selectedRouteIndex != null && _selectedRouteIndex! < _routes!.length) {
        // Show only the selected route
        final selected = _routes![_selectedRouteIndex!];
        polylines.addAll(MapUtils.buildRoutePolylines([selected]));
        markers.addAll(MapUtils.buildRouteMarkers(selected));
      } else {
        // Show all routes
        polylines.addAll(MapUtils.buildRoutePolylines(_routes!));
        markers.addAll(MapUtils.buildRouteMarkers(_routes!.first));
      }
    }

    setState(() {
      _markers = markers;
      _polylines = polylines;
    });
  }

  Future<void> _fitCameraToRoutes() async {
    if (_routes == null || _routes!.isEmpty || _mapController == null) return;
    await Future.delayed(const Duration(milliseconds: 100));
    final target = _selectedRouteIndex != null && _selectedRouteIndex! < _routes!.length
        ? _routes![_selectedRouteIndex!]
        : _routes!.first;
    await MapUtils.fitBounds(_mapController!, target.coordinates, paddingPx: 80);
  }

  void _onRouteTap(int index) {
    setState(() => _selectedRouteIndex = _selectedRouteIndex == index ? null : index);
    _rebuildOverlays();
    _fitCameraToRoutes();
  }

  // ── Route generation ──────────────────────────────────────

  Future<void> _generateAIRoutes() async {
    if (_selectedLocation == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set a starting location first — tap the map')),
      );
      return;
    }
    setState(() { _loading = true; _routes = null; _markers = {}; _polylines = {}; _selectedRouteIndex = null; });
    try {
      final routes = await _routeRepo.generateAIRoutes(location: _selectedLocation!, radiusKm: _radiusKm, filter: _filter);
      if (!mounted) return;
      setState(() { _routes = routes; _loading = false; });
      _rebuildOverlays();
      await _fitCameraToRoutes();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _generateManualRoute() async {
    if (_manualWaypoints.length < 2) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tap at least 2 points on the map')),
      );
      return;
    }
    setState(() { _loading = true; _routes = null; _markers = {}; _polylines = {}; _selectedRouteIndex = null; });
    try {
      final route = await _routeRepo.generateManualRoute(_manualWaypoints, filter: _filter);
      if (!mounted) return;
      setState(() { _routes = [route]; _loading = false; });
      _rebuildOverlays();
      await _fitCameraToRoutes();
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Save & Ride ───────────────────────────────────────────

  Future<void> _saveRoute(CyclingRoute route) async {
    try {
      await _routeRepo.saveRoute(route);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Route saved!'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _startRide(CyclingRoute route) {
    context.pushNamed('ride', extra: route);
  }

  Future<void> _exportGpx(CyclingRoute route) async {
    try {
      final file = await GpxService.exportToFile(route);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('GPX saved: ${file.path}'), backgroundColor: Colors.blue),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('GPX error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ── UI ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final isAuthenticated = authState is AuthStateAuthenticated;

    return Scaffold(
      appBar: _BrandedAppBar(
        actions: [
          IconButton(icon: const Icon(Icons.bookmark, color: Colors.white70), onPressed: () => context.pushNamed('saved-routes'), tooltip: 'Saved Routes'),
          IconButton(icon: const Icon(Icons.dashboard, color: Colors.white70), onPressed: () => context.pushNamed('dashboard'), tooltip: 'Dashboard'),
          IconButton(icon: const Icon(Icons.person, color: Colors.white70), onPressed: () => context.pushNamed('profile'), tooltip: 'Profile'),
        ],
      ),
      // Map is pinned at top, rest scrolls below
      body: Column(
        children: [
          // ── Fixed Map ──
          Expanded(
            flex: 3,
            child: GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(10.8505, 76.2711), // Kerala center
                zoom: 8,
              ),
              markers: _markers,
              polylines: _polylines,
              onMapCreated: (c) => _mapController = c,
              onTap: _onMapTap,
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
            ),
          ),

          // ── Scrollable Controls ──
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Weather
                  WeatherWidget(weather: _weather, loading: _weatherLoading),

                  // Mode Toggle
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: RouteModeToggle(mode: _mode, onChanged: _onModeChanged),
                  ),

                  // AI Panel
                  if (_mode == RouteMode.ai)
                    AIRoutePanel(
                      radiusKm: _radiusKm,
                      onRadiusChanged: (r) => setState(() => _radiusKm = r),
                      loading: _loading,
                      onGenerate: _generateAIRoutes,
                      hasLocation: _selectedLocation != null,
                      filter: _filter,
                      onFilterChanged: (f) => setState(() => _filter = f),
                    ),

                  // Manual Panel
                  if (_mode == RouteMode.manual)
                    ManualRoutePanel(
                      waypoints: _manualWaypoints,
                      loading: _loading,
                      onGenerate: _generateManualRoute,
                      onClear: _onClearWaypoints,
                      filter: _filter,
                      onFilterChanged: (f) => setState(() => _filter = f),
                    ),

                  // Loading indicator
                  if (_loading)
                    const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),

                  // Route Cards
                  if (_routes != null && !_loading)
                    ...(_routes!.asMap().entries.map((e) => RouteCard(
                          route: e.value,
                          onTap: () => _onRouteTap(e.key),
                          isSelected: _selectedRouteIndex == e.key,
                          onSave: isAuthenticated ? () => _saveRoute(e.value) : null,
                          onRide: () => _startRide(e.value),
                          onExportGpx: () => _exportGpx(e.value),
                        ))),

                  // Sign-in prompt
                  if (!isAuthenticated)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: ElevatedButton.icon(
                        onPressed: () => context.pushNamed('auth'),
                        icon: const Icon(Icons.login),
                        label: const Text('Sign in to save routes & track rides'),
                      ),
                    ),

                  const SizedBox(height: 80),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onModeChanged(RouteMode newMode) {
    setState(() { _mode = newMode; _manualWaypoints.clear(); _routes = null; _selectedRouteIndex = null; });
    _rebuildOverlays();
  }

  void _onClearWaypoints() {
    setState(() => _manualWaypoints.clear());
    _rebuildOverlays();
  }

  void _onMapTap(LatLng latLng) {
    if (_mode == RouteMode.manual) {
      setState(() => _manualWaypoints.add(Coordinate(lat: latLng.latitude, lng: latLng.longitude)));
      _rebuildOverlays();
    } else {
      setState(() => _selectedLocation = Coordinate(lat: latLng.latitude, lng: latLng.longitude));
      _rebuildOverlays();
      _fetchWeather();
    }
  }
}

// ── Branded AppBar ─────────────────────────────────────

class _BrandedAppBar extends StatelessWidget implements PreferredSizeWidget {
  final List<Widget> actions;
  const _BrandedAppBar({required this.actions});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF02494D), Color(0xFF013235)],
        ),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              // Brand identity
              const Padding(
                padding: EdgeInsets.only(left: 12, right: 8),
                child: Icon(Icons.pedal_bike, color: Color(0xFFECC382), size: 28),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CycleZen',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.2,
                      ),
                    ),
                    Text(
                      'DISCOVER · PLAN · RIDE · SHARE',
                      style: TextStyle(
                        fontFamily: 'Montserrat',
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFECC382).withValues(alpha: 0.7),
                        letterSpacing: 1.5,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
              // Action buttons
              ...actions,
            ],
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(56);
}
