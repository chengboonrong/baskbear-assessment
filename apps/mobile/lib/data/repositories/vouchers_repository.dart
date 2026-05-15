import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/http/api_client.dart';
import '../models/voucher.dart';

class VouchersRepository {
  VouchersRepository(this._api);
  final ApiClient _api;

  Future<List<VoucherDto>> list() async {
    final res = await _api.dio.get<List<dynamic>>('/v1/vouchers');
    return (res.data ?? const [])
        .map((e) => VoucherDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

final vouchersRepositoryProvider = Provider<VouchersRepository>((ref) {
  return VouchersRepository(ref.watch(apiClientProvider));
});

final vouchersListProvider = FutureProvider.autoDispose<List<VoucherDto>>((ref) async {
  return ref.watch(vouchersRepositoryProvider).list();
});
