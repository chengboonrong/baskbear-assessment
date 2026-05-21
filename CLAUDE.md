# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repo shape

Monorepo for the Baskbear Coffee assessment — two apps share one MySQL schema:

- `apps/api/` — NestJS 11 + Prisma 7 (driver-adapter, no Rust engine) + Zod, MySQL 8
- `apps/mobile/` — Flutter 3.38 + Riverpod 2 + go_router + Dio
- `db/sql/` — raw SQL export of the Prisma migration (read-only reference; the schema of record is `apps/api/prisma/schema.prisma`)
- `docs/architecture.md` — rendered ERD + AWS topology diagrams; the full long-form Q1–Q17 answers now live inline in the README, which this file's diagrams support

There is no root-level package manager. Each app installs and runs independently. The only thing shared between them is the API's HTTP contract and the country/locale headers (`X-Country`, `X-Locale`).

## Common commands

### Local infra
```bash
docker compose up -d                    # MySQL 8 on :3307, Redis on :6379
```
MySQL host port is **3307** (not 3306) to avoid clashing with a native MySQL install. The seeded creds (`baskbear:baskbear`) match `apps/api/.env.example`.

### API (`apps/api/`)
```bash
npm install                             # postinstall runs `prisma generate`
cp .env.example .env                    # works as-is against docker compose
npx prisma migrate deploy               # apply migrations
npm run seed                            # MY + TH + SG menus, 6 outlets, 3 vouchers, demo user
npm run start:dev                       # nest start --watch on :3000

npm test                                # Jest, all *.spec.ts under src/
npm test -- pricing.spec                # single file
npm test -- -t "computeVoucherDiscount" # single test by name
npm run lint                            # eslint --fix
npx tsc --noEmit -p tsconfig.json       # type-check only (what CI runs)
npx prisma studio                       # DB GUI
npx prisma migrate dev --name <slug>    # create a new migration during dev
```

### Mobile (`apps/mobile/`)
```bash
flutter pub get
cp .env.example .env                    # needed — the file is bundled as an asset
flutter run -d chrome --web-port 5050   # smoothest first run
flutter run -d <android-emu-name>       # use API_BASE_URL=http://10.0.2.2:3000 in .env for Android
flutter test                            # all tests under test/
flutter test test/data/menu_dto_test.dart   # single file
flutter analyze --no-fatal-infos        # what CI runs
```
The `.env` file is listed under `flutter.assets` in `pubspec.yaml` — if it's missing, `AppEnv.load()` will fail at boot. CI works around this by copying `.env.example` to `.env`.

### CI
- `.github/workflows/api-ci.yml` — boots a MySQL service, type-checks, `prisma validate`, `migrate deploy`, seed, Jest. Filters on `apps/api/**`.
- `.github/workflows/mobile-ci.yml` — `flutter analyze`, `flutter test`, debug APK build. Filters on `apps/mobile/**`.

## Architecture notes that span multiple files

### Request context: auth + country are decoupled, both required for most endpoints
Most controllers compose two pieces of middleware:
- `@UseGuards(CognitoJwtGuard)` — `apps/api/src/auth/cognito-jwt.guard.ts` reads `Authorization: Bearer …`, verifies against Cognito JWKS (or accepts `Bearer dev:<sub>` when `DEV_AUTH_BYPASS=true`), upserts the local `User` row by `cognitoSub`, and sets `req.auth = { userId, cognitoSub }`.
- `@UseInterceptors(CountryInterceptor)` — `apps/api/src/countries/country.interceptor.ts` resolves country + locale from `X-Country` / `X-Locale` (falling back to query → user default → env default), validates them against the DB, and sets `req.country: CountryContext`. The lookup is memoised in-process.

Controllers then pull these via the `@CurrentUser()` / `@CurrentCountry()` param decorators in `apps/api/src/common/decorators.ts`. If you add a new endpoint that depends on country pricing or per-user data, both pieces must be wired — the decorators throw at runtime if their context is missing.

Public endpoints that only need country (`/v1/menu`, `/v1/vouchers GET`, `/v1/countries`) skip the guard. `/v1/auth/exchange` skips the interceptor.

### Money is always minor units; percentages are basis points
Schema and code use `Int` minor units (cents/satang) — never floats. Tax rates and percentage vouchers use basis points (1bp = 0.01%, so 600bps = 6.00%). The shared helpers in `apps/api/src/common/pricing.ts` (`computeLineTotal`, `applyTax`, `computeVoucherDiscount`) are the canonical implementations and are unit-tested in `pricing.spec.ts`. When adding pricing logic, route it through these helpers — the order placement path in `orders.service.ts` calls them inside the transaction.

