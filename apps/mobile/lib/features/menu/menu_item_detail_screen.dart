import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../data/models/menu_item.dart';
import '../../data/repositories/cart_repository.dart';
import '../../data/repositories/menu_repository.dart';
import '../../shared/widgets/lotties.dart';

class MenuItemDetailScreen extends ConsumerStatefulWidget {
  const MenuItemDetailScreen({super.key, required this.id});
  final int id;
  @override
  ConsumerState<MenuItemDetailScreen> createState() => _MenuItemDetailScreenState();
}

class _MenuItemDetailScreenState extends ConsumerState<MenuItemDetailScreen> {
  /// Map<groupSlug, Set<optionSlug>> — supports multi-select groups (none today,
  /// but the schema allows it and we honour it here).
  final Map<String, Set<String>> _selections = {};
  int _quantity = 1;
  bool _adding = false;

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(menuItemProvider(widget.id));
    return Scaffold(
      appBar: AppBar(title: const Text('Detail')),
      body: detailAsync.when(
        loading: () => const LottieLoader(),
        error: (e, _) => Center(child: Text('$e')),
        data: (item) => _build(item),
      ),
    );
  }

  Widget _build(MenuItemDetailDto item) {
    final delta = item.customisationGroups
        .expand((g) => g.options.where((o) => _selections[g.slug]?.contains(o.slug) ?? false))
        .fold<int>(0, (acc, o) => acc + o.priceDeltaMinor);
    final unitPrice = item.priceMinor + delta;
    final total = unitPrice * _quantity;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              CoffeeThumb(
                width: double.infinity,
                height: 180,
                radius: 16,
                imageUrl: item.imageUrl,
              ),
              const SizedBox(height: 16),
              Text(item.name, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              if (item.description != null) Text(item.description!),
              const SizedBox(height: 16),
              for (final g in item.customisationGroups) _Group(
                group: g,
                selection: _selections[g.slug] ?? {},
                onChanged: (next) => setState(() => _selections[g.slug] = next),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Quantity', style: Theme.of(context).textTheme.titleMedium),
                  Row(
                    children: [
                      IconButton.outlined(
                        onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
                        icon: const Icon(Icons.remove),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('$_quantity', style: Theme.of(context).textTheme.titleLarge),
                      ),
                      IconButton.outlined(
                        onPressed: _quantity < 20 ? () => setState(() => _quantity++) : null,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton(
              onPressed: _adding || !_meetsMinima(item) ? null : () => _add(item),
              child: _adding
                  ? const LottieLoader(size: 30, center: false)
                  : Text('Add to cart · ${formatMoney(total, item.currencyCode)}'),
            ),
          ),
        ),
      ],
    );
  }

  bool _meetsMinima(MenuItemDetailDto item) {
    for (final g in item.customisationGroups) {
      final n = _selections[g.slug]?.length ?? 0;
      if (n < g.minSelect || n > g.maxSelect) return false;
    }
    return true;
  }

  Future<void> _add(MenuItemDetailDto item) async {
    setState(() => _adding = true);
    try {
      final picks = _selections.entries
          .expand((e) => e.value.map((o) => (groupSlug: e.key, optionSlug: o)))
          .toList();
      await ref.read(cartProvider.notifier).addItem(
            menuItemId: item.id,
            quantity: _quantity,
            customisations: picks,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to cart')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn\'t add: $e')),
      );
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.group, required this.selection, required this.onChanged});
  final CustomisationGroupDto group;
  final Set<String> selection;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final required = group.minSelect > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(group.name, style: Theme.of(context).textTheme.titleMedium),
              if (required) ...[
                const SizedBox(width: 8),
                Text('Required', style: Theme.of(context).textTheme.labelSmall),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              for (final opt in group.options)
                ChoiceChip(
                  label: Text(opt.priceDeltaMinor == 0
                      ? opt.name
                      : '${opt.name} +${(opt.priceDeltaMinor / 100).toStringAsFixed(2)}'),
                  selected: selection.contains(opt.slug),
                  onSelected: (sel) {
                    final next = {...selection};
                    if (group.maxSelect <= 1) {
                      next..clear()..add(opt.slug);
                    } else if (sel) {
                      if (next.length < group.maxSelect) next.add(opt.slug);
                    } else {
                      next.remove(opt.slug);
                    }
                    onChanged(next);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
