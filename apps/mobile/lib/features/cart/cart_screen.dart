import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../data/models/cart.dart';
import '../../data/repositories/cart_repository.dart';
import '../../shared/widgets/lotties.dart';

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartAsync = ref.watch(cartProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: cartAsync.when(
        loading: () => const LottieLoader(),
        error: (e, _) => Center(child: Text('$e')),
        data: (cart) {
          if (cart.items.isEmpty) {
            return _EmptyCart();
          }
          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: cart.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _CartLine(item: cart.items[i], currency: cart.currencyCode),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Subtotal', style: Theme.of(context).textTheme.titleMedium),
                          Text(formatMoney(cart.subtotalMinor, cart.currencyCode),
                              style: Theme.of(context).textTheme.titleMedium),
                        ],
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: () => context.push('/cart/checkout'),
                        child: const Text('Checkout'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CartLine extends ConsumerWidget {
  const _CartLine({required this.item, required this.currency});
  final CartItemDto item;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  if (item.customisations.isNotEmpty)
                    Text(item.customisations.map((c) => c.name).join(' · '),
                        style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 6),
                  Text(formatMoney(item.unitPriceMinor, currency)),
                ],
              ),
            ),
            Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => ref.read(cartProvider.notifier).updateQuantity(item.id, item.quantity - 1),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Text('${item.quantity}'),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => ref.read(cartProvider.notifier).updateQuantity(item.id, item.quantity + 1),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
                Text(formatMoney(item.lineTotalMinor, currency),
                    style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LottieEmpty(
      message: 'Your cart is empty',
      action: TextButton(
        onPressed: () => GoRouter.of(context).go('/menu'),
        child: const Text('Browse menu'),
      ),
    );
  }
}
