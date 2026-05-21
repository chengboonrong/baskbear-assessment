import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/onboarding/country_controller.dart';

/// Coarse weather categories, mapped from WMO weather codes.
enum WeatherKind { clear, cloudy, fog, rain, snow, thunder, unknown }

/// Current weather for the user's country, used to bias drink recommendations.
class Weather {
  const Weather({required this.tempC, required this.kind, required this.city});

  final double tempC;
  final WeatherKind kind;
  final String city;

  bool get isHot => tempC >= 28;
  bool get isCold => tempC <= 18;
  bool get isWet =>
      kind == WeatherKind.rain ||
      kind == WeatherKind.thunder ||
      kind == WeatherKind.snow;

  /// Lowercase adjective, e.g. 'rainy' — for natural-language replies.
  String get descriptor => switch (kind) {
        WeatherKind.clear => 'sunny',
        WeatherKind.cloudy => 'cloudy',
        WeatherKind.fog => 'foggy',
        WeatherKind.rain => 'rainy',
        WeatherKind.snow => 'snowy',
        WeatherKind.thunder => 'stormy',
        WeatherKind.unknown => 'mild',
      };

  String get emoji => switch (kind) {
        WeatherKind.clear => '☀️',
        WeatherKind.cloudy => '☁️',
        WeatherKind.fog => '🌫️',
        WeatherKind.rain => '🌧️',
        WeatherKind.snow => '❄️',
        WeatherKind.thunder => '⛈️',
        WeatherKind.unknown => '🌡️',
      };

  /// e.g. "Rainy · 24°C · Bangkok"
  String get label =>
      '${descriptor[0].toUpperCase()}${descriptor.substring(1)} · ${tempC.round()}°C · $city';
}

/// Map a WMO weather code (Open-Meteo `weather_code`) to a [WeatherKind].
/// https://open-meteo.com/en/docs — codes are grouped, not contiguous.
WeatherKind kindFromWmoCode(int code) {
  if (code == 0) return WeatherKind.clear;
  if (code <= 3) return WeatherKind.cloudy; // 1,2,3 mainly clear→overcast
  if (code == 45 || code == 48) return WeatherKind.fog;
  if (code >= 51 && code <= 67) return WeatherKind.rain; // drizzle/rain/freezing
  if (code >= 71 && code <= 77) return WeatherKind.snow;
  if (code >= 80 && code <= 82) return WeatherKind.rain; // rain showers
  if (code >= 85 && code <= 86) return WeatherKind.snow; // snow showers
  if (code >= 95) return WeatherKind.thunder; // 95,96,99
  return WeatherKind.unknown;
}

/// Fetches current weather from the keyless Open-Meteo API for a country's
/// representative city — no GPS permission, always resolves on emulators.
class WeatherService {
  WeatherService([Dio? dio])
      : _dio = dio ??
            Dio(BaseOptions(
              connectTimeout: const Duration(seconds: 6),
              receiveTimeout: const Duration(seconds: 6),
            ));

  final Dio _dio;

  // One representative city per operating country. Adding a country to the menu
  // (README §4 Q8) only needs an entry here to get weather-aware suggestions.
  static const Map<String, ({double lat, double lon, String city})> _cities = {
    'MY': (lat: 3.1390, lon: 101.6869, city: 'Kuala Lumpur'),
    'TH': (lat: 13.7563, lon: 100.5018, city: 'Bangkok'),
    'SG': (lat: 1.3521, lon: 103.8198, city: 'Singapore'),
    'ID': (lat: -6.2088, lon: 106.8456, city: 'Jakarta'),
  };

  /// Best-effort: returns null for unknown countries or any network failure, so
  /// the Barista simply omits weather rather than erroring.
  Future<Weather?> forCountry(String countryCode) async {
    final loc = _cities[countryCode.toUpperCase()];
    if (loc == null) return null;
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        'https://api.open-meteo.com/v1/forecast',
        queryParameters: {
          'latitude': loc.lat,
          'longitude': loc.lon,
          'current': 'temperature_2m,weather_code',
        },
      );
      final current = res.data?['current'] as Map<String, dynamic>?;
      if (current == null) return null;
      return Weather(
        tempC: (current['temperature_2m'] as num).toDouble(),
        kind: kindFromWmoCode((current['weather_code'] as num).toInt()),
        city: loc.city,
      );
    } catch (_) {
      return null;
    }
  }
}

final weatherServiceProvider = Provider<WeatherService>((_) => WeatherService());

/// Current weather for the selected country. Refetches when the country changes.
final currentWeatherProvider = FutureProvider.autoDispose<Weather?>((ref) async {
  final country = ref.watch(countrySelectionProvider).countryCode;
  return ref.read(weatherServiceProvider).forCountry(country);
});
