import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/http/api_client.dart';
import '../../features/outlets/outlet_controller.dart';
import '../models/menu_item.dart';

class MenuRepository {
  MenuRepository(this._api);
  final ApiClient _api;

  Future<List<MenuItemDto>> list({String? category, int? outletId}) async {
    final res = await _api.dio.get<List<dynamic>>(
      '/v1/menu',
      queryParameters: {
        if (category != null) 'category': category,
        if (outletId != null) 'outlet': outletId,
      },
    );
    return (res.data ?? const [])
        .map((e) => MenuItemDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MenuItemDetailDto> findOne(int id, {int? outletId}) async {
    final res = await _api.dio.get<Map<String, dynamic>>(
      '/v1/menu/$id',
      queryParameters: {if (outletId != null) 'outlet': outletId},
    );
    return MenuItemDetailDto.fromJson(res.data!);
  }
}

final menuRepositoryProvider = Provider<MenuRepository>((ref) {
  return MenuRepository(ref.watch(apiClientProvider));
});

final menuListProvider = FutureProvider.autoDispose<List<MenuItemDto>>((ref) async {
  final repo = ref.watch(menuRepositoryProvider);
  final outletId = ref.watch(selectedOutletProvider);
  return repo.list(outletId: outletId);
});

final menuItemProvider =
    FutureProvider.autoDispose.family<MenuItemDetailDto, int>((ref, id) async {
  final repo = ref.watch(menuRepositoryProvider);
  final outletId = ref.watch(selectedOutletProvider);
  return repo.findOne(id, outletId: outletId);
});
