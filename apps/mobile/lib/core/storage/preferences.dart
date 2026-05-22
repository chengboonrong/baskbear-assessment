import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Async provider over SharedPreferences. Used for non-secret user prefs:
/// selected country, locale, "onboarded?" flag.
final preferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return SharedPreferences.getInstance();
});

class PrefsKeys {
  static const country = 'pref.country';
  static const locale = 'pref.locale';
  static const onboarded = 'pref.onboarded';

  /// Selected outlet is stored per-country: `pref.outlet.<COUNTRY>`. Switching
  /// country naturally yields that country's own (or no) outlet.
  static String outlet(String countryCode) => 'pref.outlet.$countryCode';
}
