import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Lightweight env access wrapper. flutter_dotenv loads `.env` from assets
/// at startup; we read named keys with defaults here so callers don't have
/// to know about the asset path.
class AppEnv {
  static Future<void> load() => dotenv.load(fileName: '.env');

  static String get apiBaseUrl => dotenv.maybeGet('API_BASE_URL') ?? 'http://localhost:3000';
  static String? get devBearerToken {
    final v = dotenv.maybeGet('DEV_BEARER_TOKEN');
    return (v == null || v.isEmpty) ? null : v;
  }

  static String? get cognitoUserPoolId => _orNull(dotenv.maybeGet('COGNITO_USER_POOL_ID'));
  static String? get cognitoAppClientId => _orNull(dotenv.maybeGet('COGNITO_APP_CLIENT_ID'));
  static String? get cognitoRegion => _orNull(dotenv.maybeGet('COGNITO_REGION'));
  static String? get cognitoHostedUiDomain => _orNull(dotenv.maybeGet('COGNITO_HOSTED_UI_DOMAIN'));

  static String? _orNull(String? v) => (v == null || v.isEmpty) ? null : v;
}
