import '../../core/weather/weather_service.dart';

/// Quick-pick moods shown as chips in the Barista. Each maps to fallback search
/// keywords and a natural phrase the LLM prompt can use.
enum Mood { boost, relax, focus, treat, cosy }

extension MoodX on Mood {
  String get label => switch (this) {
        Mood.boost => 'Boost',
        Mood.relax => 'Relax',
        Mood.focus => 'Focus',
        Mood.treat => 'Treat',
        Mood.cosy => 'Cosy',
      };

  String get emoji => switch (this) {
        Mood.boost => '⚡',
        Mood.relax => '😌',
        Mood.focus => '🎯',
        Mood.treat => '🍰',
        Mood.cosy => '☕',
      };

  /// Keywords folded into the offline recommender's query.
  List<String> get keywords => switch (this) {
        Mood.boost => ['espresso', 'strong', 'bold', 'americano', 'cold brew', 'double'],
        Mood.relax => ['tea', 'chamomile', 'decaf', 'latte', 'herbal', 'soothing'],
        Mood.focus => ['espresso', 'americano', 'black', 'strong', 'long black'],
        Mood.treat => ['caramel', 'mocha', 'chocolate', 'frappe', 'sweet', 'vanilla', 'whipped'],
        Mood.cosy => ['hot', 'latte', 'vanilla', 'honey', 'chai', 'warm', 'cinnamon'],
      };

  /// Third-person phrase for the LLM prompt ("the customer …").
  String get phrase => switch (this) {
        Mood.boost => 'wants an energy boost',
        Mood.relax => 'wants to relax and unwind',
        Mood.focus => 'needs to focus',
        Mood.treat => 'wants to treat themselves',
        Mood.cosy => 'wants something warm and cosy',
      };

  /// Second-person phrase for the friendly fallback reply ("you …").
  String get youPhrase => switch (this) {
        Mood.boost => 'want a boost',
        Mood.relax => 'want to relax',
        Mood.focus => 'need to focus',
        Mood.treat => 'fancy a treat',
        Mood.cosy => 'want something cosy',
      };
}

/// Extra search keywords implied by the weather (hot → iced, cold/wet → warm).
List<String> _weatherKeywords(Weather? w) {
  if (w == null) return const [];
  final kws = <String>[];
  if (w.isHot) {
    kws.addAll(['iced', 'cold', 'refreshing']);
  } else if (w.isCold) {
    kws.addAll(['hot', 'warm']);
  }
  if (w.isWet) kws.addAll(['hot', 'warm', 'comforting']);
  return kws;
}

/// Combine the typed text with mood + weather keywords for the offline path.
String composeQuery(String text, Mood? mood, Weather? weather) {
  final parts = <String>[
    text,
    ...?mood?.keywords,
    ..._weatherKeywords(weather),
  ];
  return parts.where((p) => p.trim().isNotEmpty).join(' ').trim();
}

/// "Context: …" line prepended to the LLM prompt so Gemma factors in the moment.
String llmContextLine(Mood? mood, Weather? weather) {
  final parts = <String>[];
  if (weather != null) {
    parts.add("it's ${weather.descriptor} and about ${weather.tempC.round()}°C");
  }
  if (mood != null) parts.add('the customer ${mood.phrase}');
  return parts.isEmpty ? '' : 'Context: ${parts.join('; ')}.';
}

/// Natural lead-in for the offline reply, e.g. "Since it's rainy and you want
/// something cosy, ". Empty when there's no mood or weather signal.
String naturalPreface(Mood? mood, Weather? weather) {
  final bits = <String>[];
  if (weather != null) {
    if (weather.isWet) {
      bits.add("it's ${weather.descriptor} out");
    } else if (weather.isHot) {
      bits.add("it's warm out");
    } else if (weather.isCold) {
      bits.add("it's chilly");
    }
  }
  if (mood != null) bits.add('you ${mood.youPhrase}');
  return bits.isEmpty ? '' : 'Since ${bits.join(' and ')}, ';
}
