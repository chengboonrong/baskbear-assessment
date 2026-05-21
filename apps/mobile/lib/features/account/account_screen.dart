import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/country.dart';
import '../../data/repositories/countries_repository.dart';
import '../../data/repositories/cart_repository.dart';
import '../../data/repositories/menu_repository.dart';
import '../../data/repositories/vouchers_repository.dart';
import '../../data/repositories/orders_repository.dart';
import '../../shared/widgets/lotties.dart';
import '../onboarding/country_controller.dart';

class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(countrySelectionProvider);
    final countriesAsync = ref.watch(countriesListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const ListTile(
            leading: BearAvatar(size: 48),
            title: Text('Demo user'),
            subtitle: Text('demo@baskbear.test'),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('Country', style: Theme.of(context).textTheme.titleMedium),
          ),
          countriesAsync.when(
            loading: () => const LottieLoader(size: 56),
            error: (e, _) => Padding(padding: const EdgeInsets.all(16), child: Text('$e')),
            data: (countries) => Column(
              children: [
                for (final c in countries)
                  RadioListTile<String>(
                    value: c.code,
                    groupValue: selection.countryCode,
                    title: Text(c.name),
                    subtitle: Text('${c.currencyCode} · Tax ${(c.taxRateBps / 100).toStringAsFixed(1)}%'),
                    onChanged: (v) => _switchCountry(ref, c, v),
                  ),
              ],
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('Language', style: Theme.of(context).textTheme.titleMedium),
          ),
          countriesAsync.maybeWhen(
            data: (countries) {
              final current = countries.firstWhere(
                (c) => c.code == selection.countryCode,
                orElse: () => countries.first,
              );
              return Wrap(
                spacing: 8,
                children: [
                  for (final l in current.locales)
                    ChoiceChip(
                      label: Text(l.code.toUpperCase()),
                      selected: l.code == selection.localeCode,
                      onSelected: (_) => ref.read(countrySelectionProvider.notifier)
                          .setCountry(current.code, locale: l.code).then((_) {
                        ref.invalidate(menuListProvider);
                      }),
                    ),
                ],
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: () {
              // Stub — real Cognito sign-out would clear secure storage tokens.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cognito sign-out is wired through DEV_AUTH_BYPASS in dev.')),
              );
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
          const SizedBox(height: 24),
          const LottieFooter(),
        ],
      ),
    );
  }

  Future<void> _switchCountry(WidgetRef ref, CountryDto c, String? newCode) async {
    if (newCode == null) return;
    await ref.read(countrySelectionProvider.notifier).setCountry(newCode, locale: c.defaultLocale);
    ref.invalidate(menuListProvider);
    ref.invalidate(cartProvider);
    ref.invalidate(vouchersListProvider);
    ref.invalidate(ordersListProvider);
  }
}
