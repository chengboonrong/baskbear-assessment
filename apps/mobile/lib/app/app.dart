import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme.dart';

class BaskbearApp extends ConsumerWidget {
  const BaskbearApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Baskbear Coffee',
      debugShowCheckedModeBanner: false,
      theme: BaskbearTheme.light(),
      routerConfig: router,
    );
  }
}
