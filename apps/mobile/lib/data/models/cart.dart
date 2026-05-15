class CartDto {
  CartDto({
    required this.id, required this.currencyCode, required this.country,
    required this.items, required this.subtotalMinor,
  });

  final int id;
  final String currencyCode;
  final String country;
  final List<CartItemDto> items;
  final int subtotalMinor;

  factory CartDto.fromJson(Map<String, dynamic> j) => CartDto(
        id: (j['id'] as num).toInt(),
        currencyCode: j['currencyCode'] as String,
        country: j['country'] as String,
        items: (j['items'] as List<dynamic>)
            .map((e) => CartItemDto.fromJson(e as Map<String, dynamic>))
            .toList(),
        subtotalMinor: (j['subtotalMinor'] as num).toInt(),
      );
}

class CartItemDto {
  CartItemDto({
    required this.id, required this.menuItemId, required this.name,
    required this.quantity, required this.unitPriceMinor,
    required this.customisations, required this.lineTotalMinor,
  });

  final int id;
  final int menuItemId;
  final String name;
  final int quantity;
  final int unitPriceMinor;
  final List<CustomisationChoiceDto> customisations;
  final int lineTotalMinor;

  factory CartItemDto.fromJson(Map<String, dynamic> j) => CartItemDto(
        id: (j['id'] as num).toInt(),
        menuItemId: (j['menuItemId'] as num).toInt(),
        name: j['name'] as String,
        quantity: (j['quantity'] as num).toInt(),
        unitPriceMinor: (j['unitPriceMinor'] as num).toInt(),
        customisations: (j['customisations'] as List<dynamic>)
            .map((e) => CustomisationChoiceDto.fromJson(e as Map<String, dynamic>))
            .toList(),
        lineTotalMinor: (j['lineTotalMinor'] as num).toInt(),
      );
}

class CustomisationChoiceDto {
  CustomisationChoiceDto({
    required this.groupSlug, required this.optionSlug,
    required this.name, required this.deltaMinor,
  });
  final String groupSlug;
  final String optionSlug;
  final String name;
  final int deltaMinor;
  factory CustomisationChoiceDto.fromJson(Map<String, dynamic> j) =>
      CustomisationChoiceDto(
        groupSlug: j['groupSlug'] as String,
        optionSlug: j['optionSlug'] as String,
        name: j['name'] as String,
        deltaMinor: (j['deltaMinor'] as num).toInt(),
      );
}
