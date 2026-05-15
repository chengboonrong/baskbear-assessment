class VoucherDto {
  VoucherDto({
    required this.code, required this.type, required this.value,
    required this.minSpendMinor, required this.maxDiscountMinor,
    required this.stackable, required this.endsAt,
  });

  final String code;
  /// PERCENT (basis points) or FIXED (minor units)
  final String type;
  final int value;
  final int minSpendMinor;
  final int? maxDiscountMinor;
  final bool stackable;
  final DateTime endsAt;

  factory VoucherDto.fromJson(Map<String, dynamic> j) => VoucherDto(
        code: j['code'] as String,
        type: j['type'] as String,
        value: (j['value'] as num).toInt(),
        minSpendMinor: (j['minSpendMinor'] as num).toInt(),
        maxDiscountMinor: (j['maxDiscountMinor'] as num?)?.toInt(),
        stackable: j['stackable'] as bool,
        endsAt: DateTime.parse(j['endsAt'] as String),
      );
}

class VoucherValidationDto {
  VoucherValidationDto({
    required this.code, required this.discountMinor, required this.subtotalMinor,
  });
  final String code;
  final int discountMinor;
  final int subtotalMinor;
  factory VoucherValidationDto.fromJson(Map<String, dynamic> j) => VoucherValidationDto(
        code: j['code'] as String,
        discountMinor: (j['discountMinor'] as num).toInt(),
        subtotalMinor: (j['subtotalMinor'] as num).toInt(),
      );
}
