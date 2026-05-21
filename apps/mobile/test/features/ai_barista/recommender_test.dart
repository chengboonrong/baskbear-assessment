import 'package:flutter_test/flutter_test.dart';
import 'package:baskbear/data/models/ai_chat.dart';
import 'package:baskbear/data/models/menu_item.dart';

MenuItemDto _item(
  int id,
  String name, {
  String category = 'Coffee',
  int price = 1000,
  bool available = true,
  List<String> tags = const [],
  String? description,
}) =>
    MenuItemDto(
      id: id,
      sku: 'SKU-$id',
      name: name,
      description: description,
      category: CategoryDto(slug: category.toLowerCase(), name: category),
      priceMinor: price,
      currencyCode: 'MYR',
      isAvailable: available,
      dietaryTags: tags,
      imageUrl: null,
    );

final _menu = [
  _item(1, 'Iced Latte', category: 'Espresso', price: 1500, tags: ['dairy']),
  _item(2, 'Hot Americano', category: 'Espresso', price: 1000),
  _item(3, 'Iced Matcha', category: 'Tea', price: 1800, tags: ['vegan']),
  _item(4, 'Caramel Frappe', category: 'Blended', price: 2000),
  _item(5, 'Secret Off-menu', available: false),
];

void main() {
  group('recommendByKeywords', () {
    test('ranks name matches first', () {
      final picks = recommendByKeywords(_menu, 'something iced please');
      expect(picks.map((p) => p.name), containsAll(['Iced Latte', 'Iced Matcha']));
      expect(picks.first.name, anyOf('Iced Latte', 'Iced Matcha'));
    });

    test('expands synonyms (cold -> iced)', () {
      final picks = recommendByKeywords(_menu, 'I want a cold drink');
      expect(picks.any((p) => p.name.startsWith('Iced')), isTrue);
    });

    test('sweet maps to caramel', () {
      final picks = recommendByKeywords(_menu, 'something sweet');
      expect(picks.first.name, 'Caramel Frappe');
    });

    test('excludes unavailable items', () {
      final picks = recommendByKeywords(_menu, 'secret', limit: 5);
      expect(picks.any((p) => p.name == 'Secret Off-menu'), isFalse);
    });

    test('empty query returns available items as a starting point', () {
      final picks = recommendByKeywords(_menu, '');
      expect(picks, isNotEmpty);
      expect(picks.any((p) => p.isAvailable == false), isFalse);
    });
  });

  group('extractRecommendations', () {
    test('parses [[markers]] and drops hallucinated items', () {
      const reply =
          "Try [[Iced Latte]] or [[Hot Americano]] — skip the [[Unicorn Frappuccino]].";
      final picks = extractRecommendations(reply, _menu);
      expect(picks.map((p) => p.name), ['Iced Latte', 'Hot Americano']);
    });

    test('falls back to verbatim name mentions when no markers', () {
      const reply = 'You should try the Caramel Frappe today.';
      final picks = extractRecommendations(reply, _menu);
      expect(picks.map((p) => p.name), ['Caramel Frappe']);
    });

    test('dedupes repeated mentions', () {
      const reply = 'Definitely [[Iced Latte]]. Did I say [[Iced Latte]]?';
      final picks = extractRecommendations(reply, _menu);
      expect(picks, hasLength(1));
    });
  });

  group('buildMenuCatalog', () {
    test('lists available items with name and price, omits unavailable', () {
      final catalog = buildMenuCatalog(_menu);
      expect(catalog, contains('Iced Latte'));
      expect(catalog, contains('RM'));
      expect(catalog, isNot(contains('Secret Off-menu')));
    });
  });
}
