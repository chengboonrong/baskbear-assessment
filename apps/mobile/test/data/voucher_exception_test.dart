import 'package:flutter_test/flutter_test.dart';
import 'package:baskbear/data/models/voucher.dart';

void main() {
  group('VoucherException.fromBody', () {
    test('reads the code from a plain BadRequestException body', () {
      // e.g. WELCOME10 already redeemed (perUserLimit reached)
      final e = VoucherException.fromBody({
        'message': 'VOUCHER_USER_LIMIT_REACHED',
        'error': 'Bad Request',
        'statusCode': 400,
      });
      expect(e.code, 'VOUCHER_USER_LIMIT_REACHED');
      expect(e.minSpendMinor, isNull);
    });

    test('reads code and minSpendMinor from the structured min-spend body', () {
      // e.g. MY5OFF below its RM25 threshold
      final e = VoucherException.fromBody({
        'code': 'MIN_SPEND_NOT_MET',
        'minSpendMinor': 2500,
      });
      expect(e.code, 'MIN_SPEND_NOT_MET');
      expect(e.minSpendMinor, 2500);
    });

    test('handles the other plain reason codes', () {
      for (final code in const [
        'VOUCHER_INVALID',
        'VOUCHER_EXPIRED',
        'VOUCHER_NOT_AVAILABLE_IN_COUNTRY',
      ]) {
        expect(VoucherException.fromBody({'message': code}).code, code);
      }
    });

    test('falls back to a sentinel when the body has no usable code', () {
      expect(VoucherException.fromBody(null).code, 'VOUCHER_UNKNOWN');
      expect(VoucherException.fromBody('plain string').code, 'VOUCHER_UNKNOWN');
      expect(VoucherException.fromBody({'statusCode': 500}).code, 'VOUCHER_UNKNOWN');
    });
  });
}
