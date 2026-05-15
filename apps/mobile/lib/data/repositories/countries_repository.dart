import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/http/api_client.dart';
import '../models/country.dart';

class CountriesRepository {
  CountriesRepository(this._api);
  final ApiClient _api;

  Future<List<CountryDto>> list() async {
    final res = await _api.dio.get<List<dynamic>>('/v1/countries');
    return (res.data ?? const [])
        .map((e) => CountryDto.fromJson(e as Map<String, dynamic>))
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
