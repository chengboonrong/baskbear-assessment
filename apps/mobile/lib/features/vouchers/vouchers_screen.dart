import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../data/repositories/vouchers_repository.dart';
import '../../shared/widgets/lotties.dart';
import '../onboarding/country_controller.dart';

class VouchersScreen extends ConsumerWidget {
  const VouchersScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Currency for min-spend display comes from the country DTO. Falls back
    // to MYR if the country list hasn't loaded yet (a sub-second window).
    final country = ref.watch(currentCountryProvider);
    final ccy = country?.currencyCode ?? 'MYR';
    final vouchersAsync = ref.watch(vouchersListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Offers')),
      body: vouchersAsync.when(
        loading: () => const LottieLoader(),
        error: (e, _) => Center(child: Text('$e')),
        data: (vouchers) {
          if (vouchers.isEmpty) {
            return const LottieEmpty(message: 'No offers in your region right now.');
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
              final reason = unavailableLabel(v.unavailableReason);
              return Card(
                child: ListTile(
                  // enabled:false greys the icon + text so used/exhausted
                  // offers read as disabled, with the reason in the trailing chip.
                  enabled: v.redeemable,
                  leading: const Icon(Icons.local_offer_outlined),
                  title: Text('${v.code} · $desc'),
                  subtitle: Text('Min spend ${formatMoney(v.minSpendMinor, ccy)} · expires ${DateFormat.yMMMd().format(v.endsAt)}'),
                  trailing: !v.redeemable && reason != null
                      ? Chip(
                          label: Text(reason),
                          visualDensity: VisualDensity.compact,
                          backgroundColor:
                              Theme.of(context).colorScheme.surfaceContainerHighest,
                        )
                      : (v.stackable ? const Chip(label: Text('Stackable')) : null),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Maps an API `unavailableReason` to a short badge label. Returns null for
/// redeemable vouchers or unknown reasons (which then render no badge).
String? unavailableLabel(String? reason) {
  switch (reason) {
    case 'ALREADY_USED':
      return 'Already used';
    case 'FULLY_CLAIMED':
      return 'Fully claimed';
    default:
      return null;
  }
}
