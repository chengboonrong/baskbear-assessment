import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../data/repositories/orders_repository.dart';

class OrdersScreen extends ConsumerWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(ordersListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      body: ordersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (orders) {
          if (orders.isEmpty) {
            return const Center(child: Text('No orders yet.'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(ordersListProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final o = orders[i];
                return Card(
                  child: ListTile(
                    title: Text('${o.items.length} item${o.items.length == 1 ? '' : 's'} · ${formatMoney(o.totalMinor, o.currencyCode)}'),
                    subtitle: Text('${o.status.name.toUpperCase()}  ·  ${DateFormat.yMMMd().add_jm().format(o.placedAt.toLocal())}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/orders/${o.id}'),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
