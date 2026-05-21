import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// What we could infer about the user's region. Either field may be null when
/// detection was inconclusive — callers then fall back to the manual picker.
class DetectedRegion {
  const DetectedRegion({this.countryCode, this.languageCode});

  /// ISO 3166-1 alpha-2 (e.g. 'MY'), or null when undetermined.
  final String? countryCode;

  /// ISO 639-1 language code (e.g. 'en'), or null when undetermined.
  final String? languageCode;
}

/// Resolves the user's country/locale from the device on first launch.
///
/// Strategy: try GPS + reverse-geocoding for the *physical* country, then fall
/// back to the device's configured region. The device language is always read
/// (no permission needed) and is used later to pick a locale within the country.
///
/// Reverse-geocoding has no web implementation, so on web we skip straight to
/// the device-region fallback. GPS failures (permission denied, location off,
/// timeout) also fall through — detection is best-effort and never fatal.
class LocationService {
  const LocationService();

  Future<DetectedRegion> detect() async {
    final language = _deviceLanguage();

    if (!kIsWeb) {
      try {
        // Hard 10s cap on the *whole* GPS attempt — the permission prompt and
        // reverse-geocoding have no timeout of their own, so without this the
        // "Finding your location…" screen can hang well past the inner
        // getCurrentPosition limit. On timeout we fall through to the instant,
        // permission-free device-region fallback.
        final iso =
            await _countryFromGps().timeout(const Duration(seconds: 10));
        if (iso != null) {
          return DetectedRegion(countryCode: iso, languageCode: language);
        }
      } catch (_) {
        // denied / disabled / timed out — fall through to the fallback
      }
    }

    return DetectedRegion(countryCode: _deviceCountry(), languageCode: language);
  }

  Future<String?> _countryFromGps() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    // Country resolution doesn't need precision; low accuracy is faster and
    // easier on the battery.
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
    ).timeout(const Duration(seconds: 10));

    final placemarks =
        await placemarkFromCoordinates(position.latitude, position.longitude);
    if (placemarks.isEmpty) return null;
    final code = placemarks.first.isoCountryCode;
    return (code == null || code.isEmpty) ? null : code.toUpperCase();
  }

  String? _deviceCountry() {
    final code = ui.PlatformDispatcher.instance.locale.countryCode;
    return (code == null || code.isEmpty) ? null : code.toUpperCase();
  }

  String _deviceLanguage() =>
      ui.PlatformDispatcher.instance.locale.languageCode.toLowerCase();
}

final locationServiceProvider =
    Provider<LocationService>((ref) => const LocationService());
