import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../data/models/menu_item.dart';
import '../../data/models/outlet.dart';
import '../../data/repositories/countries_repository.dart';
import '../../data/repositories/menu_repository.dart';
import '../../shared/widgets/lotties.dart';
import '../onboarding/country_controller.dart';
import '../outlets/outlet_controller.dart';

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
          const _OutletPickerButton(),
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
        loading: () => const LottieLoader(),
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

/// App-bar control that shows the active outlet (or "All outlets") and opens a
/// picker. Selecting an outlet re-scopes the menu's availability via
/// [selectedOutletProvider], which the menu providers watch.
class _OutletPickerButton extends ConsumerWidget {
  const _OutletPickerButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(selectedOutletProvider);
    final outlets = ref.watch(outletsProvider).asData?.value ?? const <OutletDto>[];
    final selected =
        selectedId == null ? null : outlets.firstWhereOrNull((o) => o.id == selectedId);
    return TextButton.icon(
      icon: const Icon(Icons.storefront_outlined, size: 18),
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 110),
        child: Text(
          selected?.name ?? 'All outlets',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      onPressed: outlets.isEmpty ? null : () => _showPicker(context, ref, outlets, selectedId),
    );
  }

  Future<void> _showPicker(
    BuildContext context,
    WidgetRef ref,
    List<OutletDto> outlets,
    int? selectedId,
  ) {
    void choose(int? id) {
      ref.read(selectedOutletProvider.notifier).setOutlet(id);
      Navigator.pop(context);
    }

    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('Choose outlet', style: Theme.of(ctx).textTheme.titleMedium),
            ),
            ListTile(
              leading: const Icon(Icons.public),
              title: const Text('All outlets'),
              subtitle: const Text('Show the full country menu'),
              trailing: selectedId == null ? const Icon(Icons.check) : null,
              onTap: () => choose(null),
            ),
            for (final o in outlets)
              ListTile(
                leading: const Icon(Icons.storefront_outlined),
                title: Text(o.name),
                subtitle: Text(o.address, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: selectedId == o.id ? const Icon(Icons.check) : null,
                onTap: () => choose(o.id),
              ),
          ],
        ),
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
    final available = item.isAvailable;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        // Unavailable (here or at the selected outlet) → not tappable.
        onTap: available ? () => context.push('/menu/${item.id}') : null,
        child: Opacity(
          opacity: available ? 1 : 0.45,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CoffeeThumb(width: 64, height: 64, imageUrl: item.imageUrl),
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
                          if (!available)
                            Chip(
                              visualDensity: VisualDensity.compact,
                              backgroundColor:
                                  Theme.of(context).colorScheme.errorContainer,
                              label: const Text('Unavailable',
                                  style: TextStyle(fontSize: 11)),
                            ),
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
