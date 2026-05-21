import 'package:baskbear/core/location/location_service.dart';
import 'package:baskbear/data/models/country.dart';
import 'package:baskbear/features/onboarding/country_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final countries = [
    CountryDto(
      code: 'MY',
      name: 'Malaysia',
      currencyCode: 'MYR',
      taxRateBps: 600,
      timezone: 'Asia/Kuala_Lumpur',
      defaultLocale: 'en',
      locales: [
        LocaleDto(code: 'en', isDefault: true),
        LocaleDto(code: 'ms', isDefault: false),
      ],
    ),
    CountryDto(
      code: 'TH',
      name: 'Thailand',
      currencyCode: 'THB',
      taxRateBps: 700,
      timezone: 'Asia/Bangkok',
      defaultLocale: 'th',
      locales: [
        LocaleDto(code: 'en', isDefault: false),
        LocaleDto(code: 'th', isDefault: true),
      ],
    ),
  ];

  group('resolveCountrySelection', () {
    test('matches the detected country and keeps a supported device language', () {
      final sel = resolveCountrySelection(
        countries,
        const DetectedRegion(countryCode: 'MY', languageCode: 'ms'),
      );
      expect(sel?.countryCode, 'MY');
      expect(sel?.localeCode, 'ms');
    });

    test('falls back to the country default when the device language is unsupported', () {
      final sel = resolveCountrySelection(
        countries,
        const DetectedRegion(countryCode: 'TH', languageCode: 'fr'),
      );
      expect(sel?.countryCode, 'TH');
      expect(sel?.localeCode, 'th');
    });

    test('matches case-insensitively on country and language codes', () {
      final sel = resolveCountrySelection(
        countries,
        const DetectedRegion(countryCode: 'my', languageCode: 'EN'),
      );
      expect(sel?.countryCode, 'MY');
      expect(sel?.localeCode, 'en');
    });

    test('returns null for a country we do not operate in', () {
      final sel = resolveCountrySelection(
        countries,
        const DetectedRegion(countryCode: 'US', languageCode: 'en'),
      );
      expect(sel, isNull);
    });

    test('returns null when nothing was detected', () {
      final sel = resolveCountrySelection(countries, const DetectedRegion());
      expect(sel, isNull);
    });
  });
}
