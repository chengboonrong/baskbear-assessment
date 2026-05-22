import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/http/api_client.dart';
import '../../features/onboarding/country_controller.dart';
import '../models/country.dart';
import '../models/outlet.dart';

class CountriesRepository {
  CountriesRepository(this._api);
  final ApiClient _api;

  Future<List<CountryDto>> list() async {
    final res = await _api.dio.get<List<dynamic>>('/v1/countries');
    return (res.data ?? const [])
        .map((e) => CountryDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<OutletDto>> outlets(String countryCode) async {
    final res = await _api.dio.get<List<dynamic>>(
      '/v1/countries/outlets',
      queryParameters: {'country': countryCode},
    );
    return (res.data ?? const [])
        .map((e) => OutletDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, bool>> featureFlags(String countryCode) async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      '/v1/countries/feature-flags',
      queryParameters: {'country': countryCode},
    );
    return (res.data ?? const {}).map((k, v) => MapEntry(k, v as bool));
  }
}

final countriesRepositoryProvider = Provider<CountriesRepository>((ref) {
  return CountriesRepository(ref.watch(apiClientProvider));
});

final countriesListProvider = FutureProvider.autoDispose<List<CountryDto>>((ref) async {
  return ref.watch(countriesRepositoryProvider).list();
});

/// Outlets for the currently selected country. Re-fetches when the country
/// changes (the picker only ever offers outlets in the active country).
final outletsProvider = FutureProvider.autoDispose<List<OutletDto>>((ref) async {
  final code = ref.watch(countrySelectionProvider).countryCode;
  return ref.watch(countriesRepositoryProvider).outlets(code);
});
