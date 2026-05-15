import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Bottom-nav shell wrapping the main app surfaces.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key, required this.child});
  final Widget child;

  static const _tabs = [
    (path: '/menu',     icon: Icons.coffee_outlined,     active: Icons.coffee,        label: 'Menu'),
    (path: '/cart',     icon: Icons.shopping_bag_outlined, active: Icons.shopping_bag, label: 'Cart'),
    (path: '/orders',   icon: Icons.receipt_long_outlined, active: Icons.receipt_long, label: 'Orders'),
    (path: '/vouchers', icon: Icons.local_offer_outlined,  active: Icons.local_offer,  label: 'Offers'),
    (path: '/account',  icon: Icons.person_outline,        active: Icons.person,       label: 'Account'),
  ];

  @override
  Widget build(BuildContext context) {
    final loc = GoRouterState.of(context).uri.path;
    final index = _tabs.indexWhere((t) => loc.startsWith(t.path));
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index < 0 ? 0 : index,
        destinations: [
          for (final t in _tabs)
            NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.active),
              label: t.label,
            ),
        ],
        onDestinationSelected: (i) => context.go(_tabs[i].path),
      ),
    );
  }
}
