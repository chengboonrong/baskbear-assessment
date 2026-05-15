import 'package:flutter_test/flutter_test.dart';
import 'package:baskbear/core/money.dart';

void main() {
  group('formatMoney', () {
    test('formats MYR with 2 decimal places', () {
      // 1850 minor = RM 18.50
      final result = formatMoney(1850, 'MYR', locale: 'en_MY');
      expect(result, contains('18.50'));
    });

    test('formats THB with 2 decimal places', () {
      final result = formatMoney(8500, 'THB', locale: 'en_TH');
      expect(result, contains('85.00'));
    });

    test('handles zero', () {
      final result = formatMoney(0, 'MYR', locale: 'en_MY');
      expect(result, contains('0.00'));
    });
  });
}
