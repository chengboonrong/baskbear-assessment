import 'package:flutter_test/flutter_test.dart';
import 'package:baskbear/data/models/voucher.dart';
import 'package:baskbear/features/vouchers/vouchers_screen.dart';

void main() {
  group('VoucherDto.fromJson redeemability', () {
    test('parses redeemable + unavailableReason when present', () {
      final v = VoucherDto.fromJson({
        'code': 'WELCOME10',
        'type': 'PERCENT',
        'value': 1000,
        'minSpendMinor': 1500,
        'maxDiscountMinor': 500,
        'stackable': false,
        'endsAt': '2026-12-31T23:59:59.000Z',
        'redeemable': false,
        'unavailableReason': 'ALREADY_USED',
      });
      expect(v.redeemable, isFalse);
      expect(v.unavailableReason, 'ALREADY_USED');
    });

    test('defaults to redeemable when the fields are absent (old API)', () {
      final v = VoucherDto.fromJson({
        'code': 'MY5OFF',
        'type': 'FIXED',
        'value': 500,
        'minSpendMinor': 2500,
        'maxDiscountMinor': null,
        'stackable': false,
        'endsAt': '2026-12-31T23:59:59.000Z',
      });
      expect(v.redeemable, isTrue);
      expect(v.unavailableReason, isNull);
    });
  });

  group('unavailableLabel', () {
    test('maps known reasons to badge text', () {
      expect(unavailableLabel('ALREADY_USED'), 'Already used');
      expect(unavailableLabel('FULLY_CLAIMED'), 'Fully claimed');
    });

    test('returns null for redeemable / unknown reasons', () {
      expect(unavailableLabel(null), isNull);
      expect(unavailableLabel('SOMETHING_NEW'), isNull);
    });
  });
}
