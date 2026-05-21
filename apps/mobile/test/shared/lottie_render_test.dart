import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:baskbear/shared/widgets/lotties.dart';

/// Render smoke test: every Lottie-backed widget must mount and paint a few
/// frames without throwing. Parsing is covered by lottie_assets_test.dart; this
/// guards the paint path (trim paths, group transforms) the parser doesn't run.
void main() {
  Future<void> pumpFrames(WidgetTester tester, Widget child) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: Center(child: child))),
      );
    });
    // Advance through a chunk of the animation timelines.
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  }

  testWidgets('LottieLoader paints', (t) async {
    await pumpFrames(t, const LottieLoader(size: 96));
  });

  testWidgets('BearAvatar paints', (t) async {
    await pumpFrames(t, const BearAvatar(size: 64));
  });

  testWidgets('CoffeeThumb paints (no image url)', (t) async {
    await pumpFrames(t, const CoffeeThumb(width: 64, height: 64));
  });

  testWidgets('LottieEmpty paints', (t) async {
    await pumpFrames(t, const LottieEmpty(message: 'Nothing here'));
  });

  testWidgets('LottieFooter paints', (t) async {
    await pumpFrames(t, const LottieFooter());
  });
}
