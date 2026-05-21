import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../data/models/order.dart';
import '../../data/models/voucher.dart';
import '../../data/repositories/cart_repository.dart';
import '../../data/repositories/orders_repository.dart';
import '../../shared/widgets/lotties.dart';
import '../onboarding/country_controller.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});
  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _voucherCtrl = TextEditingController();
  VoucherValidationDto? _voucher;
  String? _voucherError;
  FulfilmentType _fulfilment = FulfilmentType.takeaway;
  bool _placing = false;

  @override
  void dispose() {
    _voucherCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartAsync = ref.watch(cartProvider);
    final country = ref.watch(currentCountryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: cartAsync.when(
        loading: () => const LottieLoader(),
        error: (e, _) => Center(child: Text('$e')),
        data: (cart) {
          // Tax rate comes from the country DTO (GET /v1/countries). Server
          // recomputes on submit; this preview is just for UX honesty. If the
          // country list hasn't loaded yet, the tax row reads 0% briefly.
          final taxBps = country?.taxRateBps ?? 0;
          final discount = _voucher?.discountMinor ?? 0;
          final taxable = (cart.subtotalMinor - discount).clamp(0, 1 << 31);
          final tax = (taxable * taxBps / 10000).round();
          final total = taxable + tax;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Fulfilment', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<FulfilmentType>(
                segments: const [
                  ButtonSegment(value: FulfilmentType.dineIn,   icon: Icon(Icons.local_cafe), label: Text('Dine-in')),
                  ButtonSegment(value: FulfilmentType.takeaway, icon: Icon(Icons.shopping_bag_outlined), label: Text('Takeaway')),
                  ButtonSegment(value: FulfilmentType.delivery, icon: Icon(Icons.delivery_dining), label: Text('Delivery')),
                ],
                selected: {_fulfilment},
                onSelectionChanged: (s) => setState(() => _fulfilment = s.first),
              ),
              const SizedBox(height: 24),
              Text('Voucher', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _voucherCtrl,
                      decoration: InputDecoration(
                        hintText: 'e.g. WELCOME10',
                        errorText: _voucherError,
                      ),
                      textCapitalization: TextCapitalization.characters,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(88, 52),
                    ),
                    onPressed: _voucherCtrl.text.trim().isEmpty ? null : _applyVoucher,
                    child: Text(_voucher == null ? 'Apply' : 'Re-apply'),
                  ),
                ],
              ),
              if (_voucher != null) ...[
                const SizedBox(height: 8),
                Card(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.check_circle),
                    title: Text('${_voucher!.code} applied'),
                    subtitle: Text('-${formatMoney(_voucher!.discountMinor, cart.currencyCode)}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() {
                        _voucher = null;
                        _voucherError = null;
                      }),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              _SummaryRow(label: 'Subtotal', value: formatMoney(cart.subtotalMinor, cart.currencyCode)),
              _SummaryRow(label: 'Discount', value: '-${formatMoney(discount, cart.currencyCode)}'),
              _SummaryRow(label: 'Tax (${(taxBps / 100).toStringAsFixed(1)}%)', value: formatMoney(tax, cart.currencyCode)),
              const Divider(),
              _SummaryRow(
                label: 'Total',
                value: formatMoney(total, cart.currencyCode),
                emphasised: true,
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: _placing || cart.items.isEmpty ? null : _placeOrder,
                child: _placing
                    ? const LottieLoader(size: 30, center: false)
                    : const Text('Place order'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _applyVoucher() async {
    setState(() {
      _voucher = null;
      _voucherError = null;
    });
    try {
      final v = await ref.read(cartRepositoryProvider).validateVoucher(_voucherCtrl.text.trim().toUpperCase());
      setState(() => _voucher = v);
    } catch (e) {
      setState(() => _voucherError = _parseError(e));
    }
  }

  String _parseError(Object e) {
    final s = e.toString();
    if (s.contains('VOUCHER_INVALID')) return 'That code isn\'t valid.';
    if (s.contains('VOUCHER_EXPIRED')) return 'That code has expired.';
    if (s.contains('MIN_SPEND')) return 'Doesn\'t meet the minimum spend.';
    if (s.contains('USER_LIMIT')) return 'You\'ve already used this code.';
    if (s.contains('COUNTRY')) return 'Not available in your country.';
    return 'Couldn\'t apply that code.';
  }

  Future<void> _placeOrder() async {
    setState(() => _placing = true);
    try {
      final order = await ref.read(ordersRepositoryProvider).place(
        fulfilmentType: _fulfilment,
        voucherCode: _voucher?.code,
      );
      ref.invalidate(cartProvider);
      ref.invalidate(ordersListProvider);
      if (!mounted) return;
      context.go('/orders/${order.id}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Couldn\'t place order: $e')),
      );
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value, this.emphasised = false});
  final String label;
  final String value;
  final bool emphasised;
  @override
  Widget build(BuildContext context) {
    final style = emphasised
        ? Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)
        : Theme.of(context).textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }
}
