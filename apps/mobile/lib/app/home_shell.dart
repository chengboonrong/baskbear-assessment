import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/repositories/cart_repository.dart';
import '../shared/widgets/lotties.dart';

/// Bottom-nav shell wrapping the main app surfaces.
class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.child});
  final Widget child;

  static const _tabs = [
    (path: '/menu',    asset: AppLottie.tabMenu,    label: 'Menu'),
    (path: '/ai',      asset: AppLottie.tabBarista, label: 'Barista'),
    (path: '/account', asset: AppLottie.tabAccount, label: 'Account'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = GoRouterState.of(context).uri.path;
    final rawIndex = _tabs.indexWhere((t) => loc.startsWith(t.path));
    final index = rawIndex < 0 ? 0 : rawIndex;
    final cartCount = ref.watch(cartProvider).maybeWhen(
          data: (c) => c.items.fold<int>(0, (s, i) => s + i.quantity),
          orElse: () => 0,
        );
    return Scaffold(
      body: child,
      floatingActionButton: cartCount > 0
          ? CartFab(count: cartCount, onPressed: () => context.push('/cart'))
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        destinations: [
          for (var i = 0; i < _tabs.length; i++)
            NavigationDestination(
              icon: TabLottieIcon(asset: _tabs[i].asset, selected: i == index),
              label: _tabs[i].label,
            ),
        ],
        onDestinationSelected: (i) => context.go(_tabs[i].path),
      ),
    );
  }
}