### Order placement: idempotency + transactional re-pricing
`OrdersService.place()` in `apps/api/src/orders/orders.service.ts` is the most architecturally dense file. The flow:
1. Fast-path return if `(userId, idempotencyKey)` already exists (the column has a unique index).
2. Open a `RepeatableRead` Prisma `$transaction`. Inside:
   - `SELECT … FOR UPDATE` on the user's cart row via `$executeRaw` (Prisma has no first-class row-lock API).
   - Re-read cart items at *current* `MenuItemCountryPrice` (defends against price drift between add-to-cart and checkout).
   - Validate voucher against `VoucherCountry` (country eligibility), `VoucherRedemption` count (per-user + total caps), and time window.
   - Persist `Order` + `OrderItem`s (with `nameSnapshot` and `unitPriceMinor` so the order stays readable after menu edits) + `OrderStatusEvent(PENDING)` + optional `VoucherRedemption` + clear `CartItem`s.
3. If a concurrent retry races us to the unique idempotency key (P2002), return the row the winner inserted.

`POST /v1/orders` **requires** the `Idempotency-Key` header — the controller throws `IDEMPOTENCY_KEY_REQUIRED` if missing. The mobile client generates a UUID per checkout attempt.

### Prisma 7 setup (driver-adapter pattern)
The API runs Prisma 7. Three things differ from a typical Prisma 6 project:

- **No `url` in `schema.prisma`.** Connection config lives in `apps/api/prisma.config.ts` (`defineConfig({ datasource: { url: env('DATABASE_URL') } })`). The CLI loads this; runtime does not.
- **Driver adapter at runtime.** `PrismaService` (`apps/api/src/prisma/prisma.service.ts`) constructs `new PrismaClient({ adapter: new PrismaMariaDb(process.env.DATABASE_URL) })`. The same pattern is in `prisma/seed.ts` since `npm run seed` calls `ts-node` directly without the Prisma CLI — it imports `dotenv/config` so `DATABASE_URL` is in `process.env`.
- **Generated client lives in `apps/api/src/generated/prisma/` (gitignored).** Import paths are `from '../generated/prisma/client'` (relative — no path alias to avoid Jest/ts-node config drift). The generator block in `schema.prisma` uses `provider = "prisma-client"`, `moduleFormat = "cjs"`, `importFileExtension = ""` so emitted imports are bare and work in ts-node, Jest, and `nest build` consistently.

If you add a new script that uses Prisma outside the Nest DI graph (one-off CLIs, cron jobs, etc.), copy the `seed.ts` pattern: `import 'dotenv/config'` at the top, then `new PrismaClient({ adapter: new PrismaMariaDb(process.env.DATABASE_URL) })`.

### Multi-country data model
Country is a first-class axis, not a column on every table:
- `Country` + `Locale` + `CountryLocale` join table define the matrix (MY ↔ {en, ms}, TH ↔ {en, th}, SG ↔ {en}).
- Translations live in per-entity side tables (`MenuItemTranslation`, `CategoryTranslation`, `CustomisationGroupTranslation`, `CustomisationOptionTranslation`) keyed by `localeId` — not JSON blobs, so they're indexable and partially updatable.
- Prices live in `MenuItemCountryPrice` and `CustomisationOptionCountryPrice`, both keyed by `(entityId, countryId)`. An item is "available in country X" iff a row exists in `MenuItemCountryPrice`. The menu list query filters by `countryPrices.length > 0`.
- `Order` and `Cart` denormalise `countryId` — gives query locality on history reads and a clean future sharding seam.

When `MenuService.findOne()` resolves an option's price, country override (`CustomisationOptionCountryPrice`) wins over the default `priceDeltaMinor` on the option itself.

### Mobile architecture: `core/` → `data/` → `features/`
Strict directional imports (described in README §3b Q5):
- `lib/core/` — env (`flutter_dotenv`), money formatter, Dio HTTP client (with auth interceptor and GET-only retry), secure storage.
- `lib/data/` — DTOs (`models/`) and repositories (`repositories/`). Repositories own the Dio calls; screens never call Dio directly.
- `lib/features/<feature>/` — Riverpod providers + screens. Country selection lives in `features/onboarding/country_controller.dart` and is read by the API client to inject `X-Country` / `X-Locale` on every request.
- `lib/app/router.dart` — go_router config with a `ShellRoute` (bottom-nav tabs) and an onboarding redirect that runs until `onboardedProvider` flips true.
- `lib/shared/widgets/` — reusable UI primitives.

