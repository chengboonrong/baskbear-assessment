import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';

/// Guards the hand-authored Lottie JSON in assets/lottie/: every file must be a
/// declared asset and must parse into a non-empty composition. A typo in the
/// bodymovin JSON fails here instead of silently rendering a blank box at runtime.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const assets = [
    'assets/lottie/coffee_loading.json',
    'assets/lottie/coffee_cup.json',
    'assets/lottie/bear_avatar.json',
    'assets/lottie/empty_state.json',
    'assets/lottie/footer_steam.json',
    'assets/lottie/tab_menu.json',
    'assets/lottie/tab_cart.json',
    'assets/lottie/tab_orders.json',
    'assets/lottie/tab_offers.json',
    'assets/lottie/tab_barista.json',
    'assets/lottie/tab_account.json',
  ];

  for (final path in assets) {
    test('parses $path', () async {
      final data = await rootBundle.load(path);
      final composition =
          await LottieComposition.fromBytes(data.buffer.asUint8List());
      expect(composition.duration, greaterThan(Duration.zero));
      expect(composition.bounds.width, greaterThan(0));
      expect(composition.bounds.height, greaterThan(0));
    });
  }
}
