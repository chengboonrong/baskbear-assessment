import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/http/api_client.dart';
import '../models/order.dart';

class OrdersRepository {
  OrdersRepository(this._api);
  final ApiClient _api;
  static const _uuid = Uuid();

  Future<List<OrderDto>> list() async {
    final res = await _api.dio.get<List<dynamic>>('/v1/orders');
    return (res.data ?? const [])
        .map((e) => OrderDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<OrderDto> findOne(int id) async {
    final res = await _api.dio.get<Map<String, dynamic>>('/v1/orders/$id');
    return OrderDto.fromJson(res.data!);
  }

  /// Idempotency key generated client-side so safe retries return the same
  /// order. Same key + same body = same order. The server enforces this via
  /// a unique (userId, idempotencyKey) index.
  Future<OrderDto> place({
    required FulfilmentType fulfilmentType,
    String? voucherCode,
    int? outletId,
    String? notes,
  }) async {
    final key = _uuid.v4();
    final res = await _api.dio.post<Map<String, dynamic>>(
      '/v1/orders',
      options: Options(headers: {'Idempotency-Key': key}),
      data: {
        'fulfilmentType': fulfilmentType.apiName,
        if (voucherCode != null) 'voucherCode': voucherCode,
        if (outletId != null) 'outletId': outletId,
        if (notes != null) 'notes': notes,
      },
    );
    return OrderDto.fromJson(res.data!);
  }
}

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepository(ref.watch(apiClientProvider));
});

final ordersListProvider = FutureProvider.autoDispose<List<OrderDto>>((ref) async {
  return ref.watch(ordersRepositoryProvider).list();
});

final orderDetailProvider =
    FutureProvider.autoDispose.family<OrderDto, int>((ref, id) async {
  return ref.watch(ordersRepositoryProvider).findOne(id);
});
