import 'dart:async';
import 'dart:math';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cyclezen/domain/models/models.dart';

/// High-accuracy ride tracking with multi-factor stationary detection,
/// speed smoothing, and GPS drift filtering.
class RideTrackingService {
  final FlutterTts _tts = FlutterTts();
  Position? _lastPosition;
  final List<Coordinate> _recordedPath = [];
  double _totalDistanceM = 0;
  double _maxSpeedMs = 0;
  double _totalAscentM = 0;
  DateTime? _startTime;
  DateTime? _pauseStart;
  Duration _pausedDuration = Duration.zero;
  RideStatus _status = RideStatus.idle;
  StreamSubscription<Position>? _positionSubscription;

  // ── Speed smoothing (EMA low-pass filter) ──
  double _smoothedSpeedMs = 0;
  static const double _speedAlpha = 0.25;  // lower = smoother, slower to respond

  // ── Stationary detection ──
  int _consecutiveStationaryReadings = 0;
  static const double _stationarySpeedMs = 1.2;    // below this = candidate for stationary (~4.3 km/h)
  static const double _stationaryDeltaM = 3.0;      // position change below this = candidate
  static const int _stationaryReadingsToPause = 8;  // ~24s at 3s intervals
  static const double _minDistanceDeltaM = 2.0;      // ignore GPS drift below this

  // ── Navigation state ──
  int _currentStepIndex = 0;
  List<RouteStep>? _steps;
  List<Coordinate>? _routeCoordinates;
  String? _lastSpokenInstruction;

  // Stream controllers for UI updates
  final StreamController<RideState> _stateController =
      StreamController<RideState>.broadcast();
  final StreamController<List<Coordinate>> _pathController =
      StreamController<List<Coordinate>>.broadcast();
  final StreamController<String> _instructionController =
      StreamController<String>.broadcast();
  final StreamController<double> _remainingDistController =
      StreamController<double>.broadcast();

  Stream<RideState> get stateStream => _stateController.stream;
  Stream<List<Coordinate>> get pathStream => _pathController.stream;
  Stream<String> get instructionStream => _instructionController.stream;
  Stream<double> get remainingDistanceStream => _remainingDistController.stream;

  RideStatus get status => _status;
  double get totalDistanceKm => _totalDistanceM / 1000;
  double get maxSpeedKmh => _maxSpeedMs * 3.6;
  double get totalAscentM => _totalAscentM;
  List<Coordinate> get recordedPath => List.unmodifiable(_recordedPath);

  Duration get elapsed {
    if (_startTime == null) return Duration.zero;
    final total = DateTime.now().difference(_startTime!);
    return total - _pausedDuration;
  }

  double get avgSpeedKmh {
    final secs = elapsed.inSeconds;
    if (secs == 0 || _totalDistanceM == 0) return 0;
    return (_totalDistanceM / 1000) / (secs / 3600.0);
  }

  /// Displayed speed: smoothed value, zeroed when stationary
  double get currentSpeedKmh {
    if (_status == RideStatus.paused || _status == RideStatus.idle) return 0;
    // When stationary (low smoothed speed), show 0
    if (_smoothedSpeedMs < 0.8) return 0;
    return _smoothedSpeedMs * 3.6;
  }

  // ── Calorie estimation ──
  double estimateCalories({double weightKg = 70}) {
    final flatKcal = weightKg * totalDistanceKm * 0.5;
    final ascentKcal = (totalAscentM / 100) * weightKg * 0.15;
    return flatKcal + ascentKcal;
  }

  // ── Permissions ───────────────────────────────────────

  Future<bool> requestPermissions() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final result = await Geolocator.requestPermission();
      return result == LocationPermission.whileInUse ||
          result == LocationPermission.always;
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  // ── Ride lifecycle ────────────────────────────────────

