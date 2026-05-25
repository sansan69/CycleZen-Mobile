import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:cyclezen/domain/models/models.dart';
import 'package:cyclezen/features/ride/services/ride_tracking_service.dart';
import 'package:cyclezen/data/repositories/ride_repository.dart';
import 'package:cyclezen/data/services/gpx_service.dart';
import 'package:cyclezen/data/services/achievement_service.dart';
import 'package:cyclezen/data/services/ride_share_service.dart';
import 'package:cyclezen/shared/utils/map_utils.dart';
import 'package:cyclezen/core/theme/app_theme.dart';

class UnifiedRidePage extends StatefulWidget {
  final CyclingRoute route;
  const UnifiedRidePage({super.key, required this.route});

  @override
  State<UnifiedRidePage> createState() => _UnifiedRidePageState();
}

class _UnifiedRidePageState extends State<UnifiedRidePage>
    with TickerProviderStateMixin {
  final RideTrackingService _trackingService = RideTrackingService();
  final RideRepository _rideRepo = RideRepository();
  final AchievementService _achievementService = AchievementService();

  RideState _rideState = const RideState(
    status: RideStatus.idle, distanceKm: 0, elapsed: Duration.zero,
    avgSpeedKmh: 0, maxSpeedKmh: 0, currentSpeedKmh: 0,
    ascentM: 0, caloriesKcal: 0,
  );
  StreamSubscription<RideState>? _stateSub;
  StreamSubscription<List<Coordinate>>? _pathSub;
  StreamSubscription<String>? _instructionSub;
  StreamSubscription<double>? _distSub;

  GoogleMapController? _mapController;
  final List<LatLng> _recordedPath = [];
  String _currentInstruction = 'Ready to ride';
  double _remainingDistanceKm = 0;
  bool _isDark = false;
  int _metricPage = 0;
  final PageController _pageController = PageController();

  // ── New state ──
  MapType _mapType = MapType.normal;
  double _prevSpeed = 0;
  double _panelExpanded = 0; // 0=collapsed, 1=expanded
  final List<String> _achievementToasts = [];
  Timer? _toastTimer;
  double _prevDistance = 0;
  double _prevAscent = 0;

  CyclingRoute get _route => widget.route;

  // Computed
  double get _progressPercent {
    if (_route.distanceKm <= 0) return 0;
    return (_rideState.distanceKm / _route.distanceKm).clamp(0.0, 1.0);
  }

  String get _etaText {
    if (_rideState.status != RideStatus.active) return '--';
    if (_rideState.avgSpeedKmh <= 0) return '--';
    final remainingH = _remainingDistanceKm / _rideState.avgSpeedKmh;
    final mins = (remainingH * 60).round();
    if (mins >= 60) return '${mins ~/ 60}h ${mins % 60}m';
    return '$mins min';
  }

  String get _calPerHour {
    if (_rideState.elapsed.inSeconds < 10) return '-- kcal/h';
    final h = _rideState.elapsed.inSeconds / 3600;
    if (h < 0.001) return '-- kcal/h';
    return '${(_rideState.caloriesKcal / h).round()} kcal/h';
  }

  @override
  void initState() {
    super.initState();

    if (_route.coordinates.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Route has no path data'), backgroundColor: Colors.red),
        );
        context.pop();
      });
      return;
    }

    _stateSub = _trackingService.stateStream.listen((s) {
      if (!mounted) return;
      // Check for milestone achievements
      _checkMilestones(s);
      setState(() => _rideState = s);
    });
    _pathSub = _trackingService.pathStream.listen((path) {
      if (!mounted) return;
      setState(() {
        _recordedPath.clear();
        _recordedPath.addAll(path.map((c) => LatLng(c.lat, c.lng)));
      });
      if (_rideState.status == RideStatus.active && _recordedPath.isNotEmpty && _mapController != null) {
        _mapController!.animateCamera(CameraUpdate.newLatLng(_recordedPath.last));
      }
    });
    _instructionSub = _trackingService.instructionStream.listen((text) {
      if (mounted) setState(() => _currentInstruction = text);
    });
    _distSub = _trackingService.remainingDistanceStream.listen((d) {
      if (mounted) setState(() => _remainingDistanceKm = d);
    });
  }

  void _checkMilestones(RideState state) {
    // Distance milestones
    final distInt = state.distanceKm.floor();
    final prevDistInt = _prevDistance.floor();
    if (distInt > prevDistInt && distInt % 5 == 0) {
      _showAchievementToast('🔥 $distInt km!');
    }
    // Ascent milestones
    final ascentInt = state.ascentM.floor();
    final prevAscentInt = _prevAscent.floor();
    if (ascentInt > prevAscentInt && ascentInt % 50 == 0 && ascentInt > 0) {
      _showAchievementToast('⛰️ ${ascentInt}m climbed!');
    }
    _prevDistance = state.distanceKm;
    _prevAscent = state.ascentM;
  }

  void _showAchievementToast(String msg) {
    setState(() => _achievementToasts.add(msg));
    _toastTimer?.cancel();
    _toastTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() {
        if (_achievementToasts.isNotEmpty) _achievementToasts.removeAt(0);
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _isDark = Theme.of(context).brightness == Brightness.dark;
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    MapUtils.fitBounds(controller, _route.coordinates, paddingPx: 80);
  }

  // ── Ride controls ─────────────────────────────────────

  Future<void> _startRide() async {
    final ok = await _trackingService.requestPermissions();
    if (!ok) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission required')),
      );
      return;
    }
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    try {
      _trackingService.startRide(
        steps: _route.steps,
        routeCoords: _route.coordinates,
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ride start error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _togglePause() => _trackingService.togglePause();

  Future<void> _stopRide() async {
    final cal = _rideState.caloriesKcal;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Ride?'),
        content: Text(
          'Distance: ${_rideState.distanceKm.toStringAsFixed(2)} km\n'
          'Time: ${_formatDuration(_rideState.elapsed)}\n'
          'Ascent: ${_rideState.ascentM.round()} m\n'
          'Calories: ~${cal.round()} kcal',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('End Ride')),
        ],
      ),
    );
    if (confirmed != true) return;

    await SystemChrome.setPreferredOrientations([]);
    final recording = _trackingService.stopRide(plannedRoute: _route);
    try {
      await _rideRepo.saveCompletedRide(recording);
      final fullRides = await _rideRepo.getCompletedRides();
      final unlocked = _achievementService.calculateAchievements(fullRides)
          .where((a) => a.isUnlocked).toList();
      if (mounted) {
        final msg = unlocked.isEmpty
            ? 'Ride saved! ${cal.round()} kcal burned 🔥'
            : 'Ride saved! 🏆 ${unlocked.length} new achievement${unlocked.length > 1 ? 's' : ''}!';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.green),
        );
        _showPostRideDialog(recording);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _exportGpx() async {
    try {
      final file = await GpxService.exportRideToFile(
        RideRecording(
          route: _route,
          actualDistanceKm: _rideState.distanceKm,
          actualDurationSec: _rideState.elapsed.inSeconds.toDouble(),
          avgSpeedKmh: _rideState.avgSpeedKmh,
          maxSpeedKmh: _rideState.maxSpeedKmh,
          recordedPath: _recordedPath.map((ll) => Coordinate(lat: ll.latitude, lng: ll.longitude)).toList(),
          completedAt: DateTime.now(),
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('GPX saved: ${file.path}'), backgroundColor: Colors.blue),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('GPX error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showPostRideDialog(RideRecording recording) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ride Complete!'),
        content: const Text('Export GPX for Strava/Komoot, or share a summary with friends.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
          ElevatedButton.icon(
            onPressed: () { Navigator.pop(ctx); _exportGpx(); },
            icon: const Icon(Icons.file_download),
            label: const Text('GPX'),
          ),
          ElevatedButton.icon(
            onPressed: () { Navigator.pop(ctx); RideShareService.shareRide(recording); },
            icon: const Icon(Icons.share),
            label: const Text('Share'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours, m = d.inMinutes.remainder(60), s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m ${s}s';
    return '${m}m ${s}s';
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([]);
    _pageController.dispose();
    _stateSub?.cancel(); _pathSub?.cancel();
    _instructionSub?.cancel(); _distSub?.cancel();
    _trackingService.dispose();
    _toastTimer?.cancel();
    super.dispose();
  }

  // ── UI ────────────────────────────────────────────────

  Color get _panelBg => _isDark
      ? const Color(0xD9011A1C)
      : const Color(0xD902494D);

  Color get _panelAccent => _isDark
      ? AppTheme.secondaryTeal
      : AppTheme.goldRing;

  Color _speedZoneColor(double kmh) {
    if (kmh < 15) return const Color(0xFF4CAF50);  // green — cruising
    if (kmh < 30) return const Color(0xFFFFC107);  // gold — pushing
    return const Color(0xFFFF5722);                  // red — sprinting
  }

  /// Parse instruction text to get direction arrow
  IconData _directionIcon(String instruction) {
    final lower = instruction.toLowerCase();
    if (lower.contains('right') || lower.contains('right')) return Icons.turn_right;
    if (lower.contains('left')) return Icons.turn_left;
    if (lower.contains('slight right')) return Icons.turn_slight_right;
    if (lower.contains('slight left')) return Icons.turn_slight_left;
    if (lower.contains('sharp right')) return Icons.turn_sharp_right;
    if (lower.contains('sharp left')) return Icons.turn_sharp_left;
    if (lower.contains('u-turn') || lower.contains('uturn')) return Icons.u_turn_left;
    if (lower.contains('roundabout') || lower.contains('rotary')) return Icons.roundabout_right;
    if (lower.contains('arrive') || lower.contains('destination')) return Icons.flag;
    if (lower.contains('continue') || lower.contains('straight')) return Icons.arrow_upward;
    return Icons.navigation;
  }

  /// Build elevation sparkline from route coordinates
  List<double> _buildElevationProfile() {
    final coords = _route.coordinates;
    if (coords.isEmpty) return [];
    // Simple sample — take every Nth point
    final step = max(1, coords.length ~/ 40);
    final profile = <double>[];
    double minE = double.infinity, maxE = double.negativeInfinity;
    final temp = <double>[];
    for (int i = 0; i < coords.length; i += step) {
      final e = coords[i].elev ?? 0;
      temp.add(e);
      if (e < minE) minE = e;
      if (e > maxE) maxE = e;
    }
    if (maxE - minE < 1) return temp; // flat — no normalization needed
    for (final e in temp) {
      profile.add((e - minE) / (maxE - minE));
    }
    return profile;
  }

  @override
  Widget build(BuildContext context) {
    final polylines = <Polyline>{
      Polyline(
        polylineId: const PolylineId('planned'),
        points: _route.coordinates.map((c) => LatLng(c.lat, c.lng)).toList(),
        color: Colors.blue.withValues(alpha: 0.35),
        width: 4,
        patterns: [PatternItem.dash(8), PatternItem.gap(4)],
      ),
    };
    if (_recordedPath.length > 1) {
      polylines.add(Polyline(
        polylineId: const PolylineId('recorded'),
        points: List.from(_recordedPath),
        color: Colors.red, width: 5,
      ));
    }
    final markers = MapUtils.buildRouteMarkers(_route, prefix: 'ride_');

    final isActive = _rideState.status == RideStatus.active;
    final isPaused = _rideState.status == RideStatus.paused;
    final isIdle = _rideState.status == RideStatus.idle;
    final topPadding = MediaQuery.of(context).padding.top;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      body: Stack(
        children: [
          // ── Map ──
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(_route.coordinates.first.lat, _route.coordinates.first.lng),
              zoom: 15,
            ),
            onMapCreated: _onMapCreated,
            myLocationEnabled: true,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            polylines: polylines,
            markers: markers,
            compassEnabled: true,
            mapType: _mapType,
          ),

          // ── Top bar: close + map toggle ──
          Positioned(
            top: topPadding + 8,
            left: 12,
            right: 12,
            child: Row(
              children: [
                // Close / back button
                Material(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () async {
                      if (isActive || isPaused) {
                        final exit = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Exit Ride?'),
                            content: const Text('Your ride is still in progress. Are you sure you want to exit?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay')),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                child: const Text('Exit'),
                              ),
                            ],
                          ),
                        );
                        if (exit != true) return;
                      }
                      SystemChrome.setPreferredOrientations([]);
                      if (mounted) context.pop();
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.arrow_back, color: Colors.white, size: 18),
                          SizedBox(width: 4),
                          Text('Exit', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                // Map style toggle
                Material(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _mapType = _mapType == MapType.normal ? MapType.hybrid : MapType.normal;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        _mapType == MapType.normal ? Icons.satellite_alt : Icons.map,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Achievement toasts ──
          if (_achievementToasts.isNotEmpty)
            Positioned(
              top: topPadding + 60,
              left: 0, right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12),
                    ],
                  ),
                  child: Text(
                    _achievementToasts.last,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ).animate().fadeIn(duration: 300.ms).then().fadeOut(delay: 2500.ms),
              ),
            ),

          // ── Bottom panel ──
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _BottomPanel(
              isIdle: isIdle,
              isActive: isActive,
              isPaused: isPaused,
              isLandscape: isLandscape,
              rideState: _rideState,
              currentInstruction: _currentInstruction,
              remainingDistanceKm: _remainingDistanceKm,
              panelBg: _panelBg,
              panelAccent: _panelAccent,
              metricPage: _metricPage,
              pageController: _pageController,
              progressPercent: _progressPercent,
              etaText: _etaText,
              calPerHour: _calPerHour,
              elevationProfile: _buildElevationProfile(),
              directionIcon: _directionIcon(_currentInstruction),
              speedZoneColor: _rideState.currentSpeedKmh > 0
                  ? _speedZoneColor(_rideState.currentSpeedKmh)
                  : Colors.white70,
              formatDuration: _formatDuration,
              onPageChanged: (p) {
                HapticFeedback.selectionClick();
                setState(() => _metricPage = p);
              },
              onStart: _startRide,
              onPause: _togglePause,
              onStop: _stopRide,
              route: _route,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// Bottom Panel
// ═══════════════════════════════════════════════════════

class _BottomPanel extends StatelessWidget {
  final bool isIdle, isActive, isPaused, isLandscape;
  final RideState rideState;
  final String currentInstruction;
  final double remainingDistanceKm;
  final Color panelBg, panelAccent;
  final int metricPage;
  final PageController pageController;
  final double progressPercent;
  final String etaText, calPerHour;
  final List<double> elevationProfile;
  final IconData directionIcon;
  final Color speedZoneColor;
  final String Function(Duration) formatDuration;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onStart, onPause, onStop;
  final CyclingRoute route;

  const _BottomPanel({
    required this.isIdle, required this.isActive, required this.isPaused,
    required this.isLandscape, required this.rideState,
    required this.currentInstruction, required this.remainingDistanceKm,
    required this.panelBg, required this.panelAccent,
    required this.metricPage, required this.pageController,
    required this.progressPercent, required this.etaText,
    required this.calPerHour, required this.elevationProfile,
    required this.directionIcon, required this.speedZoneColor,
    required this.formatDuration, required this.onPageChanged,
    required this.onStart, required this.onPause, required this.onStop,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    if (isIdle) {
      return _IdlePanel(
        panelBg: panelBg, panelAccent: panelAccent,
        bottomPadding: bottomPadding, onStart: onStart,
        route: route,
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: const ColorFilter.mode(Colors.black26, BlendMode.srcOver),
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomPadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Progress bar ──
                _ProgressBar(percent: progressPercent, accent: panelAccent),
                const SizedBox(height: 10),

                // ── Speed display ──
                _SpeedDisplay(
                  speedKmh: rideState.currentSpeedKmh,
                  isPaused: isPaused,
                  zoneColor: speedZoneColor,
                  isLandscape: isLandscape,
                ),

                if (!isLandscape) ...[
                  const SizedBox(height: 4),
                  SizedBox(
                    height: 115,
                    child: PageView(
                      controller: pageController,
                      onPageChanged: onPageChanged,
                      children: [
                        _Page1RideStats(rideState: rideState, formatDuration: formatDuration),
                        _Page2ClimbStats(
                          rideState: rideState,
                          calPerHour: calPerHour,
                          elevationProfile: elevationProfile,
                        ),
                        _Page3NavInfo(
                          currentInstruction: currentInstruction,
                          remainingDistanceKm: remainingDistanceKm,
                          etaText: etaText,
                          directionIcon: directionIcon,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  _PageDots(current: metricPage, accent: panelAccent),
                  const SizedBox(height: 8),
                ],

                // ── Control bar ──
                _ControlBar(
                  isActive: isActive, isPaused: isPaused,
                  elapsed: rideState.elapsed,
                  formatDuration: formatDuration,
                  accent: panelAccent,
                  onPause: onPause, onStop: onStop,
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Progress bar ───────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final double percent;
  final Color accent;
  const _ProgressBar({required this.percent, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(accent),
              minHeight: 3,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text('${(percent * 100).round()}%',
                style: TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w600)),
              const Spacer(),
              // Simple route length marker
              Text('Route',
                style: TextStyle(color: Colors.white24, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Idle panel ──────────────────────────────────────────

class _IdlePanel extends StatelessWidget {
  final Color panelBg, panelAccent;
  final double bottomPadding;
  final VoidCallback onStart;
  final CyclingRoute route;

  const _IdlePanel({required this.panelBg, required this.panelAccent,
    required this.bottomPadding, required this.onStart, required this.route});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 20, 24, bottomPadding + 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Route preview card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(route.routeName ?? 'Route', style: const TextStyle(
                        color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _previewChip(Icons.straighten, '${route.distanceKm.toStringAsFixed(1)} km'),
                          const SizedBox(width: 12),
                          _previewChip(Icons.timer_outlined, '${route.estimatedTimeMin.round()} min'),
                          const SizedBox(width: 12),
                          _previewChip(Icons.terrain, '${(route.ascentM ?? 0).round()} m'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, height: 56,
            child: ElevatedButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.play_arrow, size: 28),
              label: const Text('Start Ride', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF359780),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ).animate().scale(delay: 200.ms, duration: 500.ms, curve: Curves.elasticOut),
          ),
        ],
      ),
    );
  }

  Widget _previewChip(IconData icon, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 14, color: Colors.white54),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
    ]);
  }
}

// ── Hero speed ──────────────────────────────────────────

class _SpeedDisplay extends StatelessWidget {
  final double speedKmh;
  final bool isPaused;
  final Color zoneColor;
  final bool isLandscape;

  const _SpeedDisplay({
    required this.speedKmh, required this.isPaused,
    required this.zoneColor, required this.isLandscape,
  });

  @override
  Widget build(BuildContext context) {
    final display = isPaused ? '⏸' : speedKmh.toStringAsFixed(1);
    final label = isPaused ? 'PAUSED' : 'km/h';
    final labelColor = isPaused ? Colors.orange : Colors.white54;
    final fontSize = isLandscape ? 80.0 : 58.0;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
      child: Column(
        key: ValueKey(display),
        children: [
          Text(display, style: TextStyle(
            fontSize: fontSize, fontWeight: FontWeight.w800,
            color: isPaused ? Colors.orange : zoneColor,
            height: 1.0, letterSpacing: -2,
            shadows: [
              Shadow(
                color: (isPaused ? Colors.orange : zoneColor).withValues(alpha: 0.3),
                blurRadius: 20,
              ),
            ],
          )),
          Text(label, style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: labelColor, letterSpacing: 3)),
        ],
      ),
    );
  }
}

// ── Page 1: Ride essentials ──────────────────────────────

class _Page1RideStats extends StatelessWidget {
  final RideState rideState;
  final String Function(Duration) formatDuration;

  const _Page1RideStats({required this.rideState, required this.formatDuration});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: _MetricTile(icon: Icons.straighten, label: 'DIST', value: '${rideState.distanceKm.toStringAsFixed(1)} km')),
          Expanded(child: _MetricTile(icon: Icons.timer_outlined, label: 'TIME', value: formatDuration(rideState.elapsed))),
          Expanded(child: _MetricTile(icon: Icons.speed, label: 'AVG', value: '${rideState.avgSpeedKmh.toStringAsFixed(1)}')),
          Expanded(child: _MetricTile(icon: Icons.rocket_launch, label: 'MAX', value: '${rideState.maxSpeedKmh.toStringAsFixed(1)}')),
        ],
      ),
    );
  }
}

// ── Page 2: Climb & energy ───────────────────────────────

class _Page2ClimbStats extends StatelessWidget {
  final RideState rideState;
  final String calPerHour;
  final List<double> elevationProfile;

  const _Page2ClimbStats({
    required this.rideState,
    required this.calPerHour,
    required this.elevationProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(child: _MetricTile(icon: Icons.terrain, label: 'ASCENT', value: '${rideState.ascentM.round()} m')),
              Expanded(child: _MetricTile(icon: Icons.local_fire_department, label: 'CAL', value: '${rideState.caloriesKcal.round()} kcal')),
              Expanded(child: _MetricTile(icon: Icons.trending_up, label: 'GRADE', value: _gradePercent())),
              Expanded(child: _MetricTile(icon: Icons.bolt, label: 'RATE', value: calPerHour)),
            ],
          ),
          const SizedBox(height: 6),
          // ── Elevation sparkline ──
          if (elevationProfile.isNotEmpty)
            SizedBox(
              height: 28,
              child: CustomPaint(
                size: Size.infinite,
                painter: _ElevationSparklinePainter(profile: elevationProfile),
              ),
            ),
        ],
      ),
    );
  }

  String _gradePercent() {
    if (rideState.distanceKm < 0.05) return '— %';
    final grade = (rideState.ascentM / (rideState.distanceKm * 1000)) * 100;
    return '${grade.toStringAsFixed(1)}%';
  }
}

