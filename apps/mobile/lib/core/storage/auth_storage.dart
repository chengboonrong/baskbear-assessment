import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../env.dart';

const _kAccessTokenKey = 'auth.accessToken';
const _kIdTokenKey = 'auth.idToken';
const _kRefreshTokenKey = 'auth.refreshToken';

/// Secure-storage backed store for Cognito tokens.
///
/// In dev (DEV_BEARER_TOKEN set in .env), we treat that value as the live
/// access token without writing to keychain — keeps reviewer onboarding
/// frictionless.
class AuthStorage {
  AuthStorage(this._storage);
  final FlutterSecureStorage _storage;

  Future<String?> readAccessToken() async {
    final dev = AppEnv.devBearerToken;
    if (dev != null) return dev;
    return _storage.read(key: _kAccessTokenKey);
  }

  Future<void> saveTokens({
    required String accessToken,
    String? idToken,
    String? refreshToken,
  }) async {
    await _storage.write(key: _kAccessTokenKey, value: accessToken);
    if (idToken != null) await _storage.write(key: _kIdTokenKey, value: idToken);
    if (refreshToken != null) await _storage.write(key: _kRefreshTokenKey, value: refreshToken);
  }

  Future<void> clear() async {
    await _storage.delete(key: _kAccessTokenKey);
    await _storage.delete(key: _kIdTokenKey);
    await _storage.delete(key: _kRefreshTokenKey);
  }
}

final authStorageProvider = Provider<AuthStorage>((ref) {
  return AuthStorage(const FlutterSecureStorage());
});
