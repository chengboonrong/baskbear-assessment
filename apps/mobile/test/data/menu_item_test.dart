import 'package:flutter_test/flutter_test.dart';
import 'package:baskbear/data/models/menu_item.dart';

void main() {
  group('MenuItemDetailDto.fromJson', () {
    test('parses the API response shape end-to-end', () {
      final detail = MenuItemDetailDto.fromJson({
        'id': 2,
        'sku': 'ESP-002',
        'name': 'Latte',
        'description': 'Smooth espresso with steamed milk.',
        'category': {'slug': 'espresso', 'name': 'Espresso'},
        'priceMinor': 1200,
        'currencyCode': 'MYR',
        'isAvailable': true,
        'dietaryTags': [],
        'imageUrl': null,
        'customisationGroups': [
          {
            'slug': 'size',
            'name': 'Size',
            'minSelect': 1,
            'maxSelect': 1,
            'options': [
              {'slug': 'S', 'name': 'Small',  'priceDeltaMinor': 0},
              {'slug': 'M', 'name': 'Medium', 'priceDeltaMinor': 200},
              {'slug': 'L', 'name': 'Large',  'priceDeltaMinor': 400},
            ],
          },
        ],
      });

      expect(detail.id, 2);
      expect(detail.name, 'Latte');
      expect(detail.priceMinor, 1200);
      expect(detail.customisationGroups, hasLength(1));
      expect(detail.customisationGroups.first.options, hasLength(3));
      expect(detail.customisationGroups.first.options[2].priceDeltaMinor, 400);
    });
  });
}
