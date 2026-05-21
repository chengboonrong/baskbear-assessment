import '../../core/money.dart';
import 'menu_item.dart';

/// Who authored a line in the Barista transcript.
enum AiRole { user, barista }

/// One turn in the AI Barista chat. Barista turns may carry [recommendations]
/// — real [MenuItemDto]s the user can tap to open. We reuse the menu DTO rather
/// than inventing a new shape, so cards render with the same name/price/tags.
class AiChatMessage {
  const AiChatMessage({
    required this.role,
    required this.text,
    this.recommendations = const [],
  });

  final AiRole role;
  final String text;
  final List<MenuItemDto> recommendations;
}

// --- Pure, side-effect-free helpers (unit-tested in recommender_test.dart) ----
//
// These back BOTH paths of the Barista:
//   * the on-device Gemma path — `buildMenuCatalog` grounds the prompt and
//     `extractRecommendations` pulls cards out of the model's reply;
//   * the offline fallback — `recommendByKeywords` + `fallbackReply` answer
//     without any model, so the feature works on every emulator/simulator.

/// Light synonym expansion so the keyword fallback feels less literal.
/// Keys are tokens a user might type; values are extra terms to also match
/// against item name/description/category/tags.
const Map<String, List<String>> _synonyms = {
  'cold': ['iced', 'ice', 'cold'],
  'iced': ['iced', 'ice', 'cold'],
  'hot': ['hot', 'warm'],
  'sweet': ['sweet', 'caramel', 'mocha', 'vanilla', 'honey', 'sugar', 'chocolate'],
  'strong': ['espresso', 'strong', 'bold', 'ristretto'],
  'milk': ['milk', 'latte', 'oat', 'soy', 'flat'],
  'milky': ['latte', 'milk', 'flat', 'oat'],
  'tea': ['tea', 'matcha', 'chai'],
  'fruity': ['fruit', 'berry', 'citrus', 'orange', 'lemon'],
  'light': ['americano', 'long', 'black'],
};

const Set<String> _stopwords = {
  'a', 'an', 'the', 'i', 'me', 'my', 'want', 'would', 'like', 'something',
  'some', 'with', 'and', 'or', 'for', 'please', 'can', 'you', 'get', 'have',
  'to', 'of', 'is', 'are', 'not', 'too', 'really', 'kinda', 'bit', 'in',
};

List<String> _tokenize(String input) => input
    .toLowerCase()
    .split(RegExp(r'[^a-z0-9]+'))
    .where((t) => t.length > 1 && !_stopwords.contains(t))
    .toList();

String _haystack(MenuItemDto i) => [
      i.name,
      i.description ?? '',
      i.category.name,
      i.dietaryTags.join(' '),
    ].join(' ').toLowerCase();

/// Rank menu items by keyword overlap with [query]; returns up to [limit].
/// Name matches weigh double. Falls back to the first [limit] items when the
/// query matches nothing, so the Barista always offers a starting point.
List<MenuItemDto> recommendByKeywords(
  List<MenuItemDto> menu,
  String query, {
  int limit = 3,
}) {
  final available = menu.where((i) => i.isAvailable).toList();
  if (available.isEmpty) return const [];

  final keywords = <String>{};
  for (final token in _tokenize(query)) {
    keywords.add(token);
    keywords.addAll(_synonyms[token] ?? const []);
  }

  if (keywords.isEmpty) return available.take(limit).toList();

  final scored = available.map((item) {
    final hay = _haystack(item);
    final name = item.name.toLowerCase();
    var score = 0;
    for (final kw in keywords) {
      if (name.contains(kw)) {
        score += 2;
      } else if (hay.contains(kw)) {
        score += 1;
      }
    }
    return (item: item, score: score);
  }).toList()
    // Stable: higher score first, then lowest id for determinism.
    ..sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      return byScore != 0 ? byScore : a.item.id.compareTo(b.item.id);
    });

  final matched = scored.where((e) => e.score > 0).map((e) => e.item).toList();
  final picks = matched.isNotEmpty ? matched : available;
  return picks.take(limit).toList();
}

/// Pull the items a model recommended out of its free-text [reply].
/// Primary signal: `[[Exact Name]]` markers we ask the model to emit. Fallback:
/// any menu item name that appears verbatim in the reply. Deduped, order-preserved,
/// and constrained to the real menu (guards against hallucinated items).
List<MenuItemDto> extractRecommendations(String reply, List<MenuItemDto> menu) {
  final byNameLower = {for (final i in menu) i.name.toLowerCase(): i};
  final picks = <int, MenuItemDto>{};

  final markers = RegExp(r'\[\[(.+?)\]\]').allMatches(reply);
  for (final m in markers) {
    final name = m.group(1)!.trim().toLowerCase();
    final exact = byNameLower[name];
    final hit = exact ?? _firstContaining(menu, name);
    if (hit != null) picks.putIfAbsent(hit.id, () => hit);
  }

  if (picks.isEmpty) {
    final lowerReply = reply.toLowerCase();
    final mentions = menu
        .where((i) => lowerReply.contains(i.name.toLowerCase()))
        .toList()
      // Order by where the name first appears in the reply.
      ..sort((a, b) => lowerReply
          .indexOf(a.name.toLowerCase())
          .compareTo(lowerReply.indexOf(b.name.toLowerCase())));
    for (final i in mentions.take(4)) {
      picks.putIfAbsent(i.id, () => i);
    }
  }

  return picks.values.toList();
}

MenuItemDto? _firstContaining(List<MenuItemDto> menu, String needle) {
  for (final i in menu) {
    if (i.name.toLowerCase().contains(needle)) return i;
  }
  return null;
}

/// Compact, model-friendly catalog the on-device prompt is grounded on.
/// One line per item: name (category) · price · tags: description.
String buildMenuCatalog(List<MenuItemDto> menu) {
  final lines = menu.where((i) => i.isAvailable).map((i) {
    final price = formatMoney(i.priceMinor, i.currencyCode);
    final tags = i.dietaryTags.isEmpty ? '' : ' · ${i.dietaryTags.join(", ")}';
    final desc = (i.description ?? '').trim();
    final shortDesc = desc.length > 90 ? '${desc.substring(0, 90)}…' : desc;
    return '- ${i.name} (${i.category.name}) · $price$tags${shortDesc.isEmpty ? '' : ': $shortDesc'}';
  });
  return lines.join('\n');
}

/// Friendly canned reply for the offline fallback, naming the [picks].
/// [preface] is an optional natural lead-in (e.g. weather/mood context) ending
/// in a comma+space, like "Since it's rainy and you want something cosy, ".
String fallbackReply(List<MenuItemDto> picks, {String preface = ''}) {
  if (picks.isEmpty) {
    return "I couldn't find a match on the menu for your area just yet — try describing a flavour or temperature?";
  }
  final names = picks.map((p) => p.name).toList();
  final list = names.length == 1
      ? names.first
      : '${names.sublist(0, names.length - 1).join(', ')} or ${names.last}';
  final lead = preface.isEmpty ? 'Based on that, you might enjoy' : '${preface}you might enjoy';
  return "$lead $list. Tap one to see the details and add it to your cart.";
}
