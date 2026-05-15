import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../data/models/menu_item.dart';
import '../../data/repositories/menu_repository.dart';
import '../onboarding/country_controller.dart';

class MenuScreen extends ConsumerWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final menuAsync = ref.watch(menuListProvider);
    final country = ref.watch(countrySelectionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Chip(
                avatar: const Icon(Icons.flag_outlined, size: 16),
                label: Text(country.countryCode),
              ),
            ),
          ),
        ],
      ),
      body: menuAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorView(error: e, onRetry: () => ref.invalidate(menuListProvider)),
        data: (items) {
          final grouped = groupBy(items, (MenuItemDto i) => i.category.slug);
          final categories = grouped.keys.toList();
          return DefaultTabController(
            length: categories.length,
            child: Column(
              children: [
                TabBar(
                  isScrollable: true,
                  tabs: [
                    for (final slug in categories)
                      Tab(text: grouped[slug]!.first.category.name),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      for (final slug in categories)
                        RefreshIndicator(
                          onRefresh: () async => ref.invalidate(menuListProvider),
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: grouped[slug]!.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 12),
                            itemBuilder: (_, i) => _MenuRow(item: grouped[slug]![i]),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.item});
  final MenuItemDto item;

  @override
  Widget build(BuildContext context) {
    final price = formatMoney(item.priceMinor, item.currencyCode);
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/menu/${item.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.local_cafe, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: Theme.of(context).textTheme.titleMedium),
                    if (item.description != null) ...[
                      const SizedBox(height: 4),
                      Text(item.description!,
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 4, runSpacing: 4,
                      children: [
                        for (final tag in item.dietaryTags)
                          Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(tag, style: const TextStyle(fontSize: 11)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(price,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48),
            const SizedBox(height: 12),
            Text('Couldn’t load menu', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text('$error',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
