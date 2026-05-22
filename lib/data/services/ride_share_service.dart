import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cyclezen/domain/models/models.dart';

/// Generates branded HTML ride summaries and shares them as .html files.
///
/// Recipients can open the file in any browser to see a properly rendered
/// ride report card — not raw HTML text.
class RideShareService {
  /// Share a ride recording as an HTML file.
  /// The file opens as a rendered web page in the receiver's browser.
  static Future<void> shareRide(RideRecording ride) async {
    final html = _buildHtml(ride);
    final name = (ride.route.routeName ?? 'CycleZen_Ride')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name.html');
    await file.writeAsString(html);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: '${ride.route.routeName ?? 'CycleZen Ride'} — ${ride.actualDistanceKm.toStringAsFixed(1)} km',
      text: 'Check out my CycleZen ride!',
    );
  }

  static String _buildHtml(RideRecording ride) {
    final dist = ride.actualDistanceKm.toStringAsFixed(1);
    final durMin = (ride.actualDurationSec / 60).round();
    final durH = durMin ~/ 60;
    final durM = durMin % 60;
    final durStr = durH > 0 ? '${durH}h ${durM}m' : '${durM}m';
    final avgSpd = ride.avgSpeedKmh.toStringAsFixed(1);
    final maxSpd = ride.maxSpeedKmh.toStringAsFixed(1);
    final ascent = (ride.route.ascentM ?? 0).round();
    final cal = (ride.actualDistanceKm * 30 + ascent * 0.15).round();
    final date =
        '${ride.completedAt.day}/${ride.completedAt.month}/${ride.completedAt.year}';
    final time =
        '${ride.completedAt.hour.toString().padLeft(2, '0')}:${ride.completedAt.minute.toString().padLeft(2, '0')}';
    final name = ride.route.routeName ?? 'Cycling Ride';

    // Google Maps link from route center
    final coords = ride.route.coordinates;
    String mapUrl = '';
    if (coords.isNotEmpty) {
      final mid = coords[coords.length ~/ 2];
      mapUrl = 'https://www.google.com/maps?q=${mid.lat},${mid.lng}';
    }

    // Difficulty estimate
    String difficulty;
    ColorPair diffColor;
    if (dist.isEmpty || double.parse(dist) > 100 || ascent > 1000) {
      difficulty = 'Extreme';
      diffColor = const ColorPair('#DC2626', '#FEE2E2');
    } else if (double.parse(dist) > 50 || ascent > 500) {
      difficulty = 'Hard';
      diffColor = const ColorPair('#EA580C', '#FED7AA');
    } else if (double.parse(dist) > 20 || ascent > 100) {
      difficulty = 'Moderate';
      diffColor = const ColorPair('#CA8A04', '#FEF3C7');
    } else {
      difficulty = 'Easy';
      diffColor = const ColorPair('#16A34A', '#DCFCE7');
    }

    return '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$name — CycleZen Ride</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#001214;color:#e2e8f0;padding:20px 12px;min-height:100vh}
.card{max-width:480px;margin:0 auto;background:#011A1C;border-radius:20px;overflow:hidden;border:1px solid rgba(53,151,128,0.15)}
.header{background:linear-gradient(135deg,#02494D,#013235);padding:24px;text-align:center}
.header-icon{font-size:40px;margin-bottom:8px}
.header h1{font-size:22px;color:#ECC382;font-weight:700;margin-bottom:2px}
.header .meta{font-size:13px;color:rgba(202,231,226,0.7);margin-top:4px}
.stats{padding:20px;display:grid;grid-template-columns:1fr 1fr;gap:10px}
.stat{background:rgba(2,73,77,0.3);border-radius:14px;padding:14px 10px;text-align:center;border:1px solid rgba(53,151,128,0.1)}
.stat-value{font-size:24px;font-weight:800;color:#359780;line-height:1.2}
.stat-label{font-size:10px;color:rgba(202,231,226,0.5);text-transform:uppercase;letter-spacing:1px;margin-top:4px}
.badges{padding:0 20px 16px;display:flex;gap:8px;justify-content:center;flex-wrap:wrap}
.badge{display:inline-block;padding:4px 12px;border-radius:20px;font-size:11px;font-weight:600}
.badge-difficulty{background:${diffColor.bg};color:${diffColor.fg}}
.badge-cal{background:rgba(236,195,130,0.12);color:#ECC382}
.map-btn{display:block;margin:0 20px 16px;background:#02494D;color:#CAE7E2;text-align:center;padding:14px;border-radius:14px;text-decoration:none;font-weight:600;font-size:15px;border:1px solid rgba(53,151,128,0.3);transition:background 0.2s}
.footer{padding:16px 20px;text-align:center;border-top:1px solid rgba(53,151,128,0.1);background:rgba(0,0,0,0.2)}
.footer .brand{font-size:13px;color:rgba(202,231,226,0.6)}
.footer .tagline{font-size:10px;color:#359780;letter-spacing:2px;text-transform:uppercase;margin-top:6px}
@media(prefers-color-scheme:light){
  body{background:#F0FDFA;color:#0F172A}
  .card{background:#fff;border-color:rgba(2,73,77,0.15)}
  .header{background:linear-gradient(135deg,#02494D,#013235);color:#fff}
  .stat{background:rgba(2,73,77,0.05);border-color:rgba(2,73,77,0.08)}
  .stat-value{color:#02494D}
  .stat-label{color:rgba(2,73,77,0.5)}
  .map-btn{background:rgba(2,73,77,0.08);color:#02494D;border-color:rgba(2,73,77,0.15)}
  .footer{background:rgba(2,73,77,0.03);border-color:rgba(2,73,77,0.08)}
  .footer .brand{color:rgba(2,73,77,0.6)}
}
</style>
</head>
<body>
<div class="card">
  <div class="header">
    <div class="header-icon">🚴</div>
    <h1>$name</h1>
    <p class="meta">$date at $time</p>
  </div>
  <div class="stats">
    <div class="stat"><div class="stat-value">$dist km</div><div class="stat-label">Distance</div></div>
    <div class="stat"><div class="stat-value">$durStr</div><div class="stat-label">Duration</div></div>
    <div class="stat"><div class="stat-value">$avgSpd</div><div class="stat-label">Avg km/h</div></div>
    <div class="stat"><div class="stat-value">$maxSpd</div><div class="stat-label">Max km/h</div></div>
    <div class="stat"><div class="stat-value">${ascent}m</div><div class="stat-label">Ascent</div></div>
    <div class="stat"><div class="stat-value">$cal</div><div class="stat-label">Kcal</div></div>
  </div>
  <div class="badges">
    <span class="badge badge-difficulty">$difficulty</span>
    <span class="badge badge-cal">~$cal kcal</span>
  </div>
  ${mapUrl.isNotEmpty ? '<a class="map-btn" href="$mapUrl" target="_blank">📍 View Route on Google Maps</a>' : ''}
  <div class="footer">
    <p class="brand">Tracked with CycleZen 🚲</p>
    <p class="tagline">DISCOVER · PLAN · RIDE · SHARE</p>
  </div>
</div>
</body>
</html>''';
  }
}

/// Simple color pair for HTML template strings.
class ColorPair {
  final String fg;
  final String bg;
  const ColorPair(this.fg, this.bg);
}
