import 'dart:math';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:cyclezen/domain/models/models.dart';

/// Navigation service provides turn-by-turn voice guidance.
/// Monitors current position against upcoming maneuvers and speaks instructions.
class NavigationService {
  final FlutterTts _tts = FlutterTts();
  int _currentStepIndex = 0;
  List<RouteStep> _steps = [];
  List<Coordinate> _routeCoordinates = [];
  bool _isActive = false;

  bool get isActive => _isActive;

  Future<void> initialize() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  /// Start navigation with route data
  void startNavigation({
    required List<RouteStep> steps,
    required List<Coordinate> coordinates,
  }) {
    _steps = steps;
    _routeCoordinates = coordinates;
    _currentStepIndex = 0;
    _isActive = true;

    if (_steps.isNotEmpty) {
      speak('Starting navigation. ${_steps.first.instruction}');
    }
  }

  /// Update position and check for upcoming maneuvers
  void updatePosition(Coordinate currentPosition) {
    if (!_isActive || _steps.isEmpty) return;

    // Find the nearest upcoming step
    for (var i = _currentStepIndex; i < _steps.length; i++) {
      final stepCoord = _getStepCoordinate(i);
      if (stepCoord == null) continue;

      final distance = _haversineDistance(currentPosition, stepCoord);

      // Alert at 50m and 15m before turn
      if (distance < 50 && i == _currentStepIndex) {
        speak('${_steps[i].instruction} in 50 meters');
        _currentStepIndex = i + 1;
        break;
      }

      // Final turn instruction
      if (distance < 15 && i <= _currentStepIndex + 1) {
        speak(_steps[i].instruction);
        _currentStepIndex = i + 1;
        break;
      }
    }

    // Check if we've reached the destination
    if (_currentStepIndex >= _steps.length && _routeCoordinates.isNotEmpty) {
      final destDist = _haversineDistance(
        currentPosition,
        _routeCoordinates.last,
      );
      if (destDist < 30) {
        speak('You have arrived at your destination.');
        stopNavigation();
      }
    }
  }

  Coordinate? _getStepCoordinate(int index) {
    if (_routeCoordinates.isEmpty || _steps.isEmpty) return null;
    final ratio = index / _steps.length;
    final coordIndex = min((ratio * (_routeCoordinates.length - 1)).round(), _routeCoordinates.length - 1);
    return _routeCoordinates[coordIndex];
  }

  Future<void> speak(String text) async {
    await _tts.speak(text);
  }

  void stopNavigation() {
    _isActive = false;
    _tts.stop();
    _steps = [];
    _routeCoordinates = [];
    _currentStepIndex = 0;
  }

  /// Haversine distance in meters
  double _haversineDistance(Coordinate a, Coordinate b) {
    const R = 6371000;
    final dLat = _toRad(b.lat - a.lat);
    final dLng = _toRad(b.lng - a.lng);
    final aH = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(a.lat)) * cos(_toRad(b.lat)) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(aH), sqrt(1 - aH));
    return R * c;
  }

  double _toRad(double deg) => deg * pi / 180;

  void dispose() {
    stopNavigation();
  }
}
