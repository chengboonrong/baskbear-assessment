import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/onboarding/onboarding_screen.dart';
import '../features/onboarding/country_controller.dart';
import '../features/menu/menu_screen.dart';
import '../features/menu/menu_item_detail_screen.dart';
import '../features/cart/cart_screen.dart';
import '../features/cart/checkout_screen.dart';
import '../features/orders/orders_screen.dart';
import '../features/orders/order_detail_screen.dart';
import '../features/vouchers/vouchers_screen.dart';
import '../features/account/account_screen.dart';
import '../features/ai_barista/ai_barista_screen.dart';
import 'home_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/menu',
    redirect: (context, state) {
      final onboarded = ref.read(onboardedProvider).maybeWhen(
            data: (v) => v,
            orElse: () => false,
          );
      final isOnboarding = state.matchedLocation == '/onboarding';
      if (!onboarded && !isOnboarding) return '/onboarding';
      if (onboarded && isOnboarding) return '/menu';
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => HomeShell(child: child),
        routes: [
          GoRoute(
            path: '/menu',
            builder: (_, __) => const MenuScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) =>
                    MenuItemDetailScreen(id: int.parse(state.pathParameters['id']!)),
              ),
            ],
          ),
          GoRoute(
            path: '/cart',
            builder: (_, __) => const CartScreen(),
            routes: [
              GoRoute(
                path: 'checkout',
                builder: (_, __) => const CheckoutScreen(),
              ),
            ],
          ),
          GoRoute(
            path: '/orders',
            builder: (_, __) => const OrdersScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, state) =>
                    OrderDetailScreen(id: int.parse(state.pathParameters['id']!)),
              ),
            ],
          ),
          GoRoute(
            path: '/vouchers',
            builder: (_, __) => const VouchersScreen(),
          ),
          GoRoute(
            path: '/ai',
            builder: (_, __) => const AiBaristaScreen(),
          ),
          GoRoute(
            path: '/account',
            builder: (_, __) => const AccountScreen(),
          ),
        ],
      ),
    ],
  );
});
