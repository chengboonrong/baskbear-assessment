import 'package:intl/intl.dart';

/// Format a price stored in minor units (e.g. 1850 → "RM 18.50").
///
/// Currency-aware: MYR/THB are 2dp; IDR (future) is 0dp. We derive the
/// fractionDigits from `intl.NumberFormat`'s currency metadata.
String formatMoney(int minor, String currencyCode, {String? locale}) {
  final fmt = NumberFormat.simpleCurrency(name: currencyCode, locale: locale);
  final decimals = fmt.decimalDigits ?? 2;
  final divisor = _pow10(decimals);
  return fmt.format(minor / divisor);
}

double _pow10(int n) {
  var r = 1.0;
  for (var i = 0; i < n; i++) {
    r *= 10;
  }
  return r;
}
