import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:cyclezen/domain/models/models.dart';
import 'package:cyclezen/features/ride/services/ride_tracking_service.dart';
import 'package:cyclezen/data/repositories/ride_repository.dart';
import 'package:cyclezen/data/services/gpx_service.dart';
import 'package:cyclezen/data/services/achievement_service.dart';
import 'package:cyclezen/data/services/ride_share_service.dart';
import 'package:cyclezen/shared/utils/map_utils.dart';

class UnifiedRidePage extends StatefulWidget {
  final CyclingRoute route;
  const UnifiedRidePage({super.key, required this.route});

  @override
  State<UnifiedRidePage> createState() => _UnifiedRidePageState();
}

class _UnifiedRidePageState extends State<UnifiedRidePage> {
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

  CyclingRoute get _route => widget.route;

  @override
  void initState() {
    super.initState();

    if (_route.coordinates.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Route has no path data'), backgroundColor: Colors.red),
        );
        context.pop();
      });
      return;
    }

    _stateSub = _trackingService.stateStream.listen((s) {
      if (mounted) setState(() => _rideState = s);
    });
    _pathSub = _trackingService.pathStream.listen((path) {
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
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
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

    SystemChrome.setPreferredOrientations([]);
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
    super.dispose();
  }

  // ── UI ────────────────────────────────────────────────

  Color get _panelBg => _isDark
      ? const Color(0xE6011A1C)
      : const Color(0xE602494D);

  Color get _panelAccent => _isDark
      ? const Color(0xFF257A77)
      : const Color(0xFFECC382);

  Color get _speedColor {
    if (_rideState.status == RideStatus.paused) return Colors.orange;
    if (_rideState.currentSpeedKmh > 0) return _panelAccent;
    return Colors.white70;
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

    return Scaffold(
      body: Stack(
        children: [
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
          ),

          // Close button (top-left)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: Material(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () {
                  SystemChrome.setPreferredOrientations([]);
                  context.pop();
                },
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.close, color: Colors.white, size: 22),
                ),
              ),
            ),
          ),

          // Bottom bike computer panel
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _BottomPanel(
              isIdle: isIdle,
              isActive: isActive,
              isPaused: isPaused,
              rideState: _rideState,
              currentInstruction: _currentInstruction,
              remainingDistanceKm: _remainingDistanceKm,
              panelBg: _panelBg,
              panelAccent: _panelAccent,
              speedColor: _speedColor,
              metricPage: _metricPage,
              pageController: _pageController,
              formatDuration: _formatDuration,
              onPageChanged: (p) => setState(() => _metricPage = p),
              onStart: _startRide,
              onPause: _togglePause,
              onStop: _stopRide,
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
  final bool isIdle, isActive, isPaused;
  final RideState rideState;
  final String currentInstruction;
  final double remainingDistanceKm;
  final Color panelBg, panelAccent, speedColor;
  final int metricPage;
  final PageController pageController;
  final String Function(Duration) formatDuration;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onStart, onPause, onStop;

  const _BottomPanel({
    required this.isIdle, required this.isActive, required this.isPaused,
    required this.rideState, required this.currentInstruction,
    required this.remainingDistanceKm, required this.panelBg,
    required this.panelAccent, required this.speedColor,
    required this.metricPage, required this.pageController,
    required this.formatDuration, required this.onPageChanged,
    required this.onStart, required this.onPause, required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    if (isIdle) {
      return _IdlePanel(panelBg: panelBg, panelAccent: panelAccent,
        bottomPadding: bottomPadding, onStart: onStart);
    }

    return Container(
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          _SpeedDisplay(speedColor: speedColor, speedKmh: rideState.currentSpeedKmh, isPaused: isPaused),
          const SizedBox(height: 6),
          SizedBox(
            height: 120,
            child: PageView(
              controller: pageController,
              onPageChanged: onPageChanged,
              children: [
                _Page1RideStats(rideState: rideState, formatDuration: formatDuration),
                _Page2ClimbStats(rideState: rideState),
                _Page3NavInfo(currentInstruction: currentInstruction, remainingDistanceKm: remainingDistanceKm),
              ],
            ),
          ),
          const SizedBox(height: 4),
          _PageDots(current: metricPage, accent: panelAccent),
          const SizedBox(height: 10),
          _ControlBar(
            isActive: isActive, isPaused: isPaused,
            elapsed: rideState.elapsed,
            formatDuration: formatDuration,
            accent: panelAccent,
            onPause: onPause, onStop: onStop,
          ),
          const SizedBox(height: 4),
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

  const _IdlePanel({required this.panelBg, required this.panelAccent,
    required this.bottomPadding, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: panelBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 28, 24, bottomPadding + 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.directions_bike, color: Colors.white70, size: 40),
          const SizedBox(height: 8),
          Text('Ready to Ride', style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('Tap start to begin tracking', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white54)),
          const SizedBox(height: 20),
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
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hero speed ──────────────────────────────────────────

class _SpeedDisplay extends StatelessWidget {
  final Color speedColor;
  final double speedKmh;
  final bool isPaused;

  const _SpeedDisplay({required this.speedColor, required this.speedKmh, required this.isPaused});

  @override
  Widget build(BuildContext context) {
    final display = isPaused ? '⏸' : speedKmh.toStringAsFixed(1);
    return Column(
      children: [
        Text(display, style: TextStyle(
          fontSize: isPaused ? 40 : 64, fontWeight: FontWeight.w800,
          color: speedColor, height: 1.0, letterSpacing: -2)),
        Text(isPaused ? 'PAUSED' : 'km/h', style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: isPaused ? Colors.orange : Colors.white54, letterSpacing: 3)),
      ],
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
          Expanded(child: _MetricTile(icon: Icons.speed, label: 'AVG', value: '${rideState.avgSpeedKmh.toStringAsFixed(1)} km/h')),
          Expanded(child: _MetricTile(icon: Icons.rocket_launch, label: 'MAX', value: '${rideState.maxSpeedKmh.toStringAsFixed(1)} km/h')),
        ],
      ),
    );
  }
}

// ── Page 2: Climb & energy ───────────────────────────────

class _Page2ClimbStats extends StatelessWidget {
  final RideState rideState;

  const _Page2ClimbStats({required this.rideState});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: _MetricTile(icon: Icons.terrain, label: 'ASCENT', value: '${rideState.ascentM.round()} m')),
          Expanded(child: _MetricTile(icon: Icons.local_fire_department, label: 'CALORIES', value: '${rideState.caloriesKcal.round()} kcal')),
          Expanded(child: _MetricTile(icon: Icons.trending_up, label: 'GRADE', value: _gradePercent())),
          Expanded(child: _MetricTile(icon: Icons.height, label: 'ELEV', value: '— m')),
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

// ── Page 3: Navigation ──────────────────────────────────

class _Page3NavInfo extends StatelessWidget {
  final String currentInstruction;
  final double remainingDistanceKm;

  const _Page3NavInfo({required this.currentInstruction, required this.remainingDistanceKm});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.navigation, color: Colors.white54, size: 20),
              SizedBox(width: 8),
              Text('REMAINING', style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          Text('${remainingDistanceKm.toStringAsFixed(1)} km',
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Flexible(
            child: Text(currentInstruction, textAlign: TextAlign.center, maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
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
        Icon(icon, color: Colors.white38, size: 16),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(
          color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700,
          fontFeatures: [FontFeature.tabularFigures()]),
          textAlign: TextAlign.center),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(
          color: Colors.white38, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1.5)),
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
              color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600,
              fontFeatures: [FontFeature.tabularFigures()]))),
          const Spacer(),
          _CircleButton(size: 64,
            color: isPaused ? const Color(0xFF359780) : Colors.orange,
            icon: isPaused ? Icons.play_arrow : Icons.pause,
            iconSize: 32, onTap: onPause),
          const Spacer(),
          _CircleButton(size: 48,
            color: Colors.red.withValues(alpha: 0.8),
            icon: Icons.stop, iconSize: 24, onTap: onStop),
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
