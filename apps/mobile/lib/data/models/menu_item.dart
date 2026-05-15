class MenuItemDto {
  MenuItemDto({
    required this.id, required this.sku, required this.name,
    required this.description, required this.category,
    required this.priceMinor, required this.currencyCode,
    required this.isAvailable, required this.dietaryTags,
    required this.imageUrl,
  });

  final int id;
  final String sku;
  final String name;
  final String? description;
  final CategoryDto category;
  final int priceMinor;
  final String currencyCode;
  final bool isAvailable;
  final List<String> dietaryTags;
  final String? imageUrl;

  factory MenuItemDto.fromJson(Map<String, dynamic> j) => MenuItemDto(
        id: j['id'] as int,
        sku: j['sku'] as String,
        name: j['name'] as String,
        description: j['description'] as String?,
        category: CategoryDto.fromJson(j['category'] as Map<String, dynamic>),
        priceMinor: (j['priceMinor'] as num).toInt(),
        currencyCode: j['currencyCode'] as String,
        isAvailable: j['isAvailable'] as bool,
        dietaryTags: ((j['dietaryTags'] as List<dynamic>?) ?? const [])
            .map((e) => e as String)
            .toList(),
        imageUrl: j['imageUrl'] as String?,
      );
}

class CategoryDto {
  CategoryDto({required this.slug, required this.name});
  final String slug;
  final String name;
  factory CategoryDto.fromJson(Map<String, dynamic> j) =>
      CategoryDto(slug: j['slug'] as String, name: j['name'] as String);
}

class MenuItemDetailDto extends MenuItemDto {
  MenuItemDetailDto({
    required super.id, required super.sku, required super.name,
    required super.description, required super.category,
    required super.priceMinor, required super.currencyCode,
    required super.isAvailable, required super.dietaryTags,
    required super.imageUrl, required this.customisationGroups,
  });

  final List<CustomisationGroupDto> customisationGroups;

  factory MenuItemDetailDto.fromJson(Map<String, dynamic> j) {
    final base = MenuItemDto.fromJson(j);
    return MenuItemDetailDto(
      id: base.id, sku: base.sku, name: base.name, description: base.description,
      category: base.category, priceMinor: base.priceMinor,
      currencyCode: base.currencyCode, isAvailable: base.isAvailable,
      dietaryTags: base.dietaryTags, imageUrl: base.imageUrl,
      customisationGroups: (j['customisationGroups'] as List<dynamic>)
          .map((e) => CustomisationGroupDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CustomisationGroupDto {
  CustomisationGroupDto({
    required this.slug, required this.name,
    required this.minSelect, required this.maxSelect,
    required this.options,
  });
  final String slug;
  final String name;
  final int minSelect;
  final int maxSelect;
  final List<CustomisationOptionDto> options;

  factory CustomisationGroupDto.fromJson(Map<String, dynamic> j) =>
      CustomisationGroupDto(
        slug: j['slug'] as String,
        name: j['name'] as String,
        minSelect: (j['minSelect'] as num).toInt(),
        maxSelect: (j['maxSelect'] as num).toInt(),
        options: (j['options'] as List<dynamic>)
            .map((e) => CustomisationOptionDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class CustomisationOptionDto {
  CustomisationOptionDto({
    required this.slug, required this.name, required this.priceDeltaMinor,
  });
  final String slug;
  final String name;
  final int priceDeltaMinor;
  factory CustomisationOptionDto.fromJson(Map<String, dynamic> j) =>
      CustomisationOptionDto(
        slug: j['slug'] as String,
        name: j['name'] as String,
        priceDeltaMinor: (j['priceDeltaMinor'] as num).toInt(),
      );
}
