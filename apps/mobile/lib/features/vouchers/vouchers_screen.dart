import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../data/repositories/vouchers_repository.dart';
import '../onboarding/country_controller.dart';

class VouchersScreen extends ConsumerWidget {
  const VouchersScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final country = ref.watch(countrySelectionProvider);
    // Currency used for min-spend display: matches the user's country.
    const ccyByCountry = {'MY': 'MYR', 'TH': 'THB'};
    final ccy = ccyByCountry[country.countryCode] ?? 'MYR';
    final vouchersAsync = ref.watch(vouchersListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Offers')),
      body: vouchersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (vouchers) {
          if (vouchers.isEmpty) {
            return const Center(child: Text('No offers in your region right now.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: vouchers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final v = vouchers[i];
              final desc = v.type == 'PERCENT'
                  ? '${(v.value / 100).toStringAsFixed(0)}% off'
                  : '${formatMoney(v.value, ccy)} off';
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.local_offer_outlined),
                  title: Text('${v.code} · $desc'),
                  subtitle: Text('Min spend ${formatMoney(v.minSpendMinor, ccy)} · expires ${DateFormat.yMMMd().format(v.endsAt)}'),
                  trailing: v.stackable ? const Chip(label: Text('Stackable')) : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
