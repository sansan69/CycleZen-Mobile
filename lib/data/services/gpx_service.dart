import 'dart:io';
import 'package:cyclezen/domain/models/models.dart';
import 'package:path_provider/path_provider.dart';

class GpxService {
  /// Generate GPX XML string from a CyclingRoute
  static String generateGpx(CyclingRoute route) {
    final time = DateTime.now().toUtc().toIso8601String();
    final name = route.routeName?.isNotEmpty == true ? route.routeName! : 'CycleZen Route';
    final buf = StringBuffer();

    buf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buf.writeln('<gpx version="1.1" creator="CycleZen"');
    buf.writeln('  xmlns="http://www.topografix.com/GPX/1/1"');
    buf.writeln('  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"');
    buf.writeln('  xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">');
    buf.writeln('  <metadata>');
    buf.writeln('    <name>$name</name>');
    buf.writeln('    <time>$time</time>');
    buf.writeln('  </metadata>');

    if (route.coordinates.isNotEmpty) {
      buf.writeln('  <trk>');
      buf.writeln('    <name>$name</name>');
      buf.writeln('    <trkseg>');
      for (final coord in route.coordinates) {
        buf.write('      <trkpt lat="${coord.lat}" lon="${coord.lng}"');
        if (coord.elev != null) {
          buf.write('>');
          buf.writeln();
          buf.writeln('        <ele>${coord.elev!.toStringAsFixed(1)}</ele>');
          buf.writeln('      </trkpt>');
        } else {
          buf.writeln(' />');
        }
      }
      buf.writeln('    </trkseg>');
      buf.writeln('  </trk>');
    }

    buf.writeln('</gpx>');
    return buf.toString();
  }

  /// Generate GPX from a RideRecording including actual path
  static String generateGpxFromRide(RideRecording ride) {
    final time = ride.completedAt.toUtc().toIso8601String();
    final routeName = ride.route.routeName;
    final name = routeName?.isNotEmpty == true ? routeName! : 'CycleZen Ride';
    final buf = StringBuffer();

    buf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buf.writeln('<gpx version="1.1" creator="CycleZen"');
    buf.writeln('  xmlns="http://www.topografix.com/GPX/1/1"');
    buf.writeln('  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"');
    buf.writeln('  xsi:schemaLocation="http://www.topografix.com/GPX/1/1 http://www.topografix.com/GPX/1/1/gpx.xsd">');
    buf.writeln('  <metadata>');
    buf.writeln('    <name>$name</name>');
    buf.writeln('    <time>$time</time>');
    buf.writeln('  </metadata>');

    if (ride.recordedPath.isNotEmpty) {
      buf.writeln('  <trk>');
      buf.writeln('    <name>$name</name>');
      buf.writeln('    <trkseg>');
      for (final coord in ride.recordedPath) {
        buf.write('      <trkpt lat="${coord.lat}" lon="${coord.lng}"');
        if (coord.elev != null) {
          buf.write('>');
          buf.writeln();
          buf.writeln('        <ele>${coord.elev!.toStringAsFixed(1)}</ele>');
          buf.writeln('      </trkpt>');
        } else {
          buf.writeln(' />');
        }
      }
      buf.writeln('    </trkseg>');
      buf.writeln('  </trk>');
    }

    buf.writeln('</gpx>');
    return buf.toString();
  }

  /// Save GPX to a temporary file and return the file path
  static Future<File> exportToFile(CyclingRoute route) async {
    final gpx = generateGpx(route);
    final dir = await getTemporaryDirectory();
    final safeName = (route.routeName ?? '').replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    final filename = safeName.isNotEmpty
        ? '${safeName.replaceAll(' ', '_')}.gpx'
        : 'route_${DateTime.now().millisecondsSinceEpoch}.gpx';
    final file = File('${dir.path}/$filename');
    await file.writeAsString(gpx);
    return file;
  }

  /// Save GPX from RideRecording to a temporary file
  static Future<File> exportRideToFile(RideRecording ride) async {
    final gpx = generateGpxFromRide(ride);
    final dir = await getTemporaryDirectory();
    final safeName = (ride.route.routeName ?? '').replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    final filename = safeName.isNotEmpty
        ? '${safeName.replaceAll(' ', '_')}.gpx'
        : 'ride_${DateTime.now().millisecondsSinceEpoch}.gpx';
    final file = File('${dir.path}/$filename');
    await file.writeAsString(gpx);
    return file;
  }
}
