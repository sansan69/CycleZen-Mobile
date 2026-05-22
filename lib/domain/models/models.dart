import 'package:equatable/equatable.dart';

enum RouteFilter {
  fastest('Fastest', 'Direct route, minimal stops'),
  lessTraffic('Less Traffic', 'Avoids highways and busy roads'),
  scenic('Scenic', 'Picturesque roads through parks and waterfronts'),
  villageRoads('Village Roads', 'Quiet backroads and village paths');

  const RouteFilter(this.label, this.description);
  final String label;
  final String description;
}

class User extends Equatable {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final String? phoneNumber;
  final double? weightKg;
  final String provider; // 'google', 'email', 'phone'

  const User({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
    this.phoneNumber,
    this.weightKg,
    this.provider = 'google',
  });

  @override
  List<Object?> get props => [uid, email, displayName, photoUrl, phoneNumber, weightKg, provider];
}

class Coordinate extends Equatable {
  final double lat;
  final double lng;
  final double? elev;

  const Coordinate({required this.lat, required this.lng, this.elev});

  @override
  List<Object?> get props => [lat, lng, elev];
}

class CyclingRoute extends Equatable {
  final String? id;
  final double distanceKm;
  final double estimatedTimeMin;
  final List<Coordinate> coordinates;
  final double? ascentM;
  final List<RouteStep>? steps;
  final String? routeName;

  const CyclingRoute({
    this.id,
    required this.distanceKm,
    required this.estimatedTimeMin,
    required this.coordinates,
    this.ascentM,
    this.steps,
    this.routeName,
  });

  @override
  List<Object?> get props => [id, distanceKm, estimatedTimeMin, ascentM, routeName];
}

class RouteStep extends Equatable {
  final double distanceM;
  final double durationSec;
  final String instruction;
  final String name;

  const RouteStep({
    required this.distanceM,
    required this.durationSec,
    required this.instruction,
    required this.name,
  });

  @override
  List<Object?> get props => [distanceM, durationSec, instruction, name];
}

class RideRecording extends Equatable {
  final String? id;
  final CyclingRoute route;
  final double actualDistanceKm;
  final double actualDurationSec;
  final double avgSpeedKmh;
  final double maxSpeedKmh;
  final List<Coordinate> recordedPath;
  final DateTime completedAt;

  const RideRecording({
    this.id,
    required this.route,
    required this.actualDistanceKm,
    required this.actualDurationSec,
    required this.avgSpeedKmh,
    required this.maxSpeedKmh,
    required this.recordedPath,
    required this.completedAt,
  });

  @override
  List<Object?> get props => [id, actualDistanceKm, actualDurationSec, avgSpeedKmh, maxSpeedKmh, completedAt];
}

enum RouteMode { ai, manual }

enum RideStatus { idle, active, paused }
