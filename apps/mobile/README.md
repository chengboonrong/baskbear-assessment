# Baskbear Coffee — Mobile App

Flutter 3.38 app for the Baskbear Coffee ordering experience. Runs on iOS, Android, and Chrome. Connects to the NestJS API in `apps/api/`.

> Full setup instructions, environment variables, and feature descriptions are in the [root README](../../README.md).

## Quick start

```bash
cd apps/mobile
cp .env.example .env
flutter pub get
flutter run -d chrome --web-port 5050   # fastest first run — no device setup needed
```

For Android emulator, set `API_BASE_URL=http://10.0.2.2:3000` in `.env`.

## Key commands

```bash
flutter test                                      # run all tests
flutter test test/data/menu_dto_test.dart         # single test file
flutter analyze --no-fatal-infos                  # lint (matches CI)
flutter build apk                                 # debug APK
```

## AI Barista (optional)

The Barista tab works out of the box via an offline keyword recommender. To enable the on-device Gemma AI model, add your HuggingFace token to `.env` — see the [root README](../../README.md#enabling-the-on-device-ai-barista-llm-optional) for the full setup steps.
