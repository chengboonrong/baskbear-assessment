import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/http/api_client.dart';
import '../models/cart.dart';
import '../models/voucher.dart';

class CartRepository {
  CartRepository(this._api);
  final ApiClient _api;

  Future<CartDto> get() async {
    final res = await _api.dio.get<Map<String, dynamic>>('/v1/cart');
    return CartDto.fromJson(res.data!);
  }

  Future<CartDto> addItem({
    required int menuItemId,
    required int quantity,
    required List<({String groupSlug, String optionSlug})> customisations,
  }) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/v1/cart/items',
      data: {
        'menuItemId': menuItemId,
        'quantity': quantity,
        'customisations': customisations
            .map((c) => {'groupSlug': c.groupSlug, 'optionSlug': c.optionSlug})
            .toList(),
      },
    );
    return CartDto.fromJson(res.data!);
  }

  Future<CartDto> updateQuantity(int cartItemId, int quantity) async {
    final res = await _api.dio.patch<Map<String, dynamic>>(
      '/v1/cart/items/$cartItemId',
      data: {'quantity': quantity},
    );
    return CartDto.fromJson(res.data!);
  }

  Future<CartDto> removeItem(int cartItemId) async {
    final res = await _api.dio.delete<Map<String, dynamic>>('/v1/cart/items/$cartItemId');
    return CartDto.fromJson(res.data!);
  }

  Future<VoucherValidationDto> validateVoucher(String code) async {
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/v1/vouchers/validate',
      data: {'code': code},
    );
    return VoucherValidationDto.fromJson(res.data!);
  }
}

final cartRepositoryProvider = Provider<CartRepository>((ref) {
  return CartRepository(ref.watch(apiClientProvider));
});

final cartProvider = AsyncNotifierProvider<CartNotifier, CartDto>(CartNotifier.new);

class CartNotifier extends AsyncNotifier<CartDto> {
  @override
  Future<CartDto> build() async => ref.read(cartRepositoryProvider).get();

  Future<void> addItem({
    required int menuItemId,
    required int quantity,
    required List<({String groupSlug, String optionSlug})> customisations,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return ref.read(cartRepositoryProvider).addItem(
        menuItemId: menuItemId,
        quantity: quantity,
        customisations: customisations,
      );
    });
  }

  Future<void> updateQuantity(int id, int qty) async {
    state = await AsyncValue.guard(
      () => ref.read(cartRepositoryProvider).updateQuantity(id, qty),
    );
  }

  Future<void> remove(int id) async {
    state = await AsyncValue.guard(
      () => ref.read(cartRepositoryProvider).removeItem(id),
    );
  }

  Future<void> reload() async {
    state = await AsyncValue.guard(() => ref.read(cartRepositoryProvider).get());
  }
}
