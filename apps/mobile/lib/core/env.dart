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

  // Country shown before the user completes onboarding. Falls back to MY/en
  // so flutter_test (which doesn't load .env) still has sane defaults.
  static String get defaultCountry => _orNull(dotenv.maybeGet('DEFAULT_COUNTRY')) ?? 'MY';
  static String get defaultLocale => _orNull(dotenv.maybeGet('DEFAULT_LOCALE')) ?? 'en';

  // AI Barista (optional). When unset, the Barista uses its offline keyword
  // recommender; setting a model URL enables the on-device Gemma LLM.
  static String? get gemmaModelUrl => _orNull(dotenv.maybeGet('GEMMA_MODEL_URL'));
  static String? get huggingFaceToken => _orNull(dotenv.maybeGet('HUGGINGFACE_TOKEN'));

  static String? _orNull(String? v) => (v == null || v.isEmpty) ? null : v;
}