class _ElevationSparklinePainter extends CustomPainter {
  final List<double> profile;
  _ElevationSparklinePainter({required this.profile});

  @override
  void paint(Canvas canvas, Size size) {
    if (profile.length < 2) return;

    final paint = Paint()
      ..color = Colors.white38
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final stepX = size.width / (profile.length - 1);

    for (int i = 0; i < profile.length; i++) {
      final x = i * stepX;
      final y = size.height - (profile[i] * size.height * 0.8) - (size.height * 0.1);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);

    // Gradient fill
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white.withValues(alpha: 0.15), Colors.white.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _ElevationSparklinePainter old) => old.profile != profile;
}

// ── Page 3: Navigation ──────────────────────────────────

class _Page3NavInfo extends StatelessWidget {
  final String currentInstruction;
  final double remainingDistanceKm;
  final String etaText;
  final IconData directionIcon;

  const _Page3NavInfo({
    required this.currentInstruction,
    required this.remainingDistanceKm,
    required this.etaText,
    required this.directionIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Direction arrow
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(directionIcon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('REMAINING',
                  style: TextStyle(color: Colors.white38, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('${remainingDistanceKm.toStringAsFixed(1)} km',
                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('ETA: $etaText',
                  style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Flexible(
                  child: Text(currentInstruction, maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Metric tile ─────────────────────────────────────────

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String label, value;

  const _MetricTile({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.white38, size: 15),
        const SizedBox(height: 3),
        Text(value, style: const TextStyle(
          color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700,
          fontFeatures: [FontFeature.tabularFigures()]),
          textAlign: TextAlign.center),
        const SizedBox(height: 1),
        Text(label, style: const TextStyle(
          color: Colors.white38, fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
      ],
    );
  }
}

// ── Page dots ───────────────────────────────────────────

class _PageDots extends StatelessWidget {
  final int current;
  final Color accent;

  const _PageDots({required this.current, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 20 : 6, height: 6,
          decoration: BoxDecoration(
            color: active ? accent : Colors.white24,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

// ── Control bar ─────────────────────────────────────────

class _ControlBar extends StatelessWidget {
  final bool isActive, isPaused;
  final Duration elapsed;
  final String Function(Duration) formatDuration;
  final Color accent;
  final VoidCallback onPause, onStop;

  const _ControlBar({required this.isActive, required this.isPaused,
    required this.elapsed, required this.formatDuration,
    required this.accent, required this.onPause, required this.onStop});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(formatDuration(elapsed), style: const TextStyle(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()]))),
          const Spacer(),
          // HR zone placeholder
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('Z–', style: TextStyle(
                  color: Colors.white24, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(width: 16),
          _CircleButton(size: 60,
            color: isPaused ? const Color(0xFF359780) : Colors.orange,
            icon: isPaused ? Icons.play_arrow : Icons.pause,
            iconSize: 30, onTap: onPause),
          const SizedBox(width: 16),
          _CircleButton(size: 44,
            color: Colors.red.withValues(alpha: 0.8),
            icon: Icons.stop, iconSize: 22, onTap: onStop),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final double size;
  final Color color;
  final IconData icon;
  final double iconSize;
  final VoidCallback onTap;

  const _CircleButton({required this.size, required this.color,
    required this.icon, required this.iconSize, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      elevation: 4,
      shadowColor: color.withValues(alpha: 0.4),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size, height: size,
          child: Icon(icon, color: Colors.white, size: iconSize),
        ),
      ),
    );
  }
}