The Dio retry interceptor (`lib/core/http/api_client.dart`) retries **GETs only** with exponential backoff. Writes are never retried implicitly — the order-placement path generates its own UUID idempotency key per attempt instead.

Riverpod codegen (`riverpod_generator`) is intentionally not used (incompatible with Riverpod 3 on the current SDK) — providers are written by hand. Don't add a codegen step.

### AI Barista (on-device LLM + speech) — client-side only
`lib/features/ai_barista/` is a self-contained feature with **no API changes** — it grounds itself on the existing `menuListProvider` (`GET /v1/menu`). Two answer paths, chosen at runtime in `BaristaController.send()` (`ai_barista_provider.dart`):
- **On-device LLM** via `flutter_gemma` (`gemma_engine.dart`). Pinned to **0.12.6** — `>=0.12.7` needs Dart 3.10.7 but the repo is on 3.10.1. Uses the Modern API (`FlutterGemma.installModel().fromNetwork().withProgress().install()` → `getActiveModel(preferredBackend: PreferredBackend.cpu)`), `ModelFileType.task` (covers `.task`/`.litertlm`). Model + token come from `GEMMA_MODEL_URL` / `HUGGINGFACE_TOKEN` in `.env`. `ensureReady()` and `send()` are wrapped so any failure flips the UI to `GemmaStatus.unsupported` — **real inference only works on physical devices; emulators/simulators always fall back.**
- **Offline keyword recommender** (the always-on fallback) — pure functions in `lib/data/models/ai_chat.dart` (`recommendByKeywords`, `extractRecommendations`, `buildMenuCatalog`, `fallbackReply`), unit-tested without touching the plugin.

Both paths are **weather- and mood-aware**: `lib/core/weather/weather_service.dart` fetches keyless Open-Meteo by the selected country's city (best-effort, returns null on failure); `lib/features/ai_barista/mood.dart` holds the mood chips + the `composeQuery` / `llmContextLine` / `naturalPreface` helpers that fold weather+mood into both the LLM prompt and the fallback query. Speech is on-device: `speech_to_text` (mic) + `flutter_tts` (read-aloud). The recommendation guardrail (`extractRecommendations`) drops any item not on the live menu, so the LLM can't surface hallucinated SKUs. Android needs `minSdk ≥ 24` + `RECORD_AUDIO`; iOS needs Podfile static linking + mic/speech Info.plist keys.

### Auth dev bypass
`DEV_AUTH_BYPASS=true` (default in `.env.example`) makes the API accept `Authorization: Bearer dev:<sub>` and skip JWKS verification — the mobile app's `.env.example` sets `DEV_BEARER_TOKEN=dev:demo-user-sub` to match. The bypass branch is in `CognitoJwtGuard` and is the only thing that lets reviewers run the stack without AWS credentials. Never enable in prod.

### Adding a new country
Country-variant data lives in `apps/api/prisma/seed-data/*.json`. Adding a country (e.g. ID for Indonesia) is a JSON-only edit: append to `countries.json`, add a price per SKU in `pricing.json`, optionally extend `vouchers.json` / `feature-flags.json`, then `npm run seed`. The seeder has a fail-fast `validateSeedData()` step that lists every missing price or unknown country reference before touching the DB. The mobile app picks up the new country with no rebuild because the picker reads `GET /v1/countries` and `currentCountryProvider` (`apps/mobile/lib/features/onboarding/country_controller.dart`) joins the persisted code with the full country DTO (tax rate, currency code). Full runbook: `docs/architecture.md` §4 Q8.

## Conventions worth knowing

- New migrations: `cd apps/api && npx prisma migrate dev --name <slug>`. The committed `db/sql/` export is a snapshot for reference, not a parallel source of truth — don't edit it by hand.
- Input validation in the API: **Zod schemas inline in controllers** (see `orders.controller.ts`, `cart.controller.ts`). The global `ValidationPipe({ whitelist: true, transform: true })` runs alongside but Zod owns the actual shape checks.
- Translation lookups always pass `where: { localeId: country.localeId }` — there's no fallback chain to "en" in code. If a translation row is missing, the DTO falls back to the slug/SKU.
- ULIDs (not UUIDs) are used for `Order.orderNumber` — sortable, opaque to users.
