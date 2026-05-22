import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cyclezen/domain/models/models.dart';

/// Free weather service via Open-Meteo API (no key required).
/// Returns current conditions and forecast for cycling-relevant metrics.
class WeatherService {
  static const _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  /// Fetch current weather + 1-day forecast for a coordinate.
  Future<WeatherData?> getWeather(Coordinate coord) async {
    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'latitude': coord.lat.toString(),
        'longitude': coord.lng.toString(),
        'current': 'temperature_2m,relative_humidity_2m,wind_speed_10m,wind_direction_10m,weather_code',
        'hourly': 'temperature_2m,precipitation_probability,wind_speed_10m',
        'forecast_days': '1',
        'timezone': 'auto',
      });
      final resp = await http.get(uri).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) return null;
      final data = json.decode(resp.body);
      return WeatherData(
        temperature: (data['current']['temperature_2m'] as num).toDouble(),
        humidity: (data['current']['relative_humidity_2m'] as num).toDouble(),
        windSpeed: (data['current']['wind_speed_10m'] as num).toDouble(),
        windDirection: (data['current']['wind_direction_10m'] as num).toDouble(),
        weatherCode: data['current']['weather_code'] as int,
      );
    } catch (_) {
      return null;
    }
  }
}

class WeatherData {
  final double temperature;   // °C
  final double humidity;      // %
  final double windSpeed;     // km/h
  final double windDirection; // degrees
  final int weatherCode;      // WMO code

  const WeatherData({
    required this.temperature,
    required this.humidity,
    required this.windSpeed,
    required this.windDirection,
    required this.weatherCode,
  });

  String get weatherIcon {
    if (weatherCode <= 1) return '☀️';
    if (weatherCode <= 3) return '⛅';
    if (weatherCode <= 48) return '☁️';
    if (weatherCode <= 57) return '🌧️';
    if (weatherCode <= 67) return '🌧️';
    if (weatherCode <= 77) return '❄️';
    if (weatherCode <= 82) return '🌧️';
    if (weatherCode <= 86) return '❄️';
    if (weatherCode <= 99) return '⛈️';
    return '🌤️';
  }

  String get conditions {
    if (weatherCode <= 1) return 'Clear';
    if (weatherCode <= 3) return 'Partly cloudy';
    if (weatherCode <= 48) return 'Cloudy';
    if (weatherCode <= 57) return 'Drizzle';
    if (weatherCode <= 67) return 'Rain';
    if (weatherCode <= 77) return 'Snow';
    if (weatherCode <= 82) return 'Heavy rain';
    if (weatherCode <= 86) return 'Heavy snow';
    if (weatherCode <= 99) return 'Thunderstorm';
    return 'Unknown';
  }

  String get cyclingAdvice {
    if (weatherCode >= 95) return '⚠️ Thunderstorm — unsafe to ride';
    if (weatherCode >= 80) return '⚠️ Heavy rain — ride with caution';
    if (windSpeed > 40) return '💨 Strong wind — headwind sections may be tough';
    if (windSpeed > 25) return '🌬️ Breezy — check wind direction';
    if (temperature > 35) return '🥵 Very hot — hydrate well';
    if (temperature < 5) return '🥶 Cold — wear layers';
    return '✅ Great cycling weather!';
  }
}
