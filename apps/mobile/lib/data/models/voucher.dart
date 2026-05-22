class VoucherDto {
  VoucherDto({
    required this.code, required this.type, required this.value,
    required this.minSpendMinor, required this.maxDiscountMinor,
    required this.stackable, required this.endsAt,
    this.redeemable = true, this.unavailableReason,
  });

  final String code;
  /// PERCENT (basis points) or FIXED (minor units)
  final String type;
  final int value;
  final int minSpendMinor;
  final int? maxDiscountMinor;
  final bool stackable;
  final DateTime endsAt;

  /// Whether the current caller can redeem this code. False when they've hit
  /// the per-user limit or the voucher is globally exhausted. The list is
  /// computed server-side from redemptions; min-spend is *not* a factor here.
  final bool redeemable;

  /// Why it can't be redeemed: ALREADY_USED | FULLY_CLAIMED (null when redeemable).
  final String? unavailableReason;

  factory VoucherDto.fromJson(Map<String, dynamic> j) => VoucherDto(
        code: j['code'] as String,
        type: j['type'] as String,
        value: (j['value'] as num).toInt(),
        minSpendMinor: (j['minSpendMinor'] as num).toInt(),
        maxDiscountMinor: (j['maxDiscountMinor'] as num?)?.toInt(),
        stackable: j['stackable'] as bool,
        endsAt: DateTime.parse(j['endsAt'] as String),
        // Default to redeemable for forward-compat with older API responses.
        redeemable: j['redeemable'] as bool? ?? true,
        unavailableReason: j['unavailableReason'] as String?,
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

/// Raised when POST /v1/vouchers/validate rejects a code. Carries the API's
/// machine-readable [code] so the UI can show a precise message — the Dio
/// exception string alone never contains it (the reason lives in the body).
class VoucherException implements Exception {
  VoucherException(this.code, {this.minSpendMinor});

  /// e.g. VOUCHER_INVALID, VOUCHER_EXPIRED, MIN_SPEND_NOT_MET,
  /// VOUCHER_USER_LIMIT_REACHED, VOUCHER_NOT_AVAILABLE_IN_COUNTRY.
  final String code;

  /// Present only for MIN_SPEND_NOT_MET — the threshold, in minor units.
  final int? minSpendMinor;

  /// Builds from a NestJS error body, which is either `{message: 'CODE'}`
  /// (plain BadRequestException) or `{code: 'CODE', minSpendMinor: …}`
  /// (the structured min-spend case). Falls back to a sentinel otherwise.
  factory VoucherException.fromBody(Object? body) {
    if (body is Map) {
      final raw = body['code'] ?? body['message'];
      if (raw is String) {
        return VoucherException(
          raw,
          minSpendMinor: (body['minSpendMinor'] as num?)?.toInt(),
        );
      }
    }
    return VoucherException('VOUCHER_UNKNOWN');
  }

  @override
  String toString() => 'VoucherException($code)';
}