  void startRide({List<RouteStep>? steps, List<Coordinate>? routeCoords}) {
    _totalDistanceM = 0;
    _maxSpeedMs = 0;
    _totalAscentM = 0;
    _smoothedSpeedMs = 0;
    _recordedPath.clear();
    _startTime = DateTime.now();
    _pausedDuration = Duration.zero;
    _lastPosition = null;
    _consecutiveStationaryReadings = 0;
    _status = RideStatus.active;
    _steps = steps;
    _routeCoordinates = routeCoords;
    _currentStepIndex = 0;
    _lastSpokenInstruction = null;
    _emitState();
    _emitInstruction('Ride started — let\'s go! 🚴');
    _speakInstruction('Ride started. Let\'s go!');

    _initTts();

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
      ),
    ).listen(_onPositionUpdate);
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(0.9);
    await _tts.setPitch(1.0);
  }

  void _onPositionUpdate(Position position) {
    if (_status != RideStatus.active) return;
    final rawSpeed = position.speed;
    _smoothedSpeedMs = _speedAlpha * rawSpeed + (1 - _speedAlpha) * _smoothedSpeedMs;

    final coord = Coordinate(
      lat: position.latitude,
      lng: position.longitude,
      elev: position.altitude,
    );

    if (_lastPosition != null && _status == RideStatus.active) {
      final dist = Geolocator.distanceBetween(
        _lastPosition!.latitude, _lastPosition!.longitude,
        position.latitude, position.longitude,
      );

      // Only accumulate distance above drift threshold
      if (dist >= _minDistanceDeltaM) {
        _totalDistanceM += dist;

        // Track max speed (use smoothed for more realistic max)
        if (_smoothedSpeedMs > _maxSpeedMs) _maxSpeedMs = _smoothedSpeedMs;
      }

      // Track ascent — use altitude if available (can be negative, e.g. below sea level)
      final lastAlt = _lastPosition!.altitude;
      final currAlt = position.altitude;
      if (lastAlt != null && currAlt != null) {
        final elevDiff = position.altitude - _lastPosition!.altitude;
        if (elevDiff > 0) _totalAscentM += elevDiff;
      }
    }

    _recordedPath.add(coord);
    _lastPosition = position;

    // ── Multi-factor stationary detection ──
    _checkStationary(position);

    // ── Navigation check ──
    if (_status == RideStatus.active) {
      _checkNavigation(coord);
    }

    _emitState();
    if (!_pathController.isClosed) {
      _pathController.add(List.from(_recordedPath));
    }
  }

  // ── Multi-factor stationary detection ──────────────

  void _checkStationary(Position position) {
    if (_status != RideStatus.active) return;

    // Compute position delta from last reading
    double positionDelta = 0;
    if (_lastPosition != null) {
      positionDelta = Geolocator.distanceBetween(
        _lastPosition!.latitude, _lastPosition!.longitude,
        position.latitude, position.longitude,
      );
    }

    // Stationary if: smoothed speed is low AND position barely changed
    final isStationary = _smoothedSpeedMs < _stationarySpeedMs &&
        positionDelta < _stationaryDeltaM;

    if (isStationary) {
      _consecutiveStationaryReadings++;

      if (_consecutiveStationaryReadings >= _stationaryReadingsToPause) {
        _autoPause();
      }
    } else {
      _consecutiveStationaryReadings = 0;
    }
  }

  void _autoPause() {
    if (_status != RideStatus.active) return;
    _status = RideStatus.paused;
    _pauseStart = DateTime.now();
    _positionSubscription?.cancel();
    _smoothedSpeedMs = 0;
    _emitInstruction('⏸ Auto-paused — you\'ve stopped moving');
    _speakInstruction('Auto paused. You have stopped moving.');
    _emitState();
  }

  void togglePause() {
    if (_status == RideStatus.active) {
      // Manual pause
      _status = RideStatus.paused;
      _pauseStart = DateTime.now();
      _positionSubscription?.cancel();
      _smoothedSpeedMs = 0;
      _emitInstruction('⏸ Paused');
      _emitState();
    } else if (_status == RideStatus.paused) {
      // Manual resume
      _status = RideStatus.active;
      if (_pauseStart != null) {
        _pausedDuration += DateTime.now().difference(_pauseStart!);
      }
      _consecutiveStationaryReadings = 0;
      _smoothedSpeedMs = 0;  // reset filter on resume
      _emitInstruction('▶ Resumed');
      _speakInstruction('Resumed.');
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 1,
        ),
      ).listen(_onPositionUpdate);
    }
    _emitState();
  }

  // ── Navigation + TTS ──────────────────────────────────

  void _checkNavigation(Coordinate currentPos) {
    if (_steps == null || _steps!.isEmpty || _routeCoordinates == null) return;

    final last = _routeCoordinates!.last;
    final dist = _haversineDistance(currentPos, last);
    if (!_remainingDistController.isClosed) {
      _remainingDistController.add(dist / 1000);
    }

    for (var i = _currentStepIndex; i < _steps!.length; i++) {
      final stepCoord = _getStepCoordinate(i);
      if (stepCoord == null) continue;
      final d = _haversineDistance(currentPos, stepCoord);

      if (d < 50 && i == _currentStepIndex) {
        final instruction = '${_steps![i].instruction} in 50 meters';
        _emitInstruction(instruction);
        _speakInstruction(instruction);
        _currentStepIndex = i + 1;
        break;
      }
      if (d < 15 && i <= _currentStepIndex + 1) {
        final instruction = _steps![i].instruction;
        _emitInstruction(instruction);
        _speakInstruction(instruction);
        _currentStepIndex = i + 1;
        break;
      }
    }

    if (_currentStepIndex >= _steps!.length) {
      final destDist = _haversineDistance(currentPos, _routeCoordinates!.last);
      if (destDist < 30) {
        _emitInstruction('🏁 You have arrived!');
        _speakInstruction('You have arrived at your destination.');
      }
    }
  }

  Coordinate? _getStepCoordinate(int index) {
    if (_routeCoordinates == null || _routeCoordinates!.isEmpty) return null;
    if (_steps == null || _steps!.isEmpty) return null;
    final ratio = index / _steps!.length;
    final coordIndex = min((ratio * (_routeCoordinates!.length - 1)).round(), _routeCoordinates!.length - 1);
    return _routeCoordinates![coordIndex];
  }

  void _emitInstruction(String text) {
    if (!_instructionController.isClosed) {
      _instructionController.add(text);
    }
  }

  Future<void> _speakInstruction(String text) async {
    if (text == _lastSpokenInstruction) return;
    _lastSpokenInstruction = text;
    await _tts.speak(text);
  }

  // ── Stop ride ─────────────────────────────────────────

  RideRecording stopRide({required CyclingRoute plannedRoute, double? userWeightKg}) {
    _positionSubscription?.cancel();
    _tts.stop();
    _status = RideStatus.idle;

    final recording = RideRecording(
      route: plannedRoute,
      actualDistanceKm: _totalDistanceM / 1000,
      actualDurationSec: elapsed.inSeconds.toDouble(),
      avgSpeedKmh: avgSpeedKmh,
      maxSpeedKmh: maxSpeedKmh,
      recordedPath: List.from(_recordedPath),
      completedAt: DateTime.now(),
    );
    _emitState();
    return recording;
  }

  // ── Helpers ───────────────────────────────────────────

  void _emitState() {
    if (_stateController.isClosed) return;
    _stateController.add(RideState(
      status: _status,
      distanceKm: totalDistanceKm,
      elapsed: elapsed,
      avgSpeedKmh: avgSpeedKmh,
      maxSpeedKmh: maxSpeedKmh,
      currentSpeedKmh: currentSpeedKmh,
      ascentM: totalAscentM,
      caloriesKcal: estimateCalories(),
    ));
  }

  double _haversineDistance(Coordinate a, Coordinate b) {
    const R = 6371000;
    final dLat = _toRad(b.lat - a.lat);
    final dLng = _toRad(b.lng - a.lng);
    final aH = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(a.lat)) * cos(_toRad(b.lat)) * sin(dLng / 2) * sin(dLng / 2);
    return R * 2 * atan2(sqrt(aH), sqrt(1 - aH));
  }

  double _toRad(double deg) => deg * pi / 180;

  void dispose() {
    _positionSubscription?.cancel();
    _tts.stop();
    _stateController.close();
    _pathController.close();
    _instructionController.close();
    _remainingDistController.close();
  }
}

class RideState {
  final RideStatus status;
  final double distanceKm;
  final Duration elapsed;
  final double avgSpeedKmh;
  final double maxSpeedKmh;
  final double currentSpeedKmh;
  final double ascentM;
  final double caloriesKcal;

  const RideState({
    required this.status,
    required this.distanceKm,
    required this.elapsed,
    required this.avgSpeedKmh,
    required this.maxSpeedKmh,
    required this.currentSpeedKmh,
    this.ascentM = 0,
    this.caloriesKcal = 0,
  });
}
