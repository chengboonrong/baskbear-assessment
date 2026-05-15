class CountryDto {
  CountryDto({
    required this.code, required this.name, required this.currencyCode,
    required this.taxRateBps, required this.timezone, required this.defaultLocale,
    required this.locales,
  });

  final String code;
  final String name;
  final String currencyCode;
  final int taxRateBps;
  final String timezone;
  final String defaultLocale;
  final List<LocaleDto> locales;

  factory CountryDto.fromJson(Map<String, dynamic> j) => CountryDto(
        code: j['code'] as String,
        name: j['name'] as String,
        currencyCode: j['currencyCode'] as String,
        taxRateBps: (j['taxRateBps'] as num).toInt(),
        timezone: j['timezone'] as String,
        defaultLocale: j['defaultLocale'] as String,
        locales: (j['locales'] as List<dynamic>)
            .map((e) => LocaleDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class LocaleDto {
  LocaleDto({required this.code, required this.isDefault});
  final String code;
  final bool isDefault;
  factory LocaleDto.fromJson(Map<String, dynamic> j) =>
      LocaleDto(code: j['code'] as String, isDefault: j['isDefault'] as bool);
}
