import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../env.dart';
import '../storage/auth_storage.dart';
import '../../features/onboarding/country_controller.dart';

/// Dio client with three layers of cross-cutting concerns:
///   1. Auth — injects `Authorization: Bearer …` from secure storage.
///   2. Locality — adds `X-Country` / `X-Locale` from the current selection.
///   3. Resilience — retries idempotent GETs with exponential backoff.
///
/// Notes:
/// - We deliberately do NOT retry POST/PATCH/DELETE without an idempotency
///   key. Order placement carries its own key generated client-side.
/// - Timeouts are deliberately generous (15s) to survive cellular hops in MY/TH.
class ApiClient {
  ApiClient({required Dio dio}) : _dio = dio;
  final Dio _dio;
  Dio get dio => _dio;

  static ApiClient build({
    required AuthStorage authStorage,
    required CountrySelection Function() countrySelection,
  }) {
    final dio = Dio(BaseOptions(
      baseUrl: AppEnv.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: { 'Accept': 'application/json' },
    ));

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await authStorage.readAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        final sel = countrySelection();
        options.headers['X-Country'] = sel.countryCode;
        options.headers['X-Locale'] = sel.localeCode;
        handler.next(options);
      },
    ));

    dio.interceptors.add(_RetryInterceptor());

    return ApiClient(dio: dio);
  }
}

/// Minimal retry interceptor — GETs only, max 2 retries with backoff.
/// Skips on 4xx and on writes (callers handle idempotency themselves).
class _RetryInterceptor extends Interceptor {
  static const _maxAttempts = 3;
  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final req = err.requestOptions;
    final attempts = (req.extra['retryAttempts'] as int?) ?? 0;
    final shouldRetry = req.method == 'GET' &&
        attempts < _maxAttempts - 1 &&
        _isRetryable(err);
    if (!shouldRetry) {
      handler.next(err);
      return;
    }
    req.extra['retryAttempts'] = attempts + 1;
    final backoff = Duration(milliseconds: 200 * (1 << attempts));
    await Future.delayed(backoff);
    try {
      final res = await Dio().fetch(req);
      handler.resolve(res);
    } catch (e) {
      handler.next(err);
    }
  }

  bool _isRetryable(DioException err) {
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout) return true;
    final status = err.response?.statusCode ?? 0;
    return status >= 500 && status < 600;
  }
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final auth = ref.watch(authStorageProvider);
  return ApiClient.build(
    authStorage: auth,
    countrySelection: () => ref.read(countrySelectionProvider),
  );
});
