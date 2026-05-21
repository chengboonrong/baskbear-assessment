import 'package:flutter_test/flutter_test.dart';
import 'package:baskbear/core/weather/weather_service.dart';
import 'package:baskbear/features/ai_barista/mood.dart';

void main() {
  group('kindFromWmoCode', () {
    test('maps representative WMO codes', () {
      expect(kindFromWmoCode(0), WeatherKind.clear);
      expect(kindFromWmoCode(2), WeatherKind.cloudy);
      expect(kindFromWmoCode(48), WeatherKind.fog);
      expect(kindFromWmoCode(61), WeatherKind.rain);
      expect(kindFromWmoCode(81), WeatherKind.rain);
      expect(kindFromWmoCode(73), WeatherKind.snow);
      expect(kindFromWmoCode(95), WeatherKind.thunder);
    });
  });

  group('Weather flags', () {
    test('hot / cold / wet derive from temp and kind', () {
      const hot = Weather(tempC: 32, kind: WeatherKind.clear, city: 'KL');
      const cold = Weather(tempC: 12, kind: WeatherKind.cloudy, city: 'KL');
      const wet = Weather(tempC: 24, kind: WeatherKind.rain, city: 'Bangkok');
      expect(hot.isHot, isTrue);
      expect(cold.isCold, isTrue);
      expect(wet.isWet, isTrue);
      expect(hot.isWet, isFalse);
    });
  });

  group('composeQuery', () {
    test('folds in mood and weather keywords', () {
      const wet = Weather(tempC: 22, kind: WeatherKind.rain, city: 'Bangkok');
      final q = composeQuery('something nice', Mood.cosy, wet);
      expect(q, contains('something nice'));
      expect(q, contains('latte')); // from cosy mood
      expect(q, contains('warm')); // from wet weather
    });

    test('works with empty text (mood-only)', () {
      const hot = Weather(tempC: 30, kind: WeatherKind.clear, city: 'Singapore');
      final q = composeQuery('', Mood.boost, hot);
      expect(q, contains('espresso')); // boost
      expect(q, contains('iced')); // hot weather
      expect(q.trim(), isNotEmpty);
    });
  });

  group('natural-language context', () {
    test('naturalPreface combines weather and mood', () {
      const wet = Weather(tempC: 23, kind: WeatherKind.rain, city: 'Bangkok');
      final p = naturalPreface(Mood.cosy, wet);
      expect(p, startsWith('Since '));
      expect(p, contains('rainy'));
      expect(p, contains('cosy'));
      expect(p, endsWith(', '));
    });

    test('naturalPreface is empty without signals', () {
      expect(naturalPreface(null, null), isEmpty);
    });

    test('llmContextLine summarises for the prompt', () {
      const hot = Weather(tempC: 31, kind: WeatherKind.clear, city: 'KL');
      final line = llmContextLine(Mood.boost, hot);
      expect(line, startsWith('Context:'));
      expect(line, contains('31°C'));
      expect(line, contains('energy boost'));
    });
  });
}
