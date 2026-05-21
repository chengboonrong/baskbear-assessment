import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/env.dart';
import '../../core/location/location_service.dart';
import '../../core/storage/preferences.dart';
import '../../data/models/country.dart';
import '../../data/repositories/countries_repository.dart';

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

  /// Pre-onboarding fallback. Driven by the mobile .env (DEFAULT_COUNTRY /
  /// DEFAULT_LOCALE) so the app can be re-pointed at a different primary
  /// country without code changes. AppEnv.defaultCountry falls back to 'MY'
  /// when the env is missing (e.g. inside flutter_test).
  static CountrySelection get initial =>
      CountrySelection(countryCode: AppEnv.defaultCountry, localeCode: AppEnv.defaultLocale);
}

class CountryController extends Notifier<CountrySelection> {
  @override
  CountrySelection build() {
    // Hydrate asynchronously; UI shows defaults until ready.
    Future.microtask(_load);
    return CountrySelection.initial;
  }

  Future<void> _load() async {
    final prefs = await ref.read(preferencesProvider.future);
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

/// Full country DTO (currency, tax rate, timezone, …) for the currently
/// selected country. Null until [countriesListProvider] resolves — UI should
/// hide country-dependent figures (tax preview, currency labels) until then.
/// Falls back to the first country in the API response if the persisted code
/// no longer exists (e.g. a country was retired server-side).
final currentCountryProvider = Provider<CountryDto?>((ref) {
  final selection = ref.watch(countrySelectionProvider);
  final list = ref.watch(countriesListProvider).asData?.value;
  if (list == null || list.isEmpty) return null;
  for (final c in list) {
    if (c.code == selection.countryCode) return c;
  }
  return list.first;
});

/// Maps a device-detected region onto a *supported* country + locale.
///
/// Returns null when the detected country isn't one we operate in (or nothing
/// was detected) — the caller then shows the manual picker. Locale prefers the
/// device language when the country supports it, otherwise the country default.
/// Matching is case-insensitive on both the country and language codes.
CountrySelection? resolveCountrySelection(
  List<CountryDto> countries,
  DetectedRegion region,
) {
  final detectedCountry = region.countryCode?.toUpperCase();
  if (detectedCountry == null) return null;

  for (final country in countries) {
    if (country.code.toUpperCase() != detectedCountry) continue;

    final supported = country.locales.map((l) => l.code.toLowerCase()).toSet();
    final language = region.languageCode?.toLowerCase();
    final locale = (language != null && supported.contains(language))
        ? language
        : country.defaultLocale;
    return CountrySelection(countryCode: country.code, localeCode: locale);
  }
  return null;
}

/// Best-effort device-region detection (GPS → device settings). Runs once per
/// onboarding attempt; disposed when onboarding leaves the tree.
final detectedRegionProvider =
    FutureProvider.autoDispose<DetectedRegion>((ref) {
  return ref.watch(locationServiceProvider).detect();
});

/// The auto-detected selection resolved against the live country list, or null
/// when detection produced no supported country (=> show the manual picker).
final autoSelectionProvider =
    FutureProvider.autoDispose<CountrySelection?>((ref) async {
  final countries = await ref.watch(countriesListProvider.future);
  final region = await ref.watch(detectedRegionProvider.future);
  return resolveCountrySelection(countries, region);
});
