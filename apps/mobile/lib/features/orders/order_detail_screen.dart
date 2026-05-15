import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../data/models/order.dart';
import '../../data/repositories/orders_repository.dart';

class OrderDetailScreen extends ConsumerWidget {
  const OrderDetailScreen({super.key, required this.id});
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(orderDetailProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('Order')),
      body: orderAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (o) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(orderDetailProvider(id)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(o.orderNumber, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(DateFormat.yMMMMEEEEd().add_jm().format(o.placedAt.toLocal())),
                      const SizedBox(height: 12),
                      _Timeline(events: o.statusEvents),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text('Items', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final it in o.items)
                Card(
                  child: ListTile(
                    title: Text('${it.quantity}× ${it.nameSnapshot}'),
                    subtitle: it.customisations.isEmpty
                        ? null
                        : Text(it.customisations.map((c) => c.name).join(' · ')),
                    trailing: Text(formatMoney(it.lineTotalMinor, o.currencyCode)),
                  ),
                ),
              const SizedBox(height: 16),
              _row('Subtotal', formatMoney(o.subtotalMinor, o.currencyCode)),
              _row('Discount', '-${formatMoney(o.discountMinor, o.currencyCode)}'),
              _row('Tax', formatMoney(o.taxMinor, o.currencyCode)),
              const Divider(),
              _row('Total', formatMoney(o.totalMinor, o.currencyCode), bold: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: bold ? const TextStyle(fontWeight: FontWeight.w700) : null),
            Text(value, style: bold ? const TextStyle(fontWeight: FontWeight.w700) : null),
          ],
        ),
      );
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.events});
  final List<OrderStatusEventDto> events;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < events.length; i++) ...[
          Row(
            children: [
              Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(events[i].status.name.toUpperCase()),
              const Spacer(),
              Text(DateFormat.jm().format(events[i].occurredAt.toLocal()),
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ],
    );
  }
}
