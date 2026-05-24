import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cyclezen/domain/models/models.dart';
import 'package:cyclezen/data/repositories/route_repository.dart';
import 'package:cyclezen/data/services/gpx_service.dart';
import 'package:cyclezen/core/constants/app_assets.dart';
import 'package:cyclezen/data/services/weather_service.dart';
import 'package:cyclezen/features/home/widgets/route_mode_toggle.dart';
import 'package:cyclezen/features/home/widgets/route_card.dart';
import 'package:cyclezen/features/home/widgets/ai_route_panel.dart';
import 'package:cyclezen/features/home/widgets/manual_route_panel.dart';
import 'package:cyclezen/features/home/widgets/weather_widget.dart';
import 'package:cyclezen/features/auth/bloc/auth_bloc.dart';
import 'package:cyclezen/shared/utils/map_utils.dart';
import 'package:cyclezen/core/theme/app_theme.dart';

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
  bool _hasLocationPermission = false;
  bool _locatingMe = false;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  final List<Coordinate> _manualWaypoints = [];
  WeatherData? _weather;
  int? _selectedRouteIndex;
  DateTime? _lastBackPress; // for double-tap-to-exit

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLocationServices(); // prompt if GPS is off
    });
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  /// Check if device location (GPS) is enabled. If not, prompt user to turn it on.
  /// Industry-standard flow: check → dialog → open settings → retry.
  Future<void> _checkLocationServices() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!mounted) return;
      final openSettings = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.location_off, color: Colors.orange),
              SizedBox(width: 12),
              Text('Location Required'),
            ],
          ),
          content: const Text(
            'CycleZen needs your device location to find nearby cycling routes '
            'and track your rides.\n\n'
            'Please enable Location Services in your device settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not Now'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.settings),
              label: const Text('Open Settings'),
            ),
          ],
        ),
      );

      if (openSettings == true) {
        await Geolocator.openLocationSettings();
        // Re-check after returning from settings
        if (!mounted) return;
        final nowEnabled = await Geolocator.isLocationServiceEnabled();
        if (nowEnabled) {
          _startLocationFlow();
        } else {
          // Still off — show persistent banner
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location services still disabled. Routes cannot be generated.'),
                duration: Duration(seconds: 4),
              ),
            );
          }
        }
      }
      return;
    }

    // GPS is on — proceed normally
    _startLocationFlow();
  }

  /// Kick off the normal location flow once GPS is confirmed on.
  void _startLocationFlow() {
    _quickLocate();
    _fetchDefaultWeather();
  }

  /// Load weather for display area while GPS resolves.
  /// Does NOT pin a fake location — waits for real GPS data.
  Future<void> _fetchDefaultWeather() async {
    final w = await _weatherService.getWeather(
      const Coordinate(lat: 10.8505, lng: 76.2711),
    );
    if (!mounted) return;
    // Show weather for the display area, but don't pin until GPS resolves
    if (_weather == null) {
      setState(() => _weather = w);
    }
    // Kick off live GPS if cached position isn't available
    if (_selectedLocation == null) {
      _requestLocationPermission();
    }
  }

  // ── Fast Location (Instant) ───────────────────────────────

  /// Tries cached position first, falls back to live GPS with timeout.
  Future<void> _quickLocate() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _checkLocationServices();
      return;
    }
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      final result = await Geolocator.requestPermission();
      if (result != LocationPermission.whileInUse && result != LocationPermission.always) {
        return;
      }
    }
    if (perm == LocationPermission.deniedForever) return;

    // Try cached first
    final cached = await Geolocator.getLastKnownPosition();
    if (cached != null) {
      _hasLocationPermission = true;
      if (!mounted) return;
      setState(() {
        _selectedLocation = Coordinate(lat: cached.latitude, lng: cached.longitude);
      });
      _rebuildOverlays();
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(
        LatLng(cached.latitude, cached.longitude), 15,
      ));
      _fetchWeather();
      return;
    }

    // No cached position — fall through to live GPS silently
    _requestLocationPermission();
  }

  /// Called by the locate-me FAB and the "my location" map button.
  /// Always goes for live GPS with a visible loading state.
  Future<void> _locateMe() async {
    if (_locatingMe) return;
    setState(() => _locatingMe = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _checkLocationServices();
        return;
      }

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
          const SnackBar(
            content: Text('Location blocked. Enable in Settings → Apps → CycleZen → Permissions.'),
            duration: Duration(seconds: 5),
          ),
        );
        return;
      }

      // Try cached first for speed, then live with adequate timeout
      Position? pos = await Geolocator.getLastKnownPosition();
      if (pos == null) {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 15),
          ),
        ).timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw TimeoutException('GPS fix timed out'),
        );
      }

      if (!mounted) return;
      final position = pos!;
      _hasLocationPermission = true;
      setState(() {
        _selectedLocation = Coordinate(lat: position.latitude, lng: position.longitude);
        _locatingMe = false;
      });
      _rebuildOverlays();
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(
        LatLng(position.latitude, position.longitude), 15,
      ));
      _fetchWeather();
      HapticFeedback.lightImpact();
    } on TimeoutException {
      if (!mounted) return;
      setState(() => _locatingMe = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('GPS signal weak. Try moving to an open area or check location settings.'),
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _locatingMe = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location error: ${e.toString().replaceAll('Exception: ', '')}')),
      );
    }
  }

  /// Full permission + live GPS — called when needed.
  Future<void> _requestLocationPermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _checkLocationServices(); // re-prompt
        return;
      }
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
          const SnackBar(
            content: Text('Location permanently denied. Enable in Settings.'),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }

      Position? pos = await Geolocator.getLastKnownPosition();
      if (pos == null) {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 15),
          ),
        ).timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw TimeoutException('GPS fix timed out'),
        );
      }

      if (!mounted) return;
      final position = pos!;
      _hasLocationPermission = true;
      setState(() {
        _selectedLocation = Coordinate(lat: position.latitude, lng: position.longitude);
      });
      _rebuildOverlays();
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(
        LatLng(position.latitude, position.longitude), 15,
      ));
      _fetchWeather();
      HapticFeedback.lightImpact();
    } on TimeoutException {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('GPS signal weak — move to an open area and try again.'),
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Location error: ${e.toString().replaceAll('Exception: ', '')}')),
      );
    }
  }

  Future<void> _fetchWeather() async {
    if (_selectedLocation == null) return;
    final w = await _weatherService.getWeather(_selectedLocation!);
    if (mounted) setState(() => _weather = w);
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
        final selected = _routes![_selectedRouteIndex!];
        polylines.addAll(MapUtils.buildRoutePolylines([selected]));
        markers.addAll(MapUtils.buildRouteMarkers(selected));
      } else {
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
    HapticFeedback.selectionClick();
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
    HapticFeedback.mediumImpact();
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
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.primaryDark),
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
    HapticFeedback.mediumImpact();
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
          SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.primaryDark),
        );
      }
    }
  }

  // ── Save & Ride ───────────────────────────────────────────

  Future<void> _saveRoute(CyclingRoute route) async {
    HapticFeedback.lightImpact();
    try {
      await _routeRepo.saveRoute(route);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Route saved!'), backgroundColor: AppTheme.greenAccent),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e'), backgroundColor: AppTheme.primaryDark),
      );
    }
  }

  void _startRide(CyclingRoute route) {
    HapticFeedback.heavyImpact();
    context.pushNamed('ride', extra: route);
  }

  Future<void> _exportGpx(CyclingRoute route) async {
    HapticFeedback.lightImpact();
    try {
      final file = await GpxService.exportToFile(route);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('GPX saved: ${file.path}'), backgroundColor: AppTheme.secondaryTeal),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('GPX error: $e'), backgroundColor: AppTheme.primaryDark),
      );
    }
  }

  // ── Exit confirmation ─────────────────────────────────────

  Future<bool> _onWillPop() async {
    if (_lastBackPress == null ||
        DateTime.now().difference(_lastBackPress!) > const Duration(seconds: 2)) {
      _lastBackPress = DateTime.now();
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Press back again to exit'),
          duration: const Duration(seconds: 2),
          backgroundColor: AppTheme.surfaceDark,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(40, 0, 40, 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return false;
    }
    return true; // second press → exit
  }

  // ── UI ────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final isAuthenticated = authState is AuthStateAuthenticated;

    return PopScope(
      canPop: false, // we handle it
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldExit = await _onWillPop();
        if (shouldExit && mounted) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        appBar: _BrandedAppBar(
          actions: [
            IconButton(icon: const Icon(Icons.bookmark, color: Colors.white), onPressed: () => context.pushNamed('saved-routes'), tooltip: 'Saved Routes'),
            IconButton(icon: const Icon(Icons.dashboard, color: Colors.white), onPressed: () => context.pushNamed('dashboard'), tooltip: 'Dashboard'),
            IconButton(icon: const Icon(Icons.person, color: Colors.white), onPressed: () => context.pushNamed('profile'), tooltip: 'Profile'),
          ],
        ),
        body: Column(
          children: [
            // ── Fixed Map ──
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  RepaintBoundary(
                    child: GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: LatLng(10.8505, 76.2711), // Kerala center
                      zoom: 8,
                    ),
                    markers: _markers,
                    polylines: _polylines,
                    onMapCreated: (c) => _mapController = c,
                    onTap: _onMapTap,
                    myLocationEnabled: _hasLocationPermission,
                    myLocationButtonEnabled: true, // always show native button
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                  ),
                  ),
                  // ── Custom Locate-Me FAB ──
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: FloatingActionButton.small(
                      heroTag: 'locateMe',
                      onPressed: _locatingMe ? null : _locateMe,
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      child: _locatingMe
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(Icons.my_location,
                              color: _hasLocationPermission
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey),
                    ),
                  ),
                ],
              ),
            ),

            // ── Scrollable Controls ──
            Expanded(
              flex: 4,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    WeatherWidget(weather: _weather),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: RouteModeToggle(mode: _mode, onChanged: _onModeChanged),
                    ),
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
                    if (_mode == RouteMode.manual)
                      ManualRoutePanel(
                        waypoints: _manualWaypoints,
                        loading: _loading,
                        onGenerate: _generateManualRoute,
                        onClear: _onClearWaypoints,
                        filter: _filter,
                        onFilterChanged: (f) => setState(() => _filter = f),
                      ),
                    if (_loading)
                      const Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
                    if (_routes != null && !_loading)
                      ...(_routes!.asMap().entries.map((e) {
                        final index = e.key;
                        final route = e.value;
                        return TweenAnimationBuilder<double>(
                          duration: Duration(milliseconds: 350 + (index * 80)),
                          tween: Tween(begin: 0.0, end: 1.0),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 25 * (1 - value)),
                                child: child,
                              ),
                            );
                          },
                          child: RouteCard(
                            route: route,
                            onTap: () => _onRouteTap(index),
                            isSelected: _selectedRouteIndex == index,
                            onSave: () => _saveRoute(route),
                            onRide: () => _startRide(route),
                            onExportGpx: () => _exportGpx(route),
                          ),
                        );
                      })),
                    if (!isAuthenticated)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: ElevatedButton.icon(
                          onPressed: () => context.pushNamed('auth'),
                          icon: const Icon(Icons.login),
                          label: const Text('Sign in to sync routes across devices'),
                        ),
                      ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onModeChanged(RouteMode newMode) {
    HapticFeedback.selectionClick();
    setState(() { _mode = newMode; _manualWaypoints.clear(); _routes = null; _selectedRouteIndex = null; });
    _rebuildOverlays();
  }

  void _onClearWaypoints() {
    HapticFeedback.lightImpact();
    setState(() => _manualWaypoints.clear());
    _rebuildOverlays();
  }

  void _onMapTap(LatLng latLng) {
    HapticFeedback.selectionClick();
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
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.primaryDark, AppTheme.surfaceDark],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(left: 12, right: 4, top: 4, bottom: 4),
          child: Row(
            children: [
              ClipOval(
                child: Image.asset(
                  AppAssets.logoMark,
                  width: 30,
                  height: 30,
                  fit: BoxFit.cover,

                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CycleZen',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Text(
                      'DISCOVER · PLAN · RIDE · SHARE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.goldRing,
                        letterSpacing: 0.8,
                        height: 1.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(54);
}
