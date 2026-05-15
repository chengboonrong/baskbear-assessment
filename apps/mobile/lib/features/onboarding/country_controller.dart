import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/storage/preferences.dart';

/// User's current country + locale selection. Persists to SharedPreferences
/// across app launches. Sourced from onboarding initially; mutable later via
/// the account screen's country switcher.
class CountrySelection {
  const CountrySelection({required this.countryCode, required this.localeCode});
  final String countryCode;
  final String localeCode;

  CountrySelection copyWith({String? countryCode, String? localeCode}) =>
      CountrySelection(
        countryCode: countryCode ?? this.countryCode,
        localeCode: localeCode ?? this.localeCode,
      );

  /// Sensible default — matches API's DEFAULT_COUNTRY_CODE.
  static const initial = CountrySelection(countryCode: 'MY', localeCode: 'en');
}

class CountryController extends Notifier<CountrySelection> {
  SharedPreferences? _prefs;

  @override
  CountrySelection build() {
    // Hydrate asynchronously; UI shows defaults until ready.
    Future.microtask(_load);
    return CountrySelection.initial;
  }

  Future<void> _load() async {
    final prefs = await ref.read(preferencesProvider.future);
    _prefs = prefs;
    final country = prefs.getString(PrefsKeys.country);
    final locale = prefs.getString(PrefsKeys.locale);
    if (country != null && locale != null) {
      state = CountrySelection(countryCode: country, localeCode: locale);
    }
  }

  Future<void> setCountry(String code, {String? locale}) async {
    final next = state.copyWith(countryCode: code, localeCode: locale);
    state = next;
    final prefs = await ref.read(preferencesProvider.future);
    _prefs = prefs;
    await prefs.setString(PrefsKeys.country, next.countryCode);
    await prefs.setString(PrefsKeys.locale, next.localeCode);
    await prefs.setBool(PrefsKeys.onboarded, true);
  }
}

final countrySelectionProvider =
    NotifierProvider<CountryController, CountrySelection>(CountryController.new);

/// True once the user has picked a country at least once.
final onboardedProvider = FutureProvider<bool>((ref) async {
  final prefs = await ref.watch(preferencesProvider.future);
  return prefs.getBool(PrefsKeys.onboarded) ?? false;
});
